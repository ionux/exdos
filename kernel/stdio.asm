
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

; int16_to_string:
; Converts an unsigned integer to a string
; In\	AX = Integer
; Out\	SI = ASCIIZ string

int16_to_string:
	push ax
	mov [.counter], 10

	mov di, .string
	mov cx, 10
	mov ax, 0
	rep stosb

	mov si, .string
	add si, 9
	pop ax

.loop:
	cmp ax, 0
	je .done2
	mov bx, 10
	mov dx, 0
	div bx

	add dl, 48
	mov byte[si], dl
	dec si

	sub byte[.counter], 1
	cmp byte[.counter], 0
	je .done
	jmp .loop

.done:
	mov si, .string
	ret

.done2:
	cmp byte[.counter], 10
	je .zero
	mov si, .string

.find_string_loop:
	lodsb
	cmp al, 0
	jne .found_string
	jmp .find_string_loop

.found_string:
	dec si
	ret

.zero:
	mov di, .string
	mov al, '0'
	stosb
	mov al, 0
	stosb
	mov si, .string

	ret

.string:		times 11 db 0
.counter		db 0

