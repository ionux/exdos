
;;
;; HeapTest
;; Simple program for testing malloc() and free()
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
	mov esi, msg1
	mov ecx, 0x000020
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov edx, 80		; allocate 80 bytes of memory
	os_api malloc
	mov [memory], eax

	mov esi, msg2
	mov ecx, 0x000020
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov ebx, [memory]
	os_api hex_dword_to_string
	;mov esi, msg2
	mov ecx, 0x000020
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	;jmp $

	mov esi, msg3
	mov ecx, 0x000020
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov esi, msg6
	mov edi, [memory]
	mov ecx, 7
	rep movsb

	mov esi, msg4
	mov ecx, 0x000020
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov esi, [memory]
	mov ecx, 0x000020
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov esi, msg5
	mov ecx, 0x000020
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov edx, [memory]
	os_api free

	ret

memory				dd 0
msg1				db "Allocating 80 bytes of memory...",10,0
msg2				db "Done, allocated memory at location 0x",0
msg3				db 10,"Copying 'Hello!' to the allocated memory...",10,0
msg4				db "Printing contents of the allocated memory: ",0
msg5				db 10,"Freeing memory...",10,0
msg6				db "Hello!",0

align 4096
end_of_file:

