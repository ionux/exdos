#!/bin/sh
fasm kernel/kernel.asm out/kernel.sys
fasm shell/shell.asm out/init.exe
fasm programs/hello.asm out/hello.exe
fasm tmp/root.asm tmp/root.sys
dd if=tmp/root.sys bs=512 conv=notrunc seek=64 of=disk.img
dd if=out/kernel.sys bs=512 conv=notrunc seek=200 of=disk.img
dd if=out/init.exe bs=512 conv=notrunc seek=500 of=disk.img
dd if=out/hello.exe bs=512 conv=notrunc seek=800 of=disk.img


