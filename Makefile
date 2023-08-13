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

BUILDROOT_CONFIG  := $(CONFIGS)/buildroot_$(ARCH)$(XLEN)_defconfig

BOOTLOADER_CONFIG := $(CONFIGS)/uboot_$(ARCH)$(XLEN)_defconfig
BOOTLOADER_FLAGS  += ARCH=$(ARCH)
BOOTLOADER_FLAGS  += CROSS_COMPILE=$(TOOLCHAIN_PREFIX)

SBI_FLAGS         += ARCH=$(ARCH)
SBI_FLAGS         += CROSS_COMPILE=$(TOOLCHAIN_PREFIX)
SBI_FLAGS         += PLATFORM=$(PLATFORM)
SBI_FLAGS         += PLATFORM_RISCV_XLEN=$(XLEN)

LINUX_CONFIG      := $(CONFIG)/linux_$(ARCH)$(XLEN)_defconfig
LINUX_FLAGS       += ARCH=$(ARCH)
LINUX_FLAGS       += CROSS_COMPILE=$(TOOLCHAIN_PREFIX)

BUSYBOX_CONFIG    := $(CONFIGS)/busybox_$(ARCH)$(XLEN)_defconfig
BUSYBOX_FLAGS     += CROSS_COMPILE=$(TOOLCHAIN_PREFIX)

prerequisites:
	mkdir -p $(BUILD)
	mkdir -p $(TOOLCHAIN_DIR)

$(CC): prerequisites
	@if [ ! -e toolchain.timestamp ]; then \
		make -C buildroot defconfig BR2_DEFCONFIG=$(BUILDROOT_CONFIG) ; \
		make -C buildroot sdk -j $(NPROC) ; \
		tar xf buildroot/output/images/$(TOOLCHAIN).tar.gz -C $(TOOLCHAIN_DIR)/ ; \
		$(TOOLCHAIN_DIR)/$(TOOLCHAIN)/relocate-sdk.sh ; \
		touch toolchain.timestamp ; \
	fi

all: prerequisites fw_payload.bin Image rootfs

$(ROOT)/u-boot/u-boot.bin: $(CC)
	@if [ ! -e $(lastword $(subst /, ,$@)).timestamp ]; then \
		cp $(BOOTLOADER_CONFIG) u-boot/.config ; \
		make -C u-boot $(BOOTLOADER_FLAGS) olddefconfig ; \
		make -C u-boot $(BOOTLOADER_FLAGS) -j $(NPROC) ; \
		touch $(lastword $(subst /, ,$@)).timestamp ; \
	fi

$(BUILD)/u-boot.bin: $(ROOT)/u-boot/u-boot.bin
	cp $< $@

$(ROOT)/opensbi: $(BUILD)/u-boot.bin
	@if [ ! -e $(lastword $(subst /, ,$@)).timestamp ]; then \
		make -C opensbi $(SBI_FLAGS) FW_PAYLOAD_PATH=$< ; \
		touch $(lastword $(subst /, ,$@)).timestamp ; \
	fi

$(BUILD)/fw_payload.bin: $(ROOT)/opensbi
	cp $</build/platform/$(PLATFORM)/firmware/fw_payload.elf $(BUILD)/fw_payload.elf
	cp $</build/platform/$(PLATFORM)/firmware/fw_payload.bin $(BUILD)/fw_payload.bin

$(ROOT)/linux/arch/$(ARCH)/boot/Image: $(CC)
	@if [ ! -e $(lastword $(subst /, ,$@)).timestamp ]; then \
		cp $(LINUX_CONFIG) $(ROOT)/linux/.config ; \
		make -C linux ARCH=$(ARCH) olddefconfig ; \
		make -C linux $(LINUX_FLAGS) -j $(NPROC) ; \
		touch $(lastword $(subst /, ,$@)).timestamp ; \
	fi

$(BUILD)/Image: $(ROOT)/linux/arch/$(ARCH)/boot/Image
	cp $< $@

$(ROOT)/busybox/_install:
	@if [ ! -e busybox.timestamp ]; then \
		cp $(BUSYBOX_CONFIG) $(ROOT)/busybox/.config ; \
		make -C busybox $(BUSYBOX_FLAGS) -j $(NPROC) ; \
		make -C busybox $(BUSYBOX_FLAGS) install ; \
		touch busybox.timestamp ; \
	fi

$(BUILD)/rootfs: $(ROOT)/busybox/_install
	cp -R $< $@

$(BUILD)/disk.img:
	dd if=/dev/zero of=$@ bs=1M count=128 status=progress

partition: $(BUILD)/disk.img
	sgdisk \
		-n 1:0:63M \
			-t 1:EF00 -c 1:"Bootable Fat32" \
		-n 2:64M:127M \
			-t 2:8300 -c 2:"Root Filesystem" $<

format: $(BUILD)/disk.img partition
	fdisk -l $<

.PHONY: all fw_payload.bin Image rootfs disk help wipe clean

fw_payload.bin: $(BUILD)/fw_payload.bin
Image: $(BUILD)/Image
rootfs: $(BUILD)/rootfs
disk: format

clean:
	rm -rf $(BUILD) *.timestamp

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
