
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/stdio.asm							;;
;; Standard I/O routines						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use16

; print_string_16:
; Prints an ASCIIZ string in real mode
; In\	DS:SI = String location
; Out\	Nothing

print_string_16:
	mov ah, 0xE

.loop:
	lodsb
	cmp al, 0
	je .done
	int 0x10
	jmp .loop

.done:
	ret

use32

; clear_screen_text:
; Clears the screen in text mode
; In\	BL = Color
; Out\	Nothing

clear_screen_text:
	pusha
	mov [.color], bl

	mov edi, 0xB8000
	mov ecx, 2000

.loop:
	mov al, 0
	stosb
	mov al, [.color]
	stosb
	loop .loop

	popa
	ret

.color				db 0

; move_cursor_text:
; Moves the VGA hardware cursor
; In\	DX = Position
; Out\	Nothing

move_cursor_text:
	mov byte[.x], dl
	mov byte[.y], dh

	movzx eax, byte[.y]
	mov ebx, 80
	mul ebx
	movzx ebx, byte[.x]
	add eax, ebx

	mov ecx, eax

	mov al, 0xF
	mov dx, 0x3D4
	out dx, al

	mov eax, ecx
	mov dx, 0x3D5
	out dx, al

	mov al, 0xE
	mov dx, 0x3D4
	out dx, al

	mov eax, ecx
	mov al, ah
	mov dx, 0x3D5
	out dx, al

	ret

.x				db 0
.y				db 0


