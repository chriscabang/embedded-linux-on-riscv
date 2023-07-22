# :WIP:

### NOTES

```
dd if=/dev/zero of=disk.img bs=1M count=128
cfdisk disk.img
```
- partition 1 : primary | 64MB | bootable | type: W95 FAT32 (LBA)
- partition 2 : primary | **MB

```
sudo losetup -f --show --partscan disk.img
/dev/loop2
sudo mkfs.vfat -F 32 -n boot /dev/loop2p1
sudo mkfs.ext4 -L rootfs /dev/loop2p2
sudo mkdir /mnt/boot
sudo mount /dev/loop2p1 /mnt/boot
sudo cp linux/arch/riscv/boot/Image
sudo umount /mnt/boot
```
/etc/inittab
```
# This is a first run script:
::sysinit:/etc/init.d/rcS
# Start an "askfirst" shell on the console:
::askfirst:/bin/sh
```

/etc/init.d/rcS
```
#!/bin/sh
mount -t proc nodev /proc
mount -t sysfs nodev /sys
```

```
sudo mkdir /mnt/rootfs
sudo mount /dev/loop2p2 /mnt/rootfs
sudo rsync -aH busybox/_install/ /mnt/roots/
sudo umount /mnt/rootfs
```