#!/bin/sh
fasm kernel/kernel.asm out/kernel.sys
#dd if=tmp/root.sys bs=512 conv=notrunc seek=64 of=disk.img
dd if=out/kernel.sys bs=512 conv=notrunc seek=200 of=disk.img

