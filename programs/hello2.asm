
;;
;; Hello World Program for ExDOS, really meant to test loading multiple programs in memory
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
	push eax

	mov esi, string
	mov ecx, 0x000020
	mov edx, 0xFF0000
	os_api print_string_cursor

	pop ebx
	os_api int_to_string

	mov ecx, 0x000020
	mov edx, 0x7F00FF
	os_api print_string_cursor

	mov esi, string2
	mov ecx, 0x000020
	mov edx, 0xFF0000
	os_api print_string_cursor

	ret

string			db "Hello, I'm a program written in assembly!",10
			db "My PID is ",0
string2			db "!",10,0

align 4096
end_of_file:

