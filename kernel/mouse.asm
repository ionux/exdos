
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
; send_mouse_data
; init_mouse
; mouse_irq
; get_mouse_status
; set_mouse_cursor
; show_mouse_cursor
; hide_mouse_cursor
; redraw_cursor

use32

is_mouse_visible			db 0
mouse_width				dd 0
mouse_height				dd 0
mouse_color				dd 0
mouse_x					dd 0
mouse_y					dd 0

; send_mouse_data:
; Sends a command or data to the mouse
; In\	AL = Command or data byte
; Out\	Nothing

send_mouse_data:
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

	test word[hardware_bitflags], 4	; PS/2 pointing device
	jz .no_mouse

	; enable auxiliary mouse device
	call wait_ps2_write
	mov al, 0xA8
	out 0x64, al

	; reset mouse device
	mov al, 0xFF
	call send_mouse_data

	call wait_ps2_read
	in al, 0x60			; acknowledge byte

.wait_for_status:
	; The mouse will return 0xAA on success.
	call wait_ps2_read
	in al, 0x60

	cmp al, 0xAA
	je .reset_finished

	cmp al, 0xFC
	je .no_mouse

	jmp .wait_for_status

.reset_finished:
	call wait_ps2_read
	in al, 0x60			; read MouseID byte

	; set resolution
	mov al, 0xE8
	call send_mouse_data

	call wait_ps2_read
	in al, 0x60

	mov al, 3
	call send_mouse_data

	call wait_ps2_read
	in al, 0x60

	; enable packets
	mov al, 0xF4
	call send_mouse_data

	call wait_ps2_read
	in al, 0x60

	; enable IRQ 12
	call wait_ps2_write
	mov al, 0x20
	out 0x64, al

	call wait_ps2_read
	in al, 0x60
	or al, 2				; enable IRQ 12
	push eax

	call wait_ps2_write
	mov al, 0x60
	out 0x64, al

	call wait_ps2_write
	pop eax
	out 0x60, al

	call get_screen_center			; put the cursor at the center of the screen
	mov [mouse_x], ebx
	mov [mouse_y], ecx

	mov bx, 8				; cursor resolution is 8x16
	mov cx, 16
	mov edx, 0x7F7F7F			; make the cursor gray
	call set_mouse_cursor
	call show_mouse_cursor

	mov al, 32+12
	mov ebp, mouse_irq
	call install_isr		; install mouse IRQ handler

	ret

.no_mouse:
	mov esi, .no_mouse_msg
	jmp draw_boot_error

.no_mouse_msg				db "No PS/2 mouse device installed.",0

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

	call redraw_cursor
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

; get_mouse_status:
; Gets the mouse's button status and position
; In\	Nothing
; Out\	EAX = X position
; Out\	EBX = Y position
; Out\	ECX = Button status (lowest three bits)

get_mouse_status:
	pushfd
	sti

.wait_for_movement:
	cmp byte[mouse_irq.changed], 1
	jne .wait_for_movement

	;cli
	mov byte[mouse_irq.changed], 0

.check_overflow:
	test byte[mouse_irq.data], 0x80			; if the X or Y overflows are set, ignore the entire packet.
	jnz .done

	test byte[mouse_irq.data], 0x40
	jnz .done

.do_x:
	movzx eax, byte[mouse_irq.x]

	test byte[mouse_irq.data], 0x10
	jnz .x_negative

.x_positive:
	add dword[mouse_x], eax
	jmp .do_y

.x_negative:
	not al
	sub dword[mouse_x], eax

.do_y:
	movzx eax, byte[mouse_irq.y]

	test byte[mouse_irq.data], 0x20
	jnz .y_negative

.y_positive:
	sub dword[mouse_y], eax
	jmp .check_x

.y_negative:
	not al
	add dword[mouse_y], eax

.check_x:
	test dword[mouse_x], 0x80000000
	jnz .x_zero

	mov eax, [mouse_x]
	cmp eax, dword[screen.width]
	jg .x_overflow

	jmp .check_y

.x_zero:
	mov dword[mouse_x], 0
	jmp .check_y

.x_overflow:
	mov eax, [screen.width]
	mov [mouse_x], eax

.check_y:
	test dword[mouse_y], 0x80000000
	jnz .y_zero

	mov eax, [mouse_y]
	cmp eax, dword[screen.height]
	jg .y_overflow

	jmp .done

.y_zero:
	mov dword[mouse_y], 0
	jmp .done

.y_overflow:
	mov eax, [screen.height]
	mov [mouse_y], eax

.done:
	popfd
	mov eax, [mouse_x]
	mov ebx, [mouse_y]
	movzx ecx, byte[mouse_irq.data]
	and ecx, 5

	ret

; set_mouse_cursor:
; Sets the parameters of the mouse cursor
; In\	BX/CX = Width/Height
; In\	EDX = Color

set_mouse_cursor:
	and ebx, 0xFFFF
	and ecx, 0xFFFF
	mov [mouse_color], edx
	mov [mouse_width], ebx
	mov [mouse_height], ecx

	ret

; show_mouse_cursor:
; Shows the mouse cursor

show_mouse_cursor:
	mov byte[is_mouse_visible], 1
	ret

; hide_mouse_cursor:
; Hides the mouse cursor

hide_mouse_cursor:
	mov byte[is_mouse_visible], 0
	call redraw_screen				; redraw the screen to hide the old cursor
	ret

; redraw_cursor:
; Redraws the mouse cursor

redraw_cursor:
	pusha

	cmp byte[is_mouse_visible], 1			; if the mouse is not visible --
	jne .done					; -- just quit

	mov dword[dirty_line], 0
	call redraw_screen				; redraw the screen before drawing the cursor
							; this is to make the cursor appear "on top" of all other objects

	mov eax, [mouse_width]
	mov ebx, [screen.bytes_per_pixel]
	mul ebx
	mov [.size], eax

	call get_mouse_status

	mov [.x], eax
	mov [.y], ebx

.check_x:
	mov eax, [.x]
	mov ebx, [screen.width]
	sub ebx, dword[mouse_width]

	cmp eax, ebx
	jge .x_overflow

	jmp .check_y

.x_overflow:
	mov eax, [screen.width]
	sub eax, dword[mouse_width]
	mov [.x], eax

.check_y:
	mov eax, [.y]
	mov ebx, [screen.height]
	sub ebx, dword[mouse_height]

	cmp eax, ebx
	jge .y_overflow

	jmp .draw

.y_overflow:
	mov eax, [screen.height]
	sub eax, dword[mouse_height]
	mov [.y], eax

.draw:
	mov eax, [.x]
	mov ebx, [.y]
	call get_pixel_offset
	mov edi, eax
	add edi, dword[screen.virtual_buffer]		; write to the hardware framebuffer, not the back buffer
	mov [.offset], edi

	mov dword[.row], 0

	cmp dword[screen.bpp], 32
	jne .24

.32:
	mov eax, [.size]
	;mov ebx, 4
	;mov edx, 0
	;div ebx
	shr eax, 2				; quick divide by 4
	mov [.size], eax

.32_loop:
	mov edi, [.offset]
	mov eax, [mouse_color]
	mov ecx, [.size]
	rep stosd

	add dword[.row], 1
	mov eax, [mouse_height]
	cmp eax, dword[.row]
	jl .done

	mov eax, [screen.bytes_per_line]
	add dword[.offset], eax
	;mov eax, [screen.bytes_per_pixel]
	;add dword[.offset], eax
	jmp .32_loop

.24:
	mov ecx, [.size]
	mov edi, [.offset]

.24_loop:
	mov eax, [mouse_color]
	stosb
	shr eax, 8
	stosb
	shr eax, 8
	stosb

	sub ecx, 3
	cmp ecx, 0
	je .24_newline

	jmp .24_loop

.24_newline:
	add dword[.row], 1
	mov eax, [mouse_height]
	cmp eax, dword[.row]
	jl .done

	mov eax, [screen.bytes_per_line]
	add dword[.offset], eax
	jmp .24

.done:
	popa
	ret

.size				dd 0
.row				dd 0
.offset				dd 0
.x				dd 0
.y				dd 0

