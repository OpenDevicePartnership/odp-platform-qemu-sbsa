#!/bin/bash +x

# Give ownership to vscode for python, cargo and rusrtup caches
sudo chown -R vscode:vscode /home/vscode/.cache
sudo chown -R vscode:vscode /home/vscode/.cargo
sudo chown -R vscode:vscode /home/vscode/.rustup

pip install --upgrade -r bios/pip-requirements.txt
rustup default stable
rustup target add aarch64-unknown-none
rustup component add llvm-tools-preview
cargo install cargo-binutils

# shellcheck disable=SC2016
echo 'eval "$(fzf --bash)"' >> ~/.bashrc
