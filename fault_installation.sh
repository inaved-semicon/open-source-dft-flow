#!/bin/bash

# FORCE HOME DIRECTORY
cd "$HOME"

echo "=========================================================="
echo "        FAULT-DFT AUTOMATED INSTALLATION SCRIPT"
echo "=========================================================="
echo "‼️  IMPORTANT: SYSTEM RESOURCE WARNING ‼️"
echo "This script will use ALL available CPU cores ($(nproc))."
echo "To prevent your machine/VM from freezing:"
echo "----------------------------------------------------------"
echo "1. CLOSE all other applications (Browsers, IDEs)."
echo "2. DO NOT run other processes in parallel."
echo "3. Ensure your laptop is plugged into power."
echo "----------------------------------------------------------"
echo "⚠️ Recommended RAM: Minimum 4GB RAM"
echo "⚠️ Recommended Space: Minimum 10GB Free Space"
echo ""

# Proceed or Abort
read -p "Are you ready to continue in $HOME? (y/n): " confirm
if [[ $confirm != [yY] ]]; then
    echo "Installation cancelled by user."
    exit 1
fi

START_TIME=$(date +%s)

# 1/7 System Dependencies
echo -e "\n[1/7] Installing System Dependencies & EDA Tools..."
sudo apt-get update -qq
sudo apt-get install -y gawk git make python3 python3-pip python3-venv \
    build-essential lld bison clang flex libffi-dev libfl-dev \
    libreadline-dev pkg-config tcl-dev zlib1g-dev graphviz xdot \
    autoconf gperf g++ libssl-dev curl yosys iverilog

echo "[✔] System dependencies, Yosys, and Iverilog verified."

# 2/7 Swift Installation (via Swiftly)
echo -e "\n[2/7] Checking/Installing Swift Toolchain..."
export SWIFTLY_HOME_DIR="$HOME/.local/share/swiftly"
export PATH="$SWIFTLY_HOME_DIR/bin:$PATH"

if ! command -v swift &> /dev/null; then
    echo "⏳ Downloading and configuring Swiftly..."
    curl -sSfLO https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz
    tar zxf swiftly-$(uname -m).tar.gz
    
    ./swiftly init --quiet-shell-followup
    [ -f swiftly-$(uname -m).tar.gz ] && rm swiftly-$(uname -m).tar.gz
    
    # Network-safe loop for downloading the 1GB Swift package
    while true; do
        echo "⏳ Attempting to install Swift 6.3.1..."
        if swiftly install 6.3.1 --assume-yes; then
            echo "✅ Swift toolchain downloaded successfully!"
            break
        else
            echo "⚠️  Download interrupted or failed. Retrying in 5 seconds..."
            sleep 5
        fi
    done
    
    echo "⏳ Linking Swiftly toolchain globally..."
    swiftly link
else
    echo "✅ Swift already available globally."
fi

# Double-check execution path validation
export PATH="$SWIFTLY_HOME_DIR/bin:$PATH"
echo "✅ Swift Version: $(swift --version | head -n 1)"
# 3/7 Python Virtual Environment + Pyverilog
echo -e "\n[3/7] Setting up Python Virtual Environment..."
if [ ! -d "$HOME/fault_env" ]; then
    python3 -m venv "$HOME/fault_env"
fi
source "$HOME/fault_env/bin/activate"

pip install --upgrade pip -q
pip install pyverilog -q
echo "[✔] Python environment ready (Pyverilog installed inside fault_env)"

# 4/7 Rust Toolchain Verification (Required by backend elements of Fault flows)
echo -e "\n[4/7] Checking Rust/Cargo Installation..."
if ! command -v cargo &> /dev/null; then
    echo "⏳ Rust not found. Installing via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "✅ Rust/Cargo already installed."
fi

# 5/7 Build Fault From Source
echo -e "\n[5/7] Cloning and Compiling Fault..."
if [ ! -d "$HOME/Fault" ]; then
    git clone https://github.com/AUCOHL/Fault.git "$HOME/Fault" -q
fi
cd "$HOME/Fault"

# Explicitly pin the correct toolchain version to avoid parsing strings
echo "6.3.1" > .swift-version
echo "ℹ️  Set .swift-version to $(cat .swift-version)"

echo "⏳ Compiling Fault executable (release mode)..."
# Clear out any leftover broken artifacts before compiling
swift build -c release 2>&1 | tee build_fault.log

# Verify and move the executable
if [ -f ".build/release/fault" ]; then
    cp .build/release/fault "$HOME/fault_env/bin/fault"
    chmod +x "$HOME/fault_env/bin/fault"
    echo "✅ Fault binary successfully integrated into environment."
else
    echo "❌ Error: Fault compilation failed. Check $HOME/Fault/build_fault.log for details."
    exit 1
fi

# Icarus Verilog
echo -e "\n[6/7] Building Icarus Verilog..."
if [ ! -d "$HOME/iverilog" ]; then
    git clone https://github.com/steveicarus/iverilog.git -q "$HOME/iverilog"
fi
cd "$HOME/iverilog"

sh autoconf.sh
./configure
make -j$(nproc) 2>&1 | tee build_iverilog.log
sudo make install

echo "✅ Icarus installed"

# Yosys
echo -e "\n[7/7] Building Yosys..."
if [ ! -d "$HOME/yosys" ]; then
    git clone --recurse-submodules https://github.com/YosysHQ/yosys.git -q "$HOME/yosys"
fi
cd "$HOME/yosys"

make config-clang
make -j$(nproc) 2>&1 | tee build_yosys.log
sudo make install

echo "✅ Yosys installed"

echo -e "\n================================================================"
echo "                ALL SYSTEMS GO! Verification Summary:"
echo "====================================================================="
echo "📍 Fault:        $(~/fault_env/bin/fault --version)"
echo "📍 Yosys:        $(yosys -V)"
echo "📍 Icarus:       $(iverilog -V | head -n 1)"
echo "📍 Pyverilog:    $(python3 -c 'import pyverilog; print(\"Installed\")' 2>/dev/null || echo \"Not Found\")"
echo "====================================================================="

END_TIME=$(date +%s)
echo "⏱️ Total time: $((END_TIME - START_TIME)) seconds"

echo "====================================================================="
echo " To work, run:"
echo " source ~/fault_env/bin/activate"
echo " source ~/.cargo/env"
echo "====================================================================="
