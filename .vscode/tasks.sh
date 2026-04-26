#!/bin/bash

set -e
cd "$(dirname "$0")/.."

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

CONFIG_FILE="defconfig"
BUILD_DIR="build"

configure_kernel_clang_arm64(){
	make O=${BUILD_DIR} ARCH=arm64 LLVM=1 ${CONFIG_FILE}
}

build_kernel_clang_arm64(){
	make O=${BUILD_DIR} ARCH=arm64 LLVM=1 LLVM_IAS=1 -j$(nproc) Image
}

configure_ubuntu_local(){
	mkdir -p ${BUILD_DIR}
	# from https://oneuptime.com/blog/post/2026-03-02-how-to-build-and-install-a-custom-kernel-on-ubuntu/view
	cp /boot/config-$(uname -r) ${BUILD_DIR}/.config
	set +e
	make O=${BUILD_DIR} olddefconfig
	set -e

	# Enable Android Binder
	scripts/config --enable CONFIG_ANDROID_BINDER_IPC --file ${BUILD_DIR}/.config
	scripts/config --enable CONFIG_ANDROID_BINDERFS --file ${BUILD_DIR}/.config
	scripts/config --set-str CONFIG_ANDROID_BINDER_DEVICES "" --file ${BUILD_DIR}/.config

	# Disable debug info to speed up build and reduce size
	scripts/config --disable CONFIG_DEBUG_INFO --file ${BUILD_DIR}/.config
	scripts/config --disable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT --file ${BUILD_DIR}/.config
	scripts/config --enable CONFIG_DEBUG_INFO_NONE --file ${BUILD_DIR}/.config

	# Ubuntu's kernel config requires a trusted key for module signing.
	scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS "" --file ${BUILD_DIR}/.config
	scripts/config --set-str CONFIG_SYSTEM_REVOCATION_KEYS "" --file ${BUILD_DIR}/.config
}

build_ubuntu_local(){
	# (Binary Only)
	make O=${BUILD_DIR} LOCALVERSION=-custom -j$(nproc) bindeb-pkg
}

install_ubuntu_local(){
	sudo dpkg -i ${BUILD_DIR}/../linux-headers-*.deb ${BUILD_DIR}/../linux-image-*.deb
	sudo update-grub
}

build_ubuntu_local_with_src_tar(){
	# (Source + Binary)
	make O=${BUILD_DIR} LOCALVERSION=-custom-with-src -j$(nproc) deb-pkg
}

configure_kernel_gcc_arm64(){
	make O=${BUILD_DIR} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ${CONFIG_FILE}
}

build_kernel_gcc_arm64(){
	make O=${BUILD_DIR} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image
}

build_compile_commands() {
	python3 ./scripts/clang-tools/gen_compile_commands.py -d ${BUILD_DIR}
}

launch_arm_virt() {
	qemu-system-aarch64 \
		-M virt \
		-cpu cortex-a57 \
		-smp 4 \
		-m 2G \
		-kernel ${BUILD_DIR}/arch/arm64/boot/Image \
		-append "console=ttyAMA0 earlycon" \
		-nographic
}

# Function: Build the kernel
build_kernel_arm_virt() {
	local toolchain=$1
	shift

	mkdir -p ${BUILD_DIR}
	if [ "$toolchain" == "clang" ]; then
		build_kernel_clang_arm64
	else
		build_kernel_gcc_arm64
	fi
	log_info "Kernel build complete (Target: $toolchain)"
	build_compile_commands
	log_info "Compile commands generated"
}

configure_kernel_arm_virt() {
	local toolchain=$1
	shift

	mkdir -p ${BUILD_DIR}
	if [ "$toolchain" == "clang" ]; then
		configure_kernel_clang_arm64
	else
		configure_kernel_gcc_arm64
	fi
	log_info "Kernel configuration complete (Target: $toolchain)"
}

show_help() {
	cat << EOF
Usage: $(basename "$0") <command>

Commands:
	build-gcc	  Build arm64 kernel using GCC toolchain
	build-clang	Build arm64 kernel using LLVM/Clang toolchain
	help		   Show this help message

Example:
	$(basename "$0") build-clang
EOF
}

case "${1:-}" in
	build-gcc)
		shift
		build_kernel_arm_virt "gcc"
		;;
	build-clang)
		shift
		build_kernel_arm_virt "clang"
		;;
	configure-gcc)
		shift
		configure_kernel_arm_virt "gcc"
		;;
	configure-clang)
		shift
		configure_kernel_arm_virt "clang"
		;;
	configure-ubuntu-local)
		shift
		configure_ubuntu_local
		;;
	build-ubuntu-local)
		shift
		build_ubuntu_local
		;;
	build-ubuntu-local-with-src-tar)
		shift
		build_ubuntu_local_with_src_tar
		;;
	configure-ubuntu-local)
		shift
		configure_ubuntu_local
		;;
	install-ubuntu-local)
		shift
		install_ubuntu_local
		;;
	launch-arm-virt)
		shift
		launch_arm_virt
		;;
	clean)
		log_info "Cleaning up..."
		rm -rf "$BUILD_DIR" compile_commands.json
		;;
	help|--help|-h)
		show_help
		;;
	*)
		log_error "Unknown command: ${1:-none}"
		show_help
		exit 1
		;;
esac
