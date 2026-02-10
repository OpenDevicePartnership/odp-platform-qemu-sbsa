FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu-22.04

ARG DEBIAN_FRONTEND=noninteractive

# Install base packages first
RUN apt-get update && \
    apt-get install -y \
        lsb-release \
        wget \
        software-properties-common \
        gnupg \
        curl

# Install LLVM repo
RUN bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)" 18

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git python3 python3-dev python3-pip python3-venv flex bison nasm iasl uuid-dev uuid-runtime \
    qemu-utils wget curl ca-certificates pkg-config libssl-dev libncurses5-dev make \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu gcc-arm-none-eabi binutils-aarch64-linux-gnu \
    crossbuild-essential-arm64 libc6-dev-arm64-cross libfdt-dev device-tree-compiler \
    seabios ovmf qemu-efi libglib2.0-dev libgtk-3-dev libepoxy-dev \
    clang-20 lld-20 llvm-20-dev llvm lld \
    && rm -rf /var/lib/apt/lists/*

# Copy edk2 pip requirements from workspace and install if present
COPY uefi/edk2/pip-requirements.txt /tmp/pip-requirements.txt
RUN if [ -f /tmp/pip-requirements.txt ]; then python3 -m pip install --upgrade pip && python3 -m pip install -r /tmp/pip-requirements.txt; fi
RUN pip install tomli ninja poetry

WORKDIR /workspaces/odp-platform-qemu-sbsa

# Setup Default Clang
RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-20 200
RUN update-alternatives --install /usr/bin/ld.lld lld /usr/bin/lld-20 200
RUN update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-20 200

ENV PATH="/usr/lib/llvm-20/bin;${PATH}"

USER vscode
