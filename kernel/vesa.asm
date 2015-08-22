
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/vesa.asm							;;
;; VESA BIOS Extensions 2.0 Driver					;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Functions:
; check_vbe
; set_vesa_mode
; text_mode
; vesa_is_bpp_supported

use32

vesa_driver_name		db "ExDOS VESA 2.0 framebuffer driver",0

align 32

vesa_info_block:
	.signature		db "VBE2"
	.version		dw 0
	.oem			dd 0
	.capabilities		dd 0
	.video_modes		dd 0
	.memory			dw 0
	.software_rev		dw 0
	.vendor			dd 0
	.product_name		dd 0
	.product_rev		dd 0
	.reserved:		times 222 db 0
	.oem_data:		times 256 db 0

align 32

mode_info_block:
	.attributes		dw 0
	.window_a		db 0
	.window_b		db 0
	.granularity		dw 0
	.window_size		dw 0
	.segmentA		dw 0
	.segmentB		dw 0
	.win_func_ptr		dd 0
	.pitch			dw 0

	.width			dw 0
	.height			dw 0

	.w_char			db 0
	.y_char			db 0
	.planes			db 0
	.bpp			db 0
	.banks			db 0

	.memory_model		db 0
	.bank_size		db 0
	.image_pages		db 0

	.reserved0		db 0

	.red			dw 0
	.green			dw 0
	.blue			dw 0
	.reserved_mask		dw 0
	.direct_color		db 0

	.framebuffer		dd 0
	.off_screen_mem		dd 0
	.off_screen_mem_size	dw 0
	.reserved1:		times 206 db 0

align 32

screen:
	.width			dd 0
	.height			dd 0
	.bpp			dd 0
	.bytes_per_pixel	dd 0
	.bytes_per_line		dd 0
	.framebuffer		dd 0xC0000000
	.virtual_buffer		dd 0xE0000000
	.physical_buffer	dd 0
	.is_graphics_mode	db 0

vga_memory_64kb			dw 0			; in 64 KB blocks
vga_memory			dd 0

x_cur_max			db 0
y_cur_max			db 0
x_cur				db 0
y_cur				db 0

use16

; check_vbe:
; Checks for VESA BIOS

check_vbe:
	push es
	mov ax, 0x4F00					; get VBE controller info
	mov di, vesa_info_block
	int 0x10
	pop es

	cmp ax, 0x4F
	jne .error

	cmp word[vesa_info_block.version], 0x200	; we need VESA 2.0 or better to boot
	jl .error

	ret

.error:
	mov si, .error_msg
	call print_string_16

	jmp $

.error_msg			db "Boot error: VESA BIOS version 2.0 or better is not present.",0

use32

; get_screen_info:
; Gets screen info
; In\	Nothing
; Out\	AX = Width
; Out\	BX = Height
; Out\	CL = Bits per pixel
; Out\	CH = Bytes per pixel
; Out\	DL = Maximum X cursor
; Out\	DH = Maximum Y cursor

get_screen_info:
	mov eax, [screen.width]
	mov ebx, [screen.height]
	mov cl, byte[screen.bpp]
	mov ch, byte[screen.bytes_per_pixel]
	mov dl, [x_cur_max]
	mov dh, [y_cur_max]

	ret

; set_vesa_mode:
; Sets a VESA mode of specified width, height and bpp
; In\	AX = Width
; In\	BX = Height
; In\	CL = Bits per pixel
; Out\	EAX = Status (0 - success, 1 - VESA hardware error, 2 - mode not supported)

set_vesa_mode:
	mov [.width], ax
	mov [.height], bx
	mov [.bpp], cl

	call go16

use16

	push es
	mov ax, 0x4F00
	mov di, vesa_info_block
	int 0x10
	pop es

	cmp ax, 0x4F
	jne .vesa_error

	mov ax, [vesa_info_block.memory]
	mov [vga_memory_64kb], ax

	mov ax, word[vesa_info_block.video_modes+2]
	mov [.segment], ax

	mov si, word[vesa_info_block.video_modes]
	mov ax, [.segment]
	mov fs, ax

.find_mode:
	mov dx, [fs:si]				; FS:SI points to the video modes list
	add si, 2
	mov [.tmp], si
	mov ax, 0
	mov fs, ax

	cmp dx, 0xFFFF
	je .mode_not_supported

	mov [.mode], dx

	push es
	mov ax, 0x4F01
	mov cx, [.mode]
	mov di, mode_info_block
	int 0x10
	pop es

	cmp ax, 0x4F
	jne .vesa_error

	mov ax, [.width]
	cmp ax, [mode_info_block.width]
	jne .next_mode

	mov ax, [.height]
	cmp ax, [mode_info_block.height]
	jne .next_mode

	mov al, [.bpp]
	cmp al, [mode_info_block.bpp]
	jne .next_mode

	; If we make it here, we've found the correct mode
	mov eax, [mode_info_block.framebuffer]
	mov [screen.physical_buffer], eax
	movzx eax, word[mode_info_block.pitch]
	mov [screen.bytes_per_line], eax

	push es
	mov ax, 0x4F02
	mov bx, [.mode]
	or bx, 0x4000
	int 0x10
	pop es

	cmp ax, 0x4F
	jne .vesa_error

	jmp .done

.next_mode:
	mov si, [.tmp]
	mov ax, [.segment]
	mov fs, ax
	jmp .find_mode

.vesa_error:
	mov eax, 1
	jmp .error_stub

.mode_not_supported:
	mov eax, 2

.error_stub:
	call go32

use32

	ret

use16

.done:
	call go32

use32

	movzx eax, word[.width]
	mov [screen.width], eax

	movzx eax, word[.height]
	mov [screen.height], eax

	movzx eax, word[.width]
	mov ebx, 8
	mov edx, 0
	div ebx
	sub al, 2
	mov [x_cur_max], al

	movzx eax, word[.height]
	mov ebx, 16
	mov edx, 0
	div ebx
	sub al, 1
	mov [y_cur_max], al

	mov byte[x_cur], 0
	mov byte[y_cur], 0

	movzx eax, byte[.bpp]
	mov ebx, 8
	mov edx, 0
	div ebx
	mov [screen.bytes_per_pixel], eax

	movzx eax, byte[.bpp]
	mov [screen.bpp], eax

	mov [screen.is_graphics_mode], 1

	movzx eax, word[vga_memory_64kb]
	mov ebx, 64
	mul ebx
	mov ebx, 4
	mov edx, 0
	div ebx
	add eax, 1024
	mov [vga_memory], eax

	mov eax, [screen.physical_buffer]
	mov ebx, [screen.virtual_buffer]
	mov ecx, [vga_memory]
	mov edx, 3
	call vmm_map_memory

	mov eax, 0xC00000
	mov ecx, [vga_memory]
	call pmm_find_free_block
	jc .no_memory

	mov ebx, [screen.framebuffer]
	mov ecx, [vga_memory]
	mov edx, 3
	call vmm_map_memory

	mov eax, 0
	ret

.no_memory:
	cli
	hlt

.width				dw 0
.height				dw 0
.bpp				db 0
.tmp				dw 0
.segment			dw 0
.mode				dw 0

use32

; text_mode:
; Sets VGA text mode 80x25 16 colors

text_mode:
	call go16

use16

	mov ax, 3
	int 0x10

	mov ax, 0x1003			; disable blinking text
	int 0x10

	call go32

use32

	mov byte[screen.is_graphics_mode], 0
	ret

use16

; vesa_is_bpp_supported:
; Checks if a VESA mode with a specified BPP is supported
; In\	AL = BPP
; Out\	EFLAGS = Carry clear if supported

vesa_is_bpp_supported:
	mov [.bpp], al

	push es
	mov ax, 0x4F00
	mov di, vesa_info_block
	int 0x10
	pop es

	cmp ax, 0x4F
	jne .no

	mov ax, word[vesa_info_block.video_modes+2]
	mov [.segment], ax

	mov si, word[vesa_info_block.video_modes]
	mov ax, [.segment]
	mov fs, ax

.search:
	mov dx, word[fs:si]
	cmp dx, 0xFFFF
	je .no

	mov [.mode], dx
	add si, 2
	mov [.tmp], si

	mov ax, 0
	mov fs, ax

	push es
	mov ax, 0x4F01
	mov di, mode_info_block
	mov cx, [.mode]
	int 0x10
	pop es

	cmp ax, 0x4F
	jne .no

	mov al, [.bpp]
	cmp al, [mode_info_block.bpp]
	je .yes

.next_mode:
	mov si, [.tmp]
	mov ax, [.segment]
	mov fs, ax
	jmp .search

.yes:
	clc
	ret

.no:
	stc
	ret

.bpp				db 0
.segment			dw 0
.mode				dw 0
.tmp				dw 0

; get_modes_list_bpp:
; Gets the list of video modes of a specified BPP
; In\	AL = BPP
; Out\	EFLAGS = Carry clear on success
; Out\	SI = Pointer to video modes list, terminated with 0xFFFF

get_modes_list_bpp:
	mov [.bpp], al

	push es
	mov ax, 0x4F00
	mov di, vesa_info_block
	int 0x10
	pop es

	cmp ax, 0x4F
	jne .error

	mov ax, word[vesa_info_block.video_modes+2]
	mov [.segment], ax

	mov si, disk_buffer
	mov [.tmp2], si

	mov si, word[vesa_info_block.video_modes]
	mov ax, [.segment]
	mov fs, ax

.search:
	mov dx, word[fs:si]
	cmp dx, 0xFFFF
	je .done

	mov [.mode], dx
	add si, 2
	mov [.tmp], si

	mov ax, 0
	mov fs, ax

	push es
	mov ax, 0x4F01
	mov cx, [.mode]
	mov di, mode_info_block
	int 0x10
	pop es

	cmp ax, 0x4F
	jne .error

	mov al, [.bpp]
	cmp al, byte[mode_info_block.bpp]
	jne .next_mode

	mov ax, [.mode]
	mov di, [.tmp2]
	cli
	hlt
	stosw
	mov [.tmp2], di

.next_mode:
	mov si, [.tmp]
	mov ax, [.segment]
	mov fs, ax
	jmp .search

.error:
	mov ax, 0
	mov fs, ax

	stc
	ret

.done:
	mov ax, 0
	mov fs, ax

	mov di, [.tmp2]
	mov ax, 0xFFFF
	stosw
	mov si, [.tmp2]
	clc
	ret

.bpp				db 0
.segment			dw 0
.mode				dw 0
.tmp				dw 0
.tmp2				dw 0

