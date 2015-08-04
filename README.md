What is ExDOS?
==============
ExDOS is a 32-bit hobbyist operating system written entirely in assembly language for the x86. Although the name may imply it is a DOS-like system, ExDOS is not DOS-like. Unlike DOS, it doesn't support segmentation, and it supports virtual memory, memory management and ring 3 protection.  
The ExDOS kernel is the core of the ExDOS operating system. It carries out the basic tasks of the system, like managing memory, taking input, displaying output, etc...

Features
========
- Boots in less than 5 seconds on most hardware.
- Ring 3 protection.
- ACPI (with shutdown and reset!)
- PCI driver.
- PS/2 keyboard driver.
- BIOS disk access.
- VESA 2.0 framebuffer driver.
- Basic graphical routines (lines, squares, bitmap fonts, alpha blending, ...)
- Physical/virtual memory management.
- Custom file system.

TO-DO
=====
- Port OS to x86_64 while remaining compatible with 32-bit applications and drivers.
- Finish the v8086 monitor.
- Driver interface.
- IDE ATA driver.
- SATA (AHCI) driver.
- USB 1 (UHCI/OHCI) drivers.
- USB 2 (EHCI) driver.
- RTL8139 NIC driver (for QEMU.)
- NE2000 driver (for Bochs.)
- Full TCP/IP implementation.

Requirements
============
- **CPU:** Intel Pentium II or better with SSE support, or AMD equivalent.
- **RAM:** Approx. 32 MB more than VGA memory.
- **Disk space:** 1 MB.
- **Graphics:** VESA 2.0-compatible card with 2 MB of VGA memory.

About
=====
ExDOS is a small hobby OS, and is actively developed by Omar Mohammad since late 2014 and early 2015. Back then, however, it was known by two different names: Zero OS and Vector OS.  
You can contact me at omarx024@gmail.com for questions, feedback, bug reports, and anything else you'd like.  
ExDOS is licensed under the GNU General Public License version 3. By using ExDOS, you agree to the terms of the license.
