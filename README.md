# Embedded Linux on RISCV : Study

[![Licence](https://img.shields.io/github/license/Ileriayo/markdown-badges?style=for-the-badge)](./LICENSE)
[![Linux](https://img.shields.io/badge/Linux-FCC624.svg?style=for-the-badge&logo=Linux&logoColor=black)](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git)
[![RISC-V](https://img.shields.io/badge/RISCV-283272.svg?style=for-the-badge&logo=RISC-V&logoColor=white)]()
![QEMU](https://img.shields.io/badge/QEMU-FF6600.svg?style=for-the-badge&logo=QEMU&logoColor=white)

This repository houses a set of tools for building [embedded Linux on RISCV](https://github.com/chriscabang/embedded-linux-on-riscv) architecture. **This does not contain gdb**.

Most importantly, this is a result of a study on [Embedded Linux in 45 minutes by Michael Opdenacker](https://bootlin.com/pub/conferences/2020/lee/opdenacker-embedded-linux-45minutes-riscv/opdenacker-embedded-linux-45minutes-riscv.pdf).


## Table of Contents

- [Tools](#tools)
- [Quickstart](#quickstart)
- [Toolchain](#toolchain)
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


## Toolchain

[Buildroot](https://github.com/buildroot/buildroot) is used to generate the SDK which conveniently contains our toolchain. The config are located at `configs/`, 
and RISC-V 64-bit buildroot will use `configs/buildroot_riscv64_defconfig`.

The toolchain is relocated and unpacked at `toolchain/`.


## Targets

The following build targets will generate the necessary binaries and images, in `build/`, required to run an embedded Linux.


### Build rootfs

The root filesystem is built using [busybox](https://github.com/mirror/busybox.git), the config can be found in `configs/`, `configs/busybox_riscv64_defconfig`.

```
$> make rootfs
```


### Build Image

Linux Kernel image is built using config files from `configs/`, `configs/linux_riscv64_defconfig`. The following command will build linux. 

```
$> make Image
```


### Build fw_payload.bin

Builds the M-mode ABI firmware with the kernel wrapped in the [u-boot](https://github.com/openhwgroup/u-boot/) bootloader. 
The configuration for u-boot is in `configs/`, `configs/uboot_riscv64_defconfig`.

```
$> make fw_payload.bin
```


### Build world

QEMU will be compiled in-tree, which means that rebuilding QEMU may require a `make clean`. The generated script `run-qemu.sh` in `build/` executes the bootloader
that loads the ABI which boots Linux.

This also [builds the disk](#build-disk) which loads all the above payloads.

```
$> make world
```


## Build disk

This target also builds the `disk.img` having two (2) partitions, a boot partition that has the Linux [Image](#build-image) and a [root filesystem](#build-rootfs) 
in the second partition. 

```
$> make disk
```


## Notes

- This support RISC-V on 64-bit build with ABI `LP64D` and ISA `imafdch`.
- This currently builds and runs on QEMU, and has never been tried on any RISC-V processor based board yet.


## License

[![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)

[MIT](LICENSE) © Chris Cabang
