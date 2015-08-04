
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/kernel.asm							;;
;; ExDOS Kernel Entry Point						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; The first part of the kernel is a 16-bit stub.
; It uses BIOS to do several tasks, such as enabling A20, detecting memory, getting keyboard input...
; It also prompts the user for the resolution they want to use.

use16
org 0x500

jmp 0:kmain16

use32
align 32

jmp os_api

use16

define TODAY "Tuesday, 4th August, 2015"

_kernel_version			db "ExDOS 0.1 pre-alpha built ", TODAY, 0
_api_version			dd 1
_copyright			db "(C) by Omar Mohammad",0
_crlf				db 13,10,0

syswidth			dw 0
sysheight			dw 0
sysbpp				db 0

api_version			= 1
stack_size			= 8192				; reserve 8 KB of stack space

kmain16:
	cli
	cld
	mov ax, 0
	mov es, ax

	mov di, boot_partition
	mov cx, 16
	rep movsb

	mov ax, 0
	mov ss, ax
	mov ds, ax
	mov fs, ax
	mov gs, ax
	mov sp, stack_area+stack_size

	sti

	mov [bootdisk], dl

	mov si, _kernel_version
	call print_string_16

	mov si, _crlf
	call print_string_16

	call enable_a20				; enable A20 gate
	call check_a20				; check A20 status
	call detect_memory			; detect memory using E820, and use E801 if E820 fails
	call verify_enough_memory		; verify we have enough usable RAM

get_vesa_mode_loop:
	mov byte[is_paging_enabled], 0

	mov si, _crlf
	call print_string_16

	mov si, .msg
	call print_string_16

.loop:
	mov ax, 0
	int 0x16

	cmp al, 13
	je .loop

	cmp al, 8
	je .loop

	push ax
	mov ah, 0xE
	int 0x10
	mov ah, 0xE
	mov al, 8
	int 0x10
	pop ax

	cmp al, '1'
	je .640x480

	cmp al, '2'
	je .800x600

	cmp al, '3'
	je .1024x768

	cmp al, '4'
	je .1366x768

	jmp .loop

.640x480:
	mov [syswidth], 640
	mov [sysheight], 480
	jmp .set_mode

.800x600:
	mov [syswidth], 800
	mov [sysheight], 600
	jmp .set_mode

.1024x768:
	mov [syswidth], 1024
	mov [sysheight], 768
	jmp .set_mode

.1366x768:
	mov [syswidth], 1366
	mov [sysheight], 768

.set_mode:
	jmp enter_pmode

.error:
	mov ax, 3
	int 0x10

	mov si, _crlf
	call print_string_16

	mov si, .bad_resol_msg
	call print_string_16

	jmp get_vesa_mode_loop

.msg			db "Select your preferred screen resolution: ",13,10
			db " [1] 640x480",13,10
			db " [2] 800x600",13,10
			db " [3] 1024x768",13,10
			db " [4] 1366x768",13,10
			db "Your choice: ",0
.bad_resol_msg		db "This resolution is not supported by your graphics card or your display.",13,10
			db "Please try another resolution.",13,10,0

enter_pmode:
	cli
	lgdt [gdtr]
	lidt [idtr]

	mov eax, cr0
	or eax, 1				; enable protected mode
	mov cr0, eax

	jmp 8:kmain32

use32

kmain32:
	cli
	mov ax, 0x10
	mov ss, ax
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	movzx esp, sp

	pushfd
	pop eax
	and eax, 0xFFFFCFFF			; prevent v8086 from doing CLI/STI, and only the kernel can do IN/OUT
	push eax
	popfd

	call init_serial			; enable serial port
	call kdebug_init			; initialize kernel debugger
	call init_exceptions			; we should install exceptions handlers before anything, just to be safe
	call remap_pic				; remap IRQ 0-15 to INT 32-47
	call init_sse				; enable SSE
	call pmm_init				; initalize physical memory manager
	call vmm_init				; start paging and virtual memory management
	call init_pit				; set up PIT to 100 Hz
	call init_kbd				; initialize PS/2 keyboard

	mov ax, [syswidth]
	mov bx, [sysheight]
	mov cl, 32
	call set_vesa_mode			; set 32bpp VESA mode

	cmp eax, 0				; if that didn't work, try doing it with 24 bpp
	jne .try_24bpp

	jmp .draw_boot_screen

.try_24bpp:
	mov ax, [syswidth]
	mov bx, [sysheight]
	mov cl, 24
	call set_vesa_mode

	cmp eax, 0
	jne .vesa_error

	jmp .draw_boot_screen

.vesa_error:
	call go16

use16

	jmp get_vesa_mode_loop.error

use32

.draw_boot_screen:
	mov ebx, 0xC0C0C0
	call clear_screen

	call init_hdd				; initialize hard disk

	mov esi, bootlogo
	mov edi, disk_buffer
	call load_file

	cmp eax, 0
	jne .continue_booting

	call get_screen_center
	sub bx, 64
	sub cx, 64
	mov esi, disk_buffer
	call draw_image

.continue_booting:
	call get_screen_center
	sub bx, 80
	mov ecx, [screen.height]
	sub cx, 16
	mov edx, 0x606060
	mov esi, _copyright
	call print_string_transparent

	call init_sysenter			; initialize SYSENTER/SYSEXIT MSRs
	call load_tss				; load the TSS
	call init_cmos				; initialize CMOS RTC clock
	call init_cpuid				; get CPU brand
	call detect_cpu_speed			; get CPU speed
	call init_acpi				; initialize ACPI
	call init_acpi_power			; initialize ACPI power management
	;call init_pcie				; PCI Express is not yet implemented
	call init_pci				; initialize legacy PCI
	;call ata_init				; initialize IDE ATA controller
	;call ahci_init				; initialize SATA (AHCI) controller

	sti

	mov eax, 0xA00000			; look for free memory starting at 10 MB
	mov ecx, 512				; find at least 2 MB of free memory
	call pmm_find_free_block
	jc out_of_memory

	mov ebx, 0x1000000			; map the memory to 16 MB
	mov ecx, 512
	mov edx, 7				; user, read/write, present
	call vmm_map_memory

	mov esi, init_filename
	mov edi, 0x1000000			; load the init to virtual address 16 MB
	call load_file

	cmp eax, 0
	jne .init_missing

	call enter_ring3			; NEVER EVER let programs run in ring 0!
	jmp 0x1000000

.init_missing:
	mov byte[x_cur], 2
	mov byte[y_cur], 1
	mov esi, .init_missing_msg
	mov ecx, 0xC0C0C0
	mov edx, 0
	call print_string_graphics_cursor

	sti

.hlt:
	hlt
	jmp .hlt

.init_missing_msg		db "init.exe is missing.",0

_boot_error_common		db "Press Control+Alt+Delete to reboot your PC.",0
bootlogo			db "boot.bmp"
init_filename			db "init.exe"


include				"kernel/stdio.asm"		; Standard I/O
include				"kernel/string.asm"		; String manipulation routines
include				"kernel/serial.asm"		; Serial port driver
include				"kernel/system.asm"		; Internal system routines
include				"kernel/isr.asm"		; Interrupt service routines
include				"kernel/vesa.asm"		; VESA 2.0 framebuffer driver
include				"kernel/kbd.asm"		; Keyboard driver
include				"kernel/font.asm"		; Bitmap font
include				"kernel/gdi.asm"		; Graphical device interface
include				"kernel/hdd.asm"		; Hard disk "driver"
include				"kernel/cmos.asm"		; CMOS RTC driver
include				"kernel/cpuid.asm"		; CPUID parser
include				"kernel/panic.asm"		; Kernel panic screen
include				"kernel/power.asm"		; Basic power management
include				"kernel/pmm.asm"		; Physical memory manager
include				"kernel/vmm.asm"		; Virtual memory manager
include				"kernel/tasking.asm"		; Multitasking
include				"kernel/v8086.asm"		; v8086 monitor
include				"kernel/exdfs.asm"		; ExDFS driver
include				"kernel/api.asm"		; Kernel API
;include			"kernel/pcie.asm"		; PCI Express enumerator
include				"kernel/pci.asm"		; PCI enumerator
include				"kernel/acpi.asm"		; ACPI driver
include				"kernel/apm.asm"		; APM BIOS
;include			"kernel/ata.asm"		; ATA disk driver
;include			"kernel/ahci.asm"		; SATA (AHCI) disk driver
include				"kernel/drivers.asm"		; Driver interface
include				"kernel/kdebug.asm"		; Kernel debugger

db				"This program is property of Omar Mohammad.",0

align 32

stack_area:			rb stack_size			; 8 KB of stack space
				rq 1				; and an extra QWORD, just in case ;)

align 32

memory_map:			rq 64				; 1 KB of space for E820 memory map

page_directory			= 0x70000

page_table			= 0x100000			; page table takes up 4 MB of RAM
								; it can't be located in low memory

end_of_page_table		= 0x500000

pmm_table			= 0x600000
end_of_pmm_table		= 0x700000

align 32

disk_buffer:							; reserve whatever is left in memory as a disk buffer



