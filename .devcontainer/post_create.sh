#!/bin/bash +x

# Give ownership to vscode for installing modules
sudo chown -R vscode:vscode /home/vscode
sudo chown -R vscode:vscode /opt/venv
pip install --upgrade -r bios/patina-qemu/pip-requirements.txt

# shellcheck disable=SC2016
echo 'eval "$(fzf --bash)"' >> ~/.bashrc
