# Linux kernel dev image — ARM64/VirtIO focus, LLVM cross-build, sparse/checkpatch,
# gdb-multiarch + QEMU for boot-testing and remote debugging.
FROM ubuntu:24.04

ARG USERNAME=kdev
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    # kernel build deps
    build-essential flex bison bc libssl-dev libelf-dev libncurses-dev \
    rsync cpio kmod \
    # vcs / build speedup
    git ccache \
    # static analysis
    sparse coccinelle \
    # LLVM/clang cross toolchain (matches your LLVM background)
    clang lld llvm llvm-dev clang-tools clangd \
    # cross-arch debugging
    gdb-multiarch \
    # boot testing
    qemu-system-arm qemu-system-x86 qemu-utils \
    # tooling
    python3 python3-pip pipx \
    dwarves device-tree-compiler busybox-static \
    # QoL
    sudo openssh-client less vim nano ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Non-root user matching your host UID/GID — avoids root-owned files leaking
# back onto the host through the bind-mounted kernel tree.
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME
ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"

RUN pipx install b4

WORKDIR /workspaces
