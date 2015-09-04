
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
	push eax

	mov esi, string
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	pop ebx
	os_api int_to_string

	mov ecx, 0
	mov edx, 0x7F00FF
	os_api print_string_cursor

	mov esi, string2
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	os_api get_char_wait

	mov esi, filename
	os_api execute_program

	mov esi, string3
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	os_api get_char_wait
	ret

string			db "Hello, my PID is ",0
string2			db "!",10
			db "Press any key to create another process...",10,0
string3			db "Back to the parent process, press any key to quit. :)",10,0
filename		db "hello2.exe",0

align 4096
end_of_file:


