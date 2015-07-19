
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/serial.asm							;;
;; Serial Port Driver							;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

is_there_serial				db 0
serial_ioport				dw 0

; init_serial:
; Initializes the serial port

init_serial:
	cli
	mov edi, 0x400
	cmp word[edi], 0
	je .no_serial

	mov ax, word[edi]
	mov [serial_ioport], ax

	mov byte[is_there_serial], 1

	mov al, 0
	mov dx, [serial_ioport]
	out dx, al

	mov al, 0x80
	mov dx, [serial_ioport]
	add dx, 3
	out dx, al

	mov al, 2
	mov dx, [serial_ioport]
	out dx, al

	mov al, 0
	mov dx, [serial_ioport]
	add dx, 1
	out dx, al

	mov al, 3
	mov dx, [serial_ioport]
	add dx, 3
	out dx, al

	mov al, 0xC7
	mov dx, [serial_ioport]
	add dx, 2
	out dx, al

	mov al, 0x0B
	mov dx, [serial_ioport]
	add dx, 4
	out dx, al

	ret

.no_serial:
	mov byte[is_there_serial], 0
	ret

; send_byte_via_serial:
; Sends a byte via serial port
; In\	AL = Byte to send
; Out\	EAX = 0 on success, 1 if no serial port present

send_byte_via_serial:
	pusha

	cmp byte[is_there_serial], 0
	je .no_serial

.wait:
	mov dx, [serial_ioport]
	add dx, 5
	in al, dx

	test al, 0x20
	jz .wait

.send:
	popa
	pusha
	mov dx, [serial_ioport]
	out dx, al

	popa
	mov eax, 0
	ret

.no_serial:
	popa
	mov eax, 1
	ret


