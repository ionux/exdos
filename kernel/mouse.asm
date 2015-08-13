
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

	cmp byte[.status], 0
	je .data_packet

	cmp byte[.status], 1
	je .x_packet

	cmp byte[.status], 2
	je .y_packet

.data_packet:
	in al, 0x60
	mov [.data], al

	mov byte[.status], 1
	jmp .done

.x_packet:
	in al, 0x60
	mov [.x], al

	mov byte[.status], 2
	jmp .done

.y_packet:
	in al, 0x60
	mov [.y], al

	mov byte[.status], 0
	mov byte[.changed], 1

.done:
	mov al, 0x20
	out 0x20, al
	out 0xA0, al

	pop gs
	pop fs
	pop es
	pop ds
	popa
	iret

.status				db 0
.data				db 0
.x				db 0
.y				db 0
.changed			db 0

mouse_x				dd 0
mouse_y				dd 0

; get_mouse_status:
; Gets the mouse's button status and position
; In\	Nothing
; Out\	EAX = X position
; Out\	EBX = Y position
; Out\	ECX = Button status (lowest two bits)

get_mouse_status:
	sti

.wait_for_movement:
	cmp byte[mouse_irq.changed], 1
	jne .wait_for_movement

.check_overflows:
	test byte[mouse_irq.data], 0x80
	jnz .done

	test byte[mouse_irq.data], 0x40
	jnz .done

.do_x:
	mov eax, [mouse_x]
	movzx ebx, byte[mouse_irq.x]

	test byte[mouse_irq.data], 0x10
	jnz .x_negative

.x_positive:
	add eax, ebx
	mov [mouse_x], eax
	jmp .do_y

.x_negative:
	sub eax, ebx
	mov [mouse_x], eax

.do_y:
	mov eax, [mouse_y]
	movzx ebx, byte[mouse_irq.y]

	test byte[mouse_irq.data], 0x20
	jnz .y_negative

.y_positive:
	sub eax, ebx
	mov [mouse_y], eax
	jmp .check_x

.y_negative:
	add eax, ebx
	mov [mouse_y], eax

.check_x:
	mov eax, [mouse_x]
	test eax, 0x80000000
	jnz .x_zero

	cmp eax, [screen.width]
	jg .x_overflow

	jmp .check_y

.x_zero:
	mov dword[mouse_x], 0
	jmp .check_y

.x_overflow:
	mov eax, [screen.width]
	mov [mouse_x], eax

.check_y:
	mov eax, [mouse_y]
	test eax, 0x80000000
	jnz .y_zero

	cmp eax, [screen.height]
	jg .y_overflow

	jmp .done

.y_zero:
	mov dword[mouse_y], 0
	jmp .done

.y_overflow:
	mov eax, [screen.height]
	mov [mouse_y], eax

.done:
	mov byte[mouse_irq.changed], 0

	mov eax, [mouse_x]
	mov ebx, [mouse_y]

	ret




