#!/bin/sh

# Create Virtual env
python3.9 -m venv .venv

# Activate
source .venv/bin/activate

# Install libraries
pip install -r requirements.txt

# Upgrade pip
pip install --upgrade pip

# Install myproject.toml
pip install -e .

# Save librairies list
#pip freeze > requirements.txt

# List librairies available
#pip list

# Exit venv
deactivate

# Add Lib Path
echo $(pwd)/lib/ > .venv/lib/python3.9/site-packages/lib_path_cocotb.pth
