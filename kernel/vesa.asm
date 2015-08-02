
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

	mov esi, .debug_msg1
	call kdebug_print

	movzx eax, word[.width]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg2
	call kdebug_print_noprefix

	movzx eax, word[.height]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg2
	call kdebug_print_noprefix

	movzx eax, byte[.bpp]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	call go16				; go to real mode so we can use the BIOS

use16

	push es					; VESA BIOS "may" destroy ES
	mov ax, 0x4F00
	mov di, vesa_info_block
	int 0x10
	pop es

	cmp ax, 0x4F
	jne .vesa_error

	mov ax, word[vesa_info_block.memory]
	mov [vga_memory_64kb], ax

	mov si, word[vesa_info_block.video_modes]
	mov ax, word[vesa_info_block.video_modes+2]
	mov [.segment], ax
	mov ax, [.segment]
	mov ds, ax

.find_mode:
	lodsw
	cmp ax, 0xFFFF				; VESA specs say the list is 0xFFFF-terminated
	je .mode_not_supported

	mov dx, 0
	mov ds, dx

	mov [.tmp], si
	mov [.mode], ax

	push es
	mov ax, 0x4F01
	mov cx, [.mode]
	mov di, mode_info_block
	int 0x10
	pop es

	cmp ax, 0x4F
	jne .vesa_error

	mov ax, [.width]
	cmp ax, word[mode_info_block.width]
	jne .next_mode

	mov ax, [.height]
	cmp ax, word[mode_info_block.height]
	jne .next_mode

	mov al, [.bpp]
	cmp al, byte[mode_info_block.bpp]
	jne .next_mode

	mov ax, word[mode_info_block.attributes]
	test ax, 0x80					; check if the mode supports linear frame buffer
	jz .next_mode

	; if we make it here, we've found the correct VESA mode
	mov eax, [mode_info_block.framebuffer]
	mov [screen.physical_buffer], eax
	movzx eax, word[mode_info_block.pitch]
	mov [screen.bytes_per_line], eax

	mov ax, 0x4F02
	mov bx, [.mode]
	or bx, 0x4000					; enable linear frame buffer -- no bank switching
	int 0x10

	cmp ax, 0x4F
	jne .vesa_error

	call go32

use32

	jmp .done

use16

.next_mode:
	mov si, [.tmp]
	mov ax, [.segment]
	mov ds, ax
	jmp .find_mode

.vesa_error:
	mov eax, 1
	jmp .done_error

.mode_not_supported:
	mov eax, 2

.done_error:
	call go32

use32

	mov esi, .debug_msg5
	call kdebug_print
	ret

.done:
	mov esi, .debug_msg3
	call kdebug_print

	mov ax, [.mode]
	call hex_word_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg4
	call kdebug_print_noprefix

	mov eax, [screen.physical_buffer]
	call hex_dword_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	movzx eax, word[.width]
	mov [screen.width], eax
	movzx eax, word[.height]
	mov [screen.height], eax
	movzx eax, byte[.bpp]
	mov [screen.bpp], eax
	movzx eax, byte[.bpp]
	mov ebx, 8
	mov edx, 0
	div ebx
	mov [screen.bytes_per_pixel], eax

	mov byte[screen.is_graphics_mode], 1

	movzx eax, word[.width]
	mov ebx, 8
	mov edx, 0
	div ebx
	sub eax, 1

	mov byte[x_cur_max], al

	movzx eax, word[.height]
	mov ebx, 16
	mov edx, 0
	div ebx
	sub eax, 1

	mov byte[y_cur_max], al

	movzx eax, word[vga_memory_64kb]
	mov ebx, 64
	mul ebx
	mov [vga_memory], eax
	mov eax, [vga_memory]
	mov ebx, 4
	mov edx, 0
	div ebx
	add eax, 1024
	mov [.size], eax

	mov ecx, [.size]
	mov eax, [screen.physical_buffer]
	and eax, 0xFFFFF000			; ensure buffer is 4 KB page-aligned
	mov ebx, [screen.virtual_buffer]
	mov edx, 3				; only the kernel can access a framebuffer
	call vmm_map_memory			; map the framebuffer to a virtual address

	mov eax, 0xC00000			; 12 MB
	mov ecx, [.size]
	call pmm_find_free_block
	mov ebx, [screen.framebuffer]
	mov ecx, [.size]
	mov edx, 3
	call vmm_map_memory			; allocate memory for the double buffer

	; clear the double buffer and update the screen for the first time
	mov eax, [screen.height]
	mov ebx, [screen.bytes_per_line]
	mul ebx
	add eax, dword[screen.bytes_per_line]

	mov ecx, eax
	mov eax, 0
	mov edi, [screen.framebuffer]
	rep stosb

	call redraw_screen			; ensure the screen is blank

	mov eax, 0
	ret

.size			dd 0
.width			dw 0
.height			dw 0
.bpp			db 0
.segment		dw 0
.tmp			dw 0
.mode			dw 0
.debug_msg1		db "vbe: trying to set mode ",0
.debug_msg2		db "x",0
.debug_msg3		db "vbe: done, mode number ",0
.debug_msg4		db ", framebuffer at ",0
.debug_msg5		db "vbe: failed to set SVGA mode.",10,0

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





