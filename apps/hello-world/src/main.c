#include <stdio.h>

/**
 *  DEPENDS: sudo apt install qemu-user-static
 *  $> ${TOOLCHAIN}/riscv${XLEN}-linux-gcc -static -o hello main.c
 *  $> qemu-riscv${XLEN}-static hello
 */

int main() {
    printf("Hello World!\n");
    return 0;
}