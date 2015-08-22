
;;
;; Hello World Program for ExDOS
;; Assembly-language style
;;

use32
org 0x8000000

include			"programs/kapi.asm"

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
	mov esi, string
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	;dq 0xFFFFFFFF
	ret

string			db "Hello, world!",13,10
			db "If you're reading this, then you're running an assembly program for ExDOS! :)",13,10,0

align 4096
end_of_file:


