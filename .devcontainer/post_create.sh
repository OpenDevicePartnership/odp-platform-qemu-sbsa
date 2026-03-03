#!/bin/bash +x

# Give ownership to vscode for installing modules
sudo chown -R vscode:vscode /home/vscode
pip install --upgrade -r bios/pip-requirements.txt

# shellcheck disable=SC2016
echo 'eval "$(fzf --bash)"' >> ~/.bashrc
