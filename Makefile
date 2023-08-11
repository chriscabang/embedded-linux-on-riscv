ARCH			        := riscv
XLEN							:= 64
PLATFORM					:= generic

ROOT							:= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR					:= $(ROOT)/build
CONFIF_DIR				:= $(ROOT)/configs

TOOLCHAIN					:= $(ARCH)$(XLEN)-buildroot-linux-gnu_sdk-buildroot
TOOLCHAIN_DIR			:= $(ROOT)/toolchain
TOOLCHAIN_PREFIX	:= $(TOOLCHAIN_DIR)/$(TOOLCHAIN)/bin/$(ARCH)$(XLEN)-linux-
NPROC							:= $(shell nproc)
CC								:= $(TOOLCHAIN_PREFIX)gcc

.PHONY: all prerequisites
all: buildroot u-boot linux opensbi disk

.PHONY: install
install: all

prerequisites:
	mkdir -p $(BUILD_DIR)
	mkdir -p $(TOOLCHAIN_DIR)

$(CC): prerequisites

.PHONY: buildroot
buildroot: $(CC)
	make -C buildroot defconfig \
		BR2_DEFCONFIG=$(CONFIG_DIR)/buildroot_$(ARCH)$(XLEN)_defconfig
	make -C buildroot sdk -j $(NPROC)
	tar xf buildroot/output/images/$(TOOLCHAIN).tar.gz -C $(TOOLCHAIN_DIR)/
	$(TOOLCHAIN_DIR)/$(TOOLCHAIN)/relocate-sdk.sh

.PHONY: u-boot
u-boot: $(CC) buildroot
	cp $(CONFIG_DIR)/uboot_$(ARCH)$(XLEN)_defconfig u-boot/.config
	make -C u-boot ARCH=$(ARCH) olddefconfig
	make -C u-boot ARCH=$(ARCH) CROSS_COMPILE=$(TOOLCHAIN_PREFIX) -j $(NPROC)
	cp u-boot/u-boot.bin $(BUILD_DIR)/

.PHONY: opensbi
opensbi: $(CC) u-boot linux
	make -C opensbi ARCH=$(ARCH) CROSS_COMPILE=$(TOOLCHAIN_PREFIX) \
		PLATFORM=$(PLATFORM) XLEN=$(XLEN) FW_PAYLOAD_PATH=$(BUILD_DIR)/u-boot.bin
	cp opensbi/build/platform/$(PLATFORM)/firmware/fw_payload.elf $(BUILD_DIR)/

.PHONY: linux
linux: $(CC) buildroot
	cp $(CONFIG_DIR)/linux_$(ARCH)$(XLEN)_defconfig linux/.config
	make -C linux ARCH=$(ARCH) olddefconfig
	make -C linux ARCH=$(ARCH) CROSS_COMPILE=$(TOOLCHAIN_PREFIX) -j $(NPROC)
	cp linux/arch/$(ARCH)/boot/Image $(BUILD_DIR)/

$(BUILD_DIR)/disk.img:
	dd if=/dev/zero of=$(BUILD_DIR)/disk.img bs=1M count=128 status=progress

partition: $(BUILD_DIR)/disk.img
	sgdisk \
		-n 1:0:63M \
			-t 1:EF00 -c 1:"Bootable Fat32" \
		-n 2:64M:127M \
			-t 2:8300 -c 2:"Root Filesystem" $(BUILD_DIR)/disk.img


format: partition

#	mkfs.vfat -F 32 -n boot $(BUILD_DIR)/disk.img1
#	mkfs.ext4 -F -L roots $(BUILD_DIR)/disk.img2

.PHONY: disk
disk: format
	fdisk -l $(BUILD_DIR)/disk.img

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

.PHONY: wipe
wipe: clean
	rm -rf $(TOOLCHAIN_DIR)
	make -C buildroot clean
	make -C u-boot clean
	make -C opensbi clean
	make -C linux clean

.PHONY: help
help:
	@echo  'Cleaning targets:'
	@echo  '  clean     - delete generated $(BUILD_DIR) directory'
	@echo  '  wipe	    - delete all all files created by build including non-source files'
	@echo  ''
	@echo  'Build:'
	@echo  '  all         - Build all targets marked with [*]'
	@echo  '* linux       - Build the bare kernel'
	@echo  '* buildroot   - Build all modules'
	@echo  '* u-boot      - Install all modules to INSTALL_MOD_PATH (default: /)'
	@echo  '* opensbi     - Build all files in dir and below'
	@echo  '* busybox     - Build specified target only'
	@echo  '* disk        - Build the LLVM assembly file'
	@echo  ''
	@echo  'Configuration:'
	@echo  '  checkstack      - Generate a list of stack hogs'
	@echo  '  versioncheck    - Sanity check on version.h usage'
	@echo  '  includecheck    - Check for duplicate included header files'
	@echo  '  export_report   - List the usages of all exported symbols'
	@echo  '  headerdep       - Detect inclusion cycles in headers'
	@echo  '  coccicheck      - Check with Coccinelle'
	@echo  '  clang-analyzer  - Check with clang static analyzer'
	@echo  '  clang-tidy      - Check with clang-tidy'
	@echo  ''
	@echo  'Tools:'
	@echo  '  nsdeps          - Generate missing symbol namespace dependencies'
	@echo  ''
	@echo  'Kernel selftest:'
	@echo  '  kselftest         - Build and run kernel selftest'
	@echo  '                      Build, install, and boot kernel before'
	@echo  '                      running kselftest on it'
	@echo  '                      Run as root for full coverage'
	@echo  '  kselftest-all     - Build kernel selftest'
	@echo  '  kselftest-install - Build and install kernel selftest'
	@echo  '  kselftest-clean   - Remove all generated kselftest files'
	@echo  '  kselftest-merge   - Merge all the config dependencies of'
	@echo  '		      kselftest to existing .config.'
	@echo  ''
	@echo  'Rust targets:'
	@echo  '  rustavailable   - Checks whether the Rust toolchain is'
	@echo  '		    available and, if not, explains why.'
	@echo  '  rustfmt	  - Reformat all the Rust code in the kernel'
	@echo  '  rustfmtcheck	  - Checks if all the Rust code in the kernel'
	@echo  '		    is formatted, printing a diff otherwise.'
	@echo  '  rustdoc	  - Generate Rust documentation'
	@echo  '		    (requires kernel .config)'
	@echo  '  rusttest        - Runs the Rust tests'
	@echo  '                    (requires kernel .config; downloads external repos)'
	@echo  '  rust-analyzer	  - Generate rust-project.json rust-analyzer support file'
	@echo  '		    (requires kernel .config)'
	@echo  '  dir/file.[os]   - Build specified target only'
	@echo  '  dir/file.rsi    - Build macro expanded source, similar to C preprocessing.'
	@echo  '                    Run with RUSTFMT=n to skip reformatting if needed.'
	@echo  '                    The output is not intended to be compilable.'
	@echo  '  dir/file.ll     - Build the LLVM assembly file'
	@echo  ''
	@echo  'Execute "make" or "make all" to build all targets marked with [*] '
	@echo  'For further info see the ./README file'
