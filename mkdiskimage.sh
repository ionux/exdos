#!/bin/sh
echo Creating disk image...
dd if=/dev/zero bs=512 conv=notrunc count=71568 of=exdos.img
echo Compiling bootcode and root directory...
mkdir output
fasm boot/mbr.asm output/mbr.sys
fasm boot/boot_hdd.asm output/boot_hdd.sys
fasm tmp/root.asm output/root.sys
echo Compiling kernel...
fasm kernel/kernel.asm output/kernel.sys
echo Compiling shell and programs...
fasm shell/shell.asm output/init.exe
fasm shell/echo.asm output/echo.exe
fasm programs/hello.asm output/hello.exe
fasm programs/draw.asm output/draw.exe
fasm programs/hello2.asm output/hello2.exe
fasm programs/heaptest.asm output/heaptest.exe
fasm shell/cat.asm output/cat.exe
fasm programs/imgview.asm output/imgview.exe
echo Installing OS on disk image...
dd if=output/mbr.sys conv=notrunc bs=512 count=1 of=exdos.img
dd if=output/boot_hdd.sys conv=notrunc bs=512 seek=63 of=exdos.img
dd if=output/root.sys conv=notrunc bs=512 seek=64 of=exdos.img
dd if=output/kernel.sys conv=notrunc bs=512 seek=200 of=exdos.img
dd if=output/init.exe conv=notrunc bs=512 seek=500 of=exdos.img
dd if=output/hello.exe conv=notrunc bs=512 seek=600 of=exdos.img
dd if=output/hello2.exe conv=notrunc bs=512 seek=602 of=exdos.img
dd if=output/draw.exe conv=notrunc bs=512 seek=650 of=exdos.img
dd if=output/echo.exe conv=notrunc bs=512 seek=670 of=exdos.img
dd if=output/heaptest.exe conv=notrunc bs=512 seek=671 of=exdos.img
dd if=output/cat.exe conv=notrunc bs=512 seek=672 of=exdos.img
dd if=output/imgview.exe conv=notrunc bs=512 seek=673 of=exdos.img
dd if=wallpaper.bmp conv=notrunc bs=512 seek=674 of=exdos.img
echo Removing temporary files...
rm -r output
echo Finished. You can now run qemu-system-i386 exdos.img
exit
