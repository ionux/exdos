
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; shell/echo.asm							;;
;; ExDOS Shell -- Echo command						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32
org 0x8000000

include			"shell/kapi.asm"

file_header:
	.magic			db "ExDOS"
	.version		db 1
	.type			db 0		; 0: program, 1: driver
	.program_size		dd end_of_file - file_header
	.entry_point		dd main
	.manufacturer		dd 0
	.program_name		dd 0
	.driver_type		dw 0
	.driver_hardware	dd 0
	.reserved		dd 0

main:
	mov esi, [esp+4]	; program parameters
	cmp esi, 0
	je .quit

	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov esi, crlf
	os_api print_string_cursor

.quit:
	ret

crlf				db 10,0

align 4096
end_of_file:

