FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu-22.04 AS qemu-builder
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libepoxy-dev \
    libfdt-dev \
    libglib2.0-dev \
    libgtk-3-dev \
    libpixman-1-dev \
    pkg-config \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    git \
    wget \
    tar \
    gzip \
    zlib1g-dev
RUN pip install tomli ninja poetry
RUN wget https://github.com/qemu/qemu/archive/refs/tags/v10.2.1.tar.gz -O /tmp/qemu.tar.gz
RUN tar -xzf /tmp/qemu.tar.gz && \
    cd qemu-10.2.1 && \
    ./configure --target-list=aarch64-softmmu --enable-gtk && \
    make -j$(nproc) && \
    make install

FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu-22.04
ARG DEBIAN_FRONTEND=noninteractive

# Install base packages first
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    apt-get update && apt-get install -y --no-install-recommends \
    lsb-release \
    wget \
    software-properties-common \
    gnupg \
    curl

# Install LLVM repo
RUN bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)" 20

# Install build dependencies
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    apt-get update && apt-get install -y --no-install-recommends \
    binutils-aarch64-linux-gnu \
    bison \
    build-essential \
    ca-certificates \
    crossbuild-essential-arm64 \
    device-tree-compiler \
    flex \
    g++-aarch64-linux-gnu \
    gcc-aarch64-linux-gnu \
    gcc-arm-none-eabi \
    git \
    iasl \
    libc6-dev-arm64-cross \
    libepoxy-dev \
    libfdt-dev \
    libglib2.0-dev \
    libgtk-3-dev \
    libncurses5-dev \
    libssl-dev \
    lld \
    llvm \
    make \
    nasm \
    ovmf \
    pkg-config \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    qemu-efi \
    qemu-utils \
    seabios \
    uuid-dev \
    uuid-runtime

RUN pip install tomli ninja poetry

# Install QEMU 10 from builder image
COPY --from=qemu-builder /usr/local/bin/qemu-system-aarch64 /usr/local/bin/qemu-system-aarch64
COPY --from=qemu-builder /usr/local/bin/qemu-img /usr/local/bin/qemu-img
COPY --from=qemu-builder /usr/local/share/qemu /usr/local/share/qemu

# Setup Default Clang
RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-20 200
RUN update-alternatives --install /usr/bin/ld.lld lld /usr/bin/lld-20 200
RUN update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-20 200

ENV PATH="/usr/lib/llvm-20/bin:${PATH}"

USER vscode
