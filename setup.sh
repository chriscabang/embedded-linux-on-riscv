#!/bin/sh

set -e

if [ ! -e buildroot/.git ]; then
	git clone --depth 1 --branch 2023.05.1 https://github.com/buildroot/buildroot.git buildroot
fi
if [ ! -e opensbi/.git ]; then
	git clone --depth 1 --branch v1.3.1 https://github.com/riscv-software-src/opensbi.git opensbi
fi
if [ ! -e u-boot/.git ]; then
	git clone --depth 1 --branch v2023.07.02 https://github.com/u-boot/u-boot.git u-boot
fi
if [ ! -e linux/.git ]; then
	git clone --depth 1 --branch v6.1.39 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git linux
fi
if [ ! -e busybox/.git ]; then
	git clone --depth 1 --branch 1_36_0 https://github.com/mirror/busybox.git busybox
fi
if [ ! -e qemu/.git ]; then
	git clone --depth 1 --branch v8.0.3 https://github.com/qemu/qemu.git qemu
fi

git submodule sync --recursive
git submodule update --init --recursive

# sudo apt install qemu-user-static