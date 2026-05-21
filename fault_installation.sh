#!/bin/bash

# FORCE HOME DIRECTORY
cd "$HOME"

echo "=========================================================="
echo "        FAULT-DFT AUTOMATED INSTALLATION SCRIPT"
echo "=========================================================="
echo "‼️  IMPORTANT: SYSTEM RESOURCE WARNING ‼️"
echo "This script will use ALL available CPU cores ($(nproc))."
echo "To prevent your VirtualBox from freezing:"
echo "----------------------------------------------------------"
echo "1. CLOSE all other applications (Browsers, IDEs, Music)."
echo "2. DO NOT run other processes in parallel."
echo "3. Ensure your laptop is plugged into power."
echo "----------------------------------------------------------"
echo "⚠️ Recommended RAM: Minimum 4GB RAM"
echo "⚠️ Recommended Space: Minimum 10GB RAM"
echo ""

# Proceed or Abort
read -p "Are you ready to continue in $HOME? (y/n): " confirm
if [[ $confirm != [yY] ]]; then
    echo "Installation cancelled by user."
    exit 1
fi

START_TIME=$(date +%s)

# System Dependencies
echo -e "\n[1/7] Installing System Dependencies..."
sudo apt-get update -qq
sudo apt-get install -y gawk git make python3 python3-pip python3-venv \
    build-essential lld bison clang flex libffi-dev libfl-dev \
    libreadline-dev pkg-config tcl-dev zlib1g-dev graphviz xdot \
    autoconf gperf g++ libssl-dev curl

echo "[✔] Dependencies installed"

# Swift Installation (via Swiftly)
echo -e "\n[Swift] Checking/Installing Swift..."
if ! command -v swift &> /dev/null; then
curl -O https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz && \
tar zxf swiftly-$(uname -m).tar.gz && \
./swiftly init --quiet-shell-followup && \
. "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh" && \
hash -r

swiftly install 6.3.1
swiftly use 6.3.1

    echo "✅ Swift installed: $(swift --version | head -n 1)"
else
    echo "✅ Swift already installed: $(swift --version | head -n 1)"
fi

# Python Virtual Environment + Pyverilog
echo -e "\n[2/7] Setting up Python Virtual Environment..."
if [ ! -d "$HOME/fault_env" ]; then
    python3 -m venv "$HOME/fault_env"
fi
source "$HOME/fault_env/bin/activate"

pip install --upgrade pip -q
pip install pyverilog -q

echo "[✔] Python environment ready (Pyverilog installed)"

# Icarus Verilog
echo -e "\n[3/7] Building Icarus Verilog..."
if [ ! -d "$HOME/iverilog" ]; then
    git clone https://github.com/steveicarus/iverilog.git -q "$HOME/iverilog"
fi
cd "$HOME/iverilog"

sh autoconf.sh
./configure
make -j$(nproc) 2>&1 | tee build_iverilog.log
sudo make install

echo "✅ Icarus installed"

# Rust and Quaigh
echo -e "\n[4/7] Installing Rust and Quaigh..."
if ! command -v cargo &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

cargo install quaigh -q

echo "✅ Quaigh installed"

# Yosys
echo -e "\n[5/7] Building Yosys..."
if [ ! -d "$HOME/yosys" ]; then
    git clone --recurse-submodules https://github.com/YosysHQ/yosys.git -q "$HOME/yosys"
fi
cd "$HOME/yosys"

make config-clang
make -j$(nproc) 2>&1 | tee build_yosys.log
sudo make install

echo "✅ Yosys installed"

# Build Fault
echo -e "\n[6/7] Building Fault from Source..."
if [ ! -d "$HOME/Fault" ]; then
    git clone https://github.com/AUCOHL/Fault.git "$HOME/Fault" -q
fi
cd "$HOME/Fault"

swift --version | head -n 1 | awk '{print $3}' | cut -d'.' -f1,2 > .swift-version
echo " Set .swift-version to $(cat .swift-version)"

echo "⏳ Compiling Fault..."
swift build -c release 2>&1 | tee build_fault.log

cp .build/release/fault "$HOME/fault_env/bin/fault"
chmod +x "$HOME/fault_env/bin/fault"

echo "✅ Fault installed"

# Final Verification
echo -e "\n[7/7] Verification Phase"
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
