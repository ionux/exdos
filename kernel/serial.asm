
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

;; Functions:
; init_serial
; send_byte_via_serial
; send_string_via_serial

use32

is_there_serial				db 0
serial_ioport				dw 0

; init_serial:
; Initializes the serial port

init_serial:
	sti

	cmp byte[serial_enabled], 0
	je .no_serial

	mov edi, 0x400
	cmp word[edi], 0
	je .no_serial

	mov ax, word[edi]
	mov [serial_ioport], ax

	mov byte[is_there_serial], 1

	mov al, 1001b			; disable interrupts
	mov dx, [serial_ioport]
	add dx, 1
	out dx, al

	mov al, 0x80			; enable DLAB
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

	mov al, 3			; disable DLAB
	mov dx, [serial_ioport]
	add dx, 3
	out dx, al

	mov al, 0xC7			; enable FIFO
	mov dx, [serial_ioport]
	add dx, 2
	out dx, al

	mov al, 0xB
	mov dx, [serial_ioport]
	add dx, 4
	;out dx, al

	ret

.no_serial:
	mov byte[is_there_serial], 0
	ret

; wait_serial_send:
; Waits for the serial port to receive data

wait_serial_send:
	pusha

.wait:
	mov dx, [serial_ioport]
	add dx, 5
	in al, dx
	test al, 0x20
	jz .wait

	popa
	ret

; send_byte_via_serial:
; Sends a byte via serial port
; In\	AL = Byte to send
; Out\	EAX = 0 on success, 1 if no serial port present

send_byte_via_serial:
	pusha

	cmp al, 10
	je .newline

	cmp byte[is_there_serial], 0
	je .no_serial

.wait:
	call wait_serial_send
	popa
	pusha

	mov dx, [serial_ioport]
	out dx, al

	call wait_serial_send

	popa
	mov eax, 0
	ret

.no_serial:
	popa
	mov eax, 1
	ret

.newline:
	call wait_serial_send

	mov dx, [serial_ioport]
	mov al, 13
	out dx, al

	call wait_serial_send

	mov dx, [serial_ioport]
	mov al, 10
	out dx, al

	call wait_serial_send

	popa
	mov eax, 0
	ret

.string:		times 2 db 0

; send_string_via_serial:
; Sends a string via serial port
; In\	ESI = String
; Out\	EAX = 0 on success, 1 if no serial port present

send_string_via_serial:
	cmp byte[is_there_serial], 0
	je .no_serial

.loop:
	lodsb
	cmp al, 0
	je .done
	call send_byte_via_serial
	jmp .loop

.done:
	mov eax, 0
	ret

.no_serial:
	mov eax, 1
	ret



