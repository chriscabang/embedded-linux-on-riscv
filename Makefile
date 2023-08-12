ARCH              := riscv
XLEN              := 64
PLATFORM          := generic

ROOT               = $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD              = $(ROOT)/build
CONFIGS            = $(ROOT)/configs

TOOLCHAIN          = $(ARCH)$(XLEN)-buildroot-linux-gnu_sdk-buildroot
TOOLCHAIN_DIR      = $(ROOT)/toolchain
TOOLCHAIN_PREFIX  := $(TOOLCHAIN_DIR)/$(TOOLCHAIN)/bin/$(ARCH)$(XLEN)-linux-
NPROC              = $(shell nproc)
CC                := $(TOOLCHAIN_PREFIX)gcc

prerequisites:
	mkdir -p $(BUILD)
	mkdir -p $(TOOLCHAIN_DIR)

$(CC): prerequisites
	make -C buildroot defconfig BR2_DEFCONFIG=$(CONFIGS)/buildroot_$(ARCH)$(XLEN)_defconfig
	make -C buildroot sdk -j $(NPROC)
	tar xf buildroot/output/images/$(TOOLCHAIN).tar.gz -C $(TOOLCHAIN_DIR)/
	$(TOOLCHAIN_DIR)/$(TOOLCHAIN)/relocate-sdk.sh

$(ROOT)/u-boot/u-boot.bin: $(CC)
	cp $(CONFIGS)/uboot_$(ARCH)$(XLEN)_defconfig u-boot/.config
	make -C u-boot ARCH=$(ARCH) olddefconfig
	make -C u-boot ARCH=$(ARCH) CROSS_COMPILE=$(TOOLCHAIN_PREFIX) -j $(NPROC)

$(BUILD)/u-boot.bin: $(ROOT)/u-boot/u-boot.bin
	cp $< $@

$(ROOT)/opensbi: $(BUILD)/u-boot.bin
	make -C opensbi ARCH=$(ARCH) CROSS_COMPILE=$(TOOLCHAIN_PREFIX) PLATFORM=$(PLATFORM) XLEN=$(XLEN) FW_PAYLOAD_PATH=$<

$(BUILD)/fw_payload.bin: $(ROOT)/opensbi
	cp $</build/platform/$(PLATFORM)/firmware/fw_payload.elf $(BUILD)/fw_payload.elf
	cp $</build/platform/$(PLATFORM)/firmware/fw_payload.bin $(BUILD)/fw_payload.bin

$(ROOT)/linux: $(CC)
	cp $(CONFIGS)/linux_$(ARCH)$(XLEN)_defconfig $@/.config
	make -C linux ARCH=$(ARCH) olddefconfig
	make -C linux ARCH=$(ARCH) CROSS_COMPILE=$(TOOLCHAIN_PREFIX) -j $(NPROC)

$(BUILD)/Image: $(ROOT)/linux
	cp $</arch/$(ARCH)/boot/Image $@

$(ROOT)/busybox/_install:
	cp $(CONFIGS)/busybox_$(ARCH)$(XLEN)_defconfig $(ROOT)/busybox/.config
	make -C busybox allnoconfig
	make -C busybox CROSS_COMPILE=$(TOOLCHAIN_PREFIX) -j $(NPROC)
	make -C busybox install

$(BUILD)/rootfs.tar: $(ROOT)/busybox/_install
	cp -R $< $(BUILD)/rootfs

$(BUILD)/disk.img:
	dd if=/dev/zero of=$@ bs=1M count=128 status=progress

partition: $(BUILD)/disk.img
	sgdisk \
		-n 1:0:63M \
			-t 1:EF00 -c 1:"Bootable Fat32" \
		-n 2:64M:127M \
			-t 2:8300 -c 2:"Root Filesystem" $<

format: $(BUILD)/disk.img partition
#	mkfs.vfat -F 32 -n boot $(BUILD)/disk.img1
#	mkfs.ext4 -F -L roots $(BUILD)/disk.img2
	fdisk -l $<

.PHONY: all firmware image disk rootfs install help wipe clean

all: firmware image rootfs
firmware: $(BUILD)/fw_payload.bin
image: $(BUILD)/Image
rootfs: $(BUILD)/rootfs.tar
disk: format
install: all disk

clean:
	rm -rf $(BUILD)

wipe: clean
	rm -rf $(TOOLCHAIN_DIR)
	make -C buildroot clean
	make -C u-boot clean
	make -C opensbi clean
	make -C linux clean
	make -C busybox distclean

help:
	@echo  'Cleaning targets:'
	@echo  '  clean				- delete generated $(BUILD) directory'
	@echo  '  wipe	    	- delete all all files created by build including non-source files'
	@echo  ''
	@echo  'Build:'
	@echo  '  all         - Build all targets marked with [*]'
	@echo  '* linux       - Build the bare kernel'
	@echo  '* opensbi     - Build all files in dir and below'
	@echo  '  install     - Build all and install on disk image for load'
	@echo  '  disk        - Build the LLVM assembly file'
	@echo  ''
	@echo  'Execute "make" or "make all" to build all targets marked with [*] '
	@echo  'For further info see the ./README file'
