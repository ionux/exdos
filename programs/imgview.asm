
;;
;; Simple image viewer
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
	mov esi, [esp+4]		; program parameters
	cmp esi, 0
	je show_usage

	mov esi, [esp+4]
	os_api get_file_size		; get file size so we can allocate memory for it

	cmp eax, 0
	jne file_error

	mov edx, ecx			; EDX = file size
	os_api malloc

	cmp eax, 0
	je memory_error

	mov [memory], eax

	mov esi, [esp+4]
	mov edi, [memory]
	os_api load_file		; load the file into the free memory area

	cmp eax, 0
	jne file_error2

	os_api hide_text_cursor

	mov ebx, 0
	os_api clear_screen

	mov esi, [memory]
	mov ebx, 0
	mov ecx, 0
	os_api draw_image

	cmp eax, 1
	je corrupt

	cmp eax, 2
	je too_big

	os_api get_char_wait
	mov ebx, 0x000020
	os_api clear_screen

	mov eax, 0
	ret

too_big:
	mov ebx, 0x000020
	os_api clear_screen
	mov esi, too_big_msg
	mov ecx, 0x000020
	mov edx, 0x2020BF
	os_api print_string_cursor

	jmp $

	mov eax, 1
	ret

file_error2:
	mov edx, [memory]
	os_api free

file_error:
	mov esi, file_error_msg
	mov ecx, 0x000020
	mov edx, 0x2020BF
	os_api print_string_cursor

	mov eax, 1
	ret

corrupt:
	mov ebx, 0x000020
	os_api clear_screen
	mov esi, corrupt_msg
	mov ecx, 0x000020
	mov edx, 0x2020BF
	os_api print_string_cursor

	mov eax, 1
	ret

memory_error:
	mov esi, memory_error_msg
	mov ecx, 0x000020
	mov edx, 0x2020BF
	os_api print_string_cursor

	mov eax, 1
	ret

show_usage:
	mov esi, usage_msg
	mov ecx, 0x000020
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov eax, 0
	ret

memory				dd 0
usage_msg			db "usage: imgview [filename]",10
				db "function: shows a BMP image.",10
				db "example: imgview image.bmp",10,0
file_error_msg			db "imgview: couldn't load file.",10,0
memory_error_msg		db "imgview: file too large to fit in memory!",10,0
too_big_msg			db "imgview: image too big to fit on screen.",10,0
corrupt_msg			db "imgview: BMP file is corrupt or not valid.",10,0

align 4096
end_of_file:
