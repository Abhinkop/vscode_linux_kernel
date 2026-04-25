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

configure_kernel_gcc_arm64(){
	make O=${BUILD_DIR} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ${CONFIG_FILE}
}

build_kernel_gcc_arm64(){
	make O=${BUILD_DIR} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image
}

build_compile_commands() {
	python3 ./scripts/clang-tools/gen_compile_commands.py -d ${BUILD_DIR}
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
