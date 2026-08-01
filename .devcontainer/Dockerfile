# Linux kernel dev image — ARM64/VirtIO focus, LLVM cross-build, sparse/checkpatch,
# gdb-multiarch + QEMU for boot-testing and remote debugging.
#
# Built on Microsoft's devcontainers base image: it already ships a "vscode"
# non-root user at UID/GID 1000 with passwordless sudo configured. The Dev
# Containers CLI automatically remaps that user's UID/GID to match the host
# user (updateRemoteUserUID, on by default) — no manual user creation needed.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core kernel build dependencies
    build-essential flex bison bc libssl-dev libelf-dev libncurses-dev \
    rsync cpio kmod \
    # Build speedups & static analysis
    ccache sparse coccinelle \
    # LLVM/Clang cross toolchain & language server support
    clang lld llvm llvm-dev clang-tools clangd \
    # Cross-architecture debugging & execution
    gdb-multiarch qemu-system-arm qemu-system-x86 qemu-utils \
    # Essential kernel utilities & auxiliary build tools
    dwarves device-tree-compiler busybox-static \
    # Python ecosystem for modern kernel workflow tooling
    python3 python3-pip pipx \
    && rm -rf /var/lib/apt/lists/*

# Drop down to the pre-configured Microsoft base image user
USER vscode

# Configure local binaries path and map ccache to your devcontainer.json volume target
ENV PATH="/home/vscode/.local/bin:/usr/lib/ccache:${PATH}"
ENV CCACHE_DIR=/home/vscode/.cache/ccache

# Install b4 for mailing list / patch management via pipx isolated context
RUN pipx install b4

# Automate variables for LLVM ARM64 cross-compilation in the interactive terminal
RUN echo "export ARCH=arm64" >> ~/.bashrc \
    && echo "export LLVM=1" >> ~/.bashrc \
    && echo "export CROSS_COMPILE=aarch64-linux-gnu-" >> ~/.bashrc

RUN mkdir -p /home/vscode/.cache/ccache \
    && chown -R vscode:vscode /home/vscode/.cache

WORKDIR /workspaces
