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
    clang lld llvm llvm-dev clang-tools clangd libc6-dev-arm64-cross \
    # arm64 crt objects/libgcc for static-linked cross builds (e.g.
    # make-rootfs.sh's busybox) — not pulled in by libc6-dev-arm64-cross
    libgcc-13-dev-arm64-cross \
    # Cross-architecture debugging & execution
    gdb-multiarch qemu-system-arm qemu-system-x86 qemu-utils \
    # QEMU monitor control (device_del for surprise-removal testing) and
    # raw hex inspection of PCI config-space reads/writes
    socat xxd \
    # Essential kernel utilities & auxiliary build tools
    dwarves device-tree-compiler busybox-static \
    # Python ecosystem for modern kernel workflow tooling
    python3 python3-pip pipx \
    # git send-email and its mail-sending dependencies. git-email is a
    # separate package from git itself on Debian/Ubuntu; the two Perl
    # libs handle SASL auth and TLS to the SMTP server respectively.
    git-email libauthen-sasl-perl libio-socket-ssl-perl \
    # mutt for reading/replying to patch review threads (proper inline
    # quoting, References/In-Reply-To threading) — config comes from
    # the host via a bind mount in devcontainer.json, not baked in here
    mutt \
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

RUN mkdir -p /home/vscode/.cache/ccache /home/vscode/.mutt \
    && chown -R vscode:vscode /home/vscode/.cache /home/vscode/.mutt

RUN git config --global sendemail.smtpserver smtp.gmail.com \
    && git config --global sendemail.smtpserverport 587 \
    && git config --global sendemail.smtpencryption tls \
    && git config --global sendemail.smtpuser abhinjoses@gmail.com \
    && git config --global user.name "Abhin Parekadan Jose" \
    && git config --global user.email "abhinjoses@gmail.com"

WORKDIR /workspaces
