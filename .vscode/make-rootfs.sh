#!/usr/bin/env bash
# make-rootfs.sh — build a minimal arm64 busybox-based initramfs for boot-
# testing under qemu-system-aarch64, using LLVM/clang (matches the kernel's
# own LLVM=1 build).
#
# IMPORTANT: the `busybox-static` apt package installs a binary matching the
# HOST architecture (x86_64 in this devcontainer), not the arm64 target you
# boot under QEMU. An x86_64 init on an emulated arm64 CPU will not execute.
# This script cross-compiles busybox from source for arm64 instead.
set -euo pipefail

WORKROOT="${WORKROOT:-$PWD}"
BUSYBOX_SRC="$WORKROOT/.vscode/rootfs/busybox-src"
ROOTFS_DIR="$WORKROOT/.vscode/rootfs/initramfs"
OUT="$WORKROOT/.vscode/rootfs/initramfs.cpio.gz"
SYSROOT="/usr/aarch64-linux-gnu"

# --- 0. Preflight: everything LLVM cross-compilation needs ---
for bin in clang ld.lld llvm-ar llvm-nm llvm-strip llvm-objcopy; do
  if ! command -v "$bin" >/dev/null; then
    echo "Missing $bin. Install with: sudo apt-get install -y clang lld llvm" >&2
    exit 1
  fi
done
# clang doesn't bundle a target libc — it needs glibc's arm64 headers/libs
# (crt1.o etc). The package that provides them is only a *Recommends* of
# some cross-gcc packages, and images that disable install-recommends
# (Microsoft's devcontainers/base does) silently skip it — install
# explicitly rather than relying on it coming along for free.
if [ ! -f "$SYSROOT/include/bits/libc-header-start.h" ]; then
  echo "Missing arm64 libc headers. Install with: sudo apt-get install -y libc6-dev-arm64-cross" >&2
  exit 1
fi
# libc6-dev-arm64-cross doesn't ship libgcc (crtbeginT.o, crtend.o, -lgcc,
# -lgcc_eh) — that comes from a separate cross-runtime package, installed
# under /usr/lib/gcc-cross/aarch64-linux-gnu/<ver>/ (clang auto-detects it
# there, not under $SYSROOT). Without it the final static link fails with
# "cannot open crtbeginT.o".
if ! compgen -G "/usr/lib/gcc-cross/aarch64-linux-gnu/*/crtbeginT.o" >/dev/null; then
  echo "Missing arm64 libgcc. Install with: sudo apt-get install -y libgcc-13-dev-arm64-cross" >&2
  exit 1
fi

# clang cross-compile flags, mirroring the kernel's own LLVM=1 build.
# -isysroot (not --sysroot) on purpose: without any sysroot flag, clang
# falls back to the HOST's /usr/include, producing headers-not-found
# errors. But plain --sysroot also sets the *linker's* sysroot, and
# Debian's libm.a is a GROUP linker script containing an absolute path
# (/usr/aarch64-linux-gnu/lib/libm-2.39.a) that's already fully qualified
# — ld.lld then prepends the sysroot again and fails to find it
# ("...libm-2.39.a inside /usr/aarch64-linux-gnu"). -isysroot only
# redirects header search; crt objects and -L library paths are still
# found correctly via clang's automatic detection of the installed
# aarch64 GCC cross-runtime (libgcc-*-dev-arm64-cross).
CLANG_TARGET_FLAGS="--target=aarch64-linux-gnu -fuse-ld=lld -isysroot $SYSROOT"
# CROSS_COMPILE is cleared explicitly: this repo's devcontainer exports
# ARCH=arm64 / CROSS_COMPILE=aarch64-linux-gnu- for kernel builds, and
# busybox's Makefile defaults CC etc. to that prefix when unset on the
# command line (e.g. aarch64-linux-gnu-gcc, which doesn't exist here —
# only clang/lld are installed).
MAKE_LLVM_ARGS=(
  ARCH=arm64
  CROSS_COMPILE=
  CC="clang $CLANG_TARGET_FLAGS"
  LD=ld.lld
  AR=llvm-ar
  NM=llvm-nm
  STRIP=llvm-strip
  OBJCOPY=llvm-objcopy
)

# --- 1. Fetch and cross-compile a static arm64 busybox, if not already built ---
if [ ! -x "$BUSYBOX_SRC/busybox" ]; then
  echo "==> Cloning busybox source"
  rm -rf "$BUSYBOX_SRC"
  git clone --depth 1 https://github.com/mirror/busybox.git "$BUSYBOX_SRC"

  echo "==> Configuring busybox (static, arm64)"
  make -C "$BUSYBOX_SRC" CROSS_COMPILE= defconfig
  sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' "$BUSYBOX_SRC/.config"
  # defconfig enables x86 SHA hardware-acceleration intrinsics that don't
  # build under arm64 cross-compilation — disable them.
  sed -i \
    -e 's/CONFIG_SHA1_HWACCEL=y/# CONFIG_SHA1_HWACCEL is not set/' \
    -e 's/CONFIG_SHA256_HWACCEL=y/# CONFIG_SHA256_HWACCEL is not set/' \
    "$BUSYBOX_SRC/.config"
  # The `tc` (traffic control) applet needs kernel headers this sysroot
  # doesn't ship with — not needed for a minimal test rootfs.
  sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' "$BUSYBOX_SRC/.config"

  echo "==> Cross-compiling busybox for arm64 with clang/lld"
  make -C "$BUSYBOX_SRC" -j"$(nproc)" "${MAKE_LLVM_ARGS[@]}"
else
  echo "==> Reusing already-built $BUSYBOX_SRC/busybox"
fi

# --- 2. Get the applet list ---
# `busybox --list` runs the binary to enumerate applets — but the binary we
# just built is arm64 and can't execute on this (x86_64) build host. Build a
# second, host-native busybox from the *same config* purely to get the list;
# it isn't shipped anywhere, only used to generate symlink names.
if [ ! -x "$BUSYBOX_SRC/busybox-host-native" ]; then
  echo "==> Building host-native busybox (applet listing only, not shipped)"
  cp "$BUSYBOX_SRC/.config" "$BUSYBOX_SRC/.config.arm64.bak"
  make -C "$BUSYBOX_SRC" -j"$(nproc)" CROSS_COMPILE= CC=clang
  mv "$BUSYBOX_SRC/busybox" "$BUSYBOX_SRC/busybox-host-native"
  mv "$BUSYBOX_SRC/.config.arm64.bak" "$BUSYBOX_SRC/.config"
  # Rebuild the arm64 target binary (the host-native build overwrote it).
  make -C "$BUSYBOX_SRC" -j"$(nproc)" "${MAKE_LLVM_ARGS[@]}"
fi
APPLET_LIST="$("$BUSYBOX_SRC/busybox-host-native" --list)"

# --- 3. Assemble the rootfs ---
echo "==> Building rootfs at $ROOTFS_DIR"
rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"/{bin,sbin,etc,proc,sys,dev,tmp,root}

cp "$BUSYBOX_SRC/busybox" "$ROOTFS_DIR/bin/busybox"

# Relative symlinks for every applet (sh, ls, cat, mount, ...), skipping
# busybox itself. (Using `busybox --install` directly bakes in the build
# machine's absolute path as the symlink target, which breaks once booted
# on a different filesystem — so link relatively instead.)
(cd "$ROOTFS_DIR/bin" && \
  for applet in $APPLET_LIST; do \
    [ "$applet" = "busybox" ] && continue; \
    ln -sf busybox "$applet"; \
  done)

cat > "$ROOTFS_DIR/init" <<'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null
echo ""
echo "=== minimal rootfs booted — dropping to shell ==="
exec /bin/sh
EOF
chmod +x "$ROOTFS_DIR/init"

echo "==> Packing initramfs -> $OUT"
(cd "$ROOTFS_DIR" && find . | cpio -o -H newc 2>/dev/null | gzip -9) > "$OUT"

echo "==> Done: $OUT ($(du -h "$OUT" | cut -f1))"
llvm-objdump -f "$ROOTFS_DIR/bin/busybox" | head -2
