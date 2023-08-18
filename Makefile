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
	@if [ ! -e toolchain.stamp ]; then \
		make -C buildroot defconfig BR2_DEFCONFIG=$(BUILDROOT_CONFIG) ; \
		make -C buildroot sdk -j $(NPROC) ; \
		tar xf buildroot/output/images/$(TOOLCHAIN).tar.gz -C $(TOOLCHAIN_DIR)/ ; \
		$(TOOLCHAIN_DIR)/$(TOOLCHAIN)/relocate-sdk.sh ; \
		touch toolchain.stamp ; \
	fi

all: prerequisites fw_payload.bin Image rootfs

$(ROOT)/app: $(CC)
	@if [ ! -e $(lastword $(subst /, ,$@)).stamp ]; then \
	fi

$(ROOT)/u-boot/u-boot.bin: $(CC)
	@if [ ! -e $(lastword $(subst /, ,$@)).stamp ]; then \
		cp $(BOOTLOADER_CONFIG) u-boot/.config ; \
		make -C u-boot $(BOOTLOADER_FLAGS) olddefconfig ; \
		make -C u-boot $(BOOTLOADER_FLAGS) -j $(NPROC) ; \
		touch $(lastword $(subst /, ,$@)).stamp ; \
	fi

$(BUILD)/u-boot.bin: $(ROOT)/u-boot/u-boot.bin
	cp $< $@

$(ROOT)/opensbi: $(BUILD)/u-boot.bin
	@if [ ! -e $(lastword $(subst /, ,$@)).stamp ]; then \
		make -C opensbi $(SBI_FLAGS) FW_PAYLOAD_PATH=$< ; \
		touch $(lastword $(subst /, ,$@)).stamp ; \
	fi

$(BUILD)/fw_payload.bin: $(ROOT)/opensbi
	cp $</build/platform/$(PLATFORM)/firmware/fw_payload.elf $(BUILD)/fw_payload.elf
	cp $</build/platform/$(PLATFORM)/firmware/fw_payload.bin $(BUILD)/fw_payload.bin

$(ROOT)/linux/arch/$(ARCH)/boot/Image: $(CC)
	@if [ ! -e $(lastword $(subst /, ,$@)).stamp ]; then \
		cp $(LINUX_CONFIG) $(ROOT)/linux/.config ; \
		make -C linux ARCH=$(ARCH) olddefconfig ; \
		make -C linux $(LINUX_FLAGS) -j $(NPROC) ; \
		touch $(lastword $(subst /, ,$@)).stamp ; \
	fi

$(BUILD)/Image: $(ROOT)/linux/arch/$(ARCH)/boot/Image
	cp $< $@

$(ROOT)/busybox/_install: $(CC)
	@if [ ! -e busybox.stamp ]; then \
		cp $(BUSYBOX_CONFIG) $(ROOT)/busybox/.config ; \
		make -C busybox $(BUSYBOX_FLAGS) -j $(NPROC) ; \
		make -C busybox $(BUSYBOX_FLAGS) install ; \
		touch busybox.stamp ; \
	fi

$(BUILD)/rootfs: $(ROOT)/busybox/_install
	cp -R $< $@
	cp -pR $(ROOT)/rootfs/etc $@/
	mkdir -p $@/proc
	mkdir -p $@/sys

$(INSTALL)/qemu/build:
	@if [ ! -e qemu.stamp ]; then \
		cd $(ROOT)/qemu ; \
    ./configure --target-list=$(ARCH)$(XLEN)-softmmu ; \
		make -j $(NPROC) ; \
		make install ; \
		touch $(ROOT)/qemu.stamp ; \
	fi

$(BUILD)/run-qemu.sh: $(INSTALL)/qemu/build
	echo "#!/bin/sh" > $@
	echo "qemu-system-$(ARCH)$(XLEN) -m 2G -nographic -machine virt -smp 8 \\" >> $@
	echo "-bios $(BUILD)/fw_payload.elf \\" >> $@
	echo "-drive file=$(BUILD)/disk.img,format=raw,id=hd0 \\" >> $@
	echo "-device virtio-blk-device,drive=hd0 \\" >> $@
	chmod +x $@
	chown "${SUDO_USER}:${SUDO_USER}" $@

$(BUILD)/disk.img:
	dd if=/dev/zero of=$@ bs=1M count=128 oflag=sync status=progress

partition: $(BUILD)/disk.img
	sgdisk \
		-n 1:0:63M \
			-t 1:EF00 -c 1:"Bootable Fat32" \
		-n 2:64M:127M \
			-t 2:8300 -c 2:"Root Filesystem" $<

format: $(BUILD)/disk.img partition
	@LOOP_DEVICE=$$(losetup -f --show --partscan $<) ; \
	mkfs.vfat -F 32 -n boot $${LOOP_DEVICE}p1 ; \
	mkfs.ext4 -L rootfs $${LOOP_DEVICE}p2 ; \
	mkdir -p /mnt/boot ; \
	mount $${LOOP_DEVICE}p1 /mnt/boot ; \
	cp $(BUILD)/Image /mnt/boot ; \
	umount /mnt/boot ; \
	mkdir -p /mnt/rootfs ; \
	mount $${LOOP_DEVICE}p2 /mnt/rootfs ; \
	rsync -aH $(BUILD)/rootfs/ /mnt/rootfs/ ; \
	umount /mnt/rootfs ; \
	losetup -d $${LOOP_DEVICE}

check-files:
	@test -e $(BUILD)/fw_payload.elf && \
		test -e $(BUILD)/Image && \
		test -e $(BUILD)/rootfs || \
		(echo "At least fw_payload.elf, Image or rootfs does not exist.Exiting." && exit 1)

$(BUILD)/disk: check-files format
	chown "${SUDO_USER}:${SUDO_USER}" $@.img
	fdisk -l $@.img

.PHONY: all fw_payload.bin Image rootfs qemu disk help wipe clean

fw_payload.bin: $(BUILD)/fw_payload.bin
Image: $(BUILD)/Image
rootfs: $(BUILD)/rootfs
world: $(BUILD)/run-qemu.sh $(BUILD)/disk
disk: $(BUILD)/disk

clean:
	rm -rf $(BUILD) *.stamp *.applied
	make -C buildroot clean
	make -C u-boot clean
	make -C opensbi clean
	make -C busybox clean
	make -C linux clean
	cd qemu && make clean

wipe: clean
	rm -rf $(TOOLCHAIN_DIR)
	make -C buildroot distclean
	make -C u-boot distclean
	make -C opensbi distclean
	make -C busybox distclean
	make -C linux distclean
	cd qemu && make distclean

help:
	@echo  'Cleaning targets:'
	@echo  '  clean           - delete generated $(BUILD) directory'
	@echo  '  wipe            - delete all all files created by build including non-source files'
	@echo  ''
	@echo  'Build:'
	@echo  '  all             - Build all targets marked with [*]'
	@echo  '* fw_payload.bin  - Build firmware via openSBI'
	@echo  '* Image           - Build the bare kernel'
	@echo  '* rootfs          - Build the root file system'
	@echo  '  world           - Build qemu and disk for run-qemu script'
	@echo  '  disk            - Build the disk image with Image and file system for qemu'
	@echo  ''
	@echo  'Execute "make" or "make all" to build all targets marked with [*] '
#	@echo  'For further info see the ./README file'
