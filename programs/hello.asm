
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; programs/hello.asm							;;
;; Sample Hello World Program						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32
org 0x8000000			; programs are loaded to 128 MB

beginning_of_file:

exdos_program_header:
	.magic			db "ExDOS"				; must be ExDOS
	.version		db 1					; version 1
	.type			db 0					; 0 program, 1 driver
	.program_size		dd end_of_file - beginning_of_file	; size of program
	.entry_point		dd main					; entry point address
	.manufacturer		dd manufacturer				; program manufacturer
	.program_name		dd program_name				; program name
	.driver_type		dw 0					; reserved for drivers (should be class code of PCI device)
	.driver_hardware	dd 0					; reserved for drivers (should be model name of the hardware)
	.reserved		dd 0					; reserved for future expansion

manufacturer			db "Omar Mohammad",0
program_name			db "Hello world program",0

main:
	mov eax, 5		; Print string at cursor position function
	mov esi, string		; ESI = String location
	mov ebx, 0xFFFFFF	; EBX = Foreground color
	mov edx, 0		; EDX = Background color
	int 0x5F		; Kernel API

	mov eax, 0		; Terminate program
	mov ebx, 0		; EBX = Exit code
	int 0x5F		; Kernel API

string				db "Hello, world! :)",13,10,0

align 4096			; program size *must* be a multiple of 4096 (page-aligned)

end_of_file:

