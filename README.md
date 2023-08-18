# Embedded Linux on RISCV : Study

[![license](https://img.shields.io/github/license/:user/:repo.svg)](../LICENSE)
[![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)


This repository houses a set of tools for building [embedded Linux on RISCV](https://github.com/chriscabang/embedded-linux-on-riscv) architecture. **This does not contain gdb**.

## Table of Contents

- [Tools](#tools)
- [Quickstart](#quickstart)
- [Targets](#targets)
- [Notes](#notes)
- [License](#license)

## Tools:
* [buildroot](https://github.com/buildroot/buildroot), the simple, efficient and easy-to-use tool to generate embedded Linux systems through cross-compilation.
* [u-boot](https://github.com/openhwgroup/u-boot/), the open-source bootloader for embedded systems and development board.
* [opensbi](https://github.com/riscv/opensbi/), the open-source reference implementation of the RISC-V Supervisor Binary Interface (SBI)
* [linux](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git), the linux operating system
* [busybox](https://github.com/mirror/busybox.git), the swiss army knife of embedded Linux, contains tiny versions of many UNIX utilities into a single executable. 
* [qemu](https://github.com/qemu/qemu.git), the open source machine and user space emulator virtualizer


## Quickstart

Quickly setup the required tools (submodules) by running `./setup.sh`. This script requires Git >= 2.11.0, 
because the script uses `--shallow-clone` for faster submodule initialization.


## Targets

### Build rootfs

### Build Image

### Build fw_payload.bin

### Build world



Note: The `license` badge image link at the top of this file should be updated with the correct `:user` and `:repo`.

## Notes

Small note: If editing the Readme, please conform to the [standard-readme](https://github.com/RichardLitt/standard-readme) specification.

## License

[MIT © Chris Cabang.](../LICENSE)
