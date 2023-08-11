#!/bin/sh
qemu-system-riscv64 -m 2G -nographic -machine virt -smp 8 \
-bios build/fw_payload.elf \
-drive file=disk.img,format=raw,id=hd0 \
-device virtio-blk-device,drive=hd0 \
