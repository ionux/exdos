
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/mouse.asm							;;
;; PS/2 Mouse Driver							;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Functions:
; send_mouse
; init_mouse
; mouse_irq
; get_mouse_status

use32

; send_mouse:
; Sends a command or data to the mouse
; In\	AL = Command or data byte
; Out\	Nothing

send_mouse:
	push eax

	call wait_ps2_write
	mov al, 0xD4
	out 0x64, al

	call wait_ps2_write		; this command doesn't generate an ACK
	pop eax
	out 0x60, al			; send the command/data

	ret

; init_mouse:
; Initializes the PS/2 mouse

init_mouse:
	cli

	mov al, 32+12
	mov ebp, mouse_irq
	call install_isr		; install mouse IRQ handler

	; enable IRQ 12
	call wait_ps2_write
	mov al, 0x20
	out 0x64, al

	call wait_ps2_read
	in al, 0x60
	or al, 2
	push eax

	call wait_ps2_write
	mov al, 0x60
	out 0x64, al

	call wait_ps2_write
	pop eax
	out 0x60, al

	; enable auxiliary device
	call wait_ps2_write
	mov al, 0xA8
	out 0x64, al

	; set defaults
	mov al, 0xF6
	call send_mouse

	call wait_ps2_read
	in al, 0x60

	; set resolution
	mov al, 0xE8
	call send_mouse

	call wait_ps2_read
	in al, 0x60

	mov al, 3
	call send_mouse

	call wait_ps2_read
	in al, 0x60

	; enable packets
	mov al, 0xF4
	call send_mouse

	call wait_ps2_read
	in al, 0x60

	ret

; mouse_irq:
; Mouse IRQ 12 handler

mouse_irq:
	pusha
	push ds
	push es
	push fs
	push gs

	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	mov esi, .a

	in al, 0x60
	call hex_byte_to_string
	mov ecx, 0xC0C0C0
	mov edx, 0
	call print_string_graphics_cursor

	mov al, 0x20
	out 0x20, al
	out 0xA0, al

	pop gs
	pop fs
	pop es
	pop ds
	popa
	iret

.a		db "a",0

