
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; shell/cat.asm							;;
;; ExDOS Shell -- Cat command						;;
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
	je show_usage

	mov esi, [esp+4]
	os_api get_file_size	; get file size so we know how much memory to allocate

	cmp eax, 0
	jne file_error

	mov edx, ecx		; EDX = File size
	os_api malloc		; ask the OS for memory

	cmp eax, 0		; if the OS returns a null pointer --
	je no_memory		; -- then there is no memory..

	mov [memory], eax

	mov esi, [esp+4]
	mov edi, [memory]
	os_api load_file	; load the file to the free memory area

	cmp eax, 0
	jne file_error2

	; print the contents of the file :)
	mov esi, [memory]
	mov ecx, 0x000020
	mov edx, 0x2020BF
	os_api print_string_cursor

	; free the unused memory
	mov edx, [memory]
	os_api free

	; and quit
	mov eax, 0
	ret

file_error2:
	mov edx, [memory]
	os_api free

file_error:
	mov esi, file_not_found_msg
	mov ecx, 0x000020
	mov edx, 0x2020BF
	os_api print_string_cursor

	mov eax, 1
	ret

no_memory:
	mov esi, no_memory_msg
	mov ecx, 0x000020
	mov edx, 0x2020BF
	os_api print_string_cursor

	mov eax, 1
	ret

show_usage:
	mov esi, usage_msg
	mov ecx, 0x000020
	mov edx, 0x2020BF
	os_api print_string_cursor

	mov eax, 0
	ret

memory				dd 0
usage_msg			db "usage: cat [filename]",10
				db "function: shows contents of a file.",10
				db "example: cat file.txt",10,0
no_memory_msg			db "cat: out of memory!",10,0
file_not_found_msg		db "cat: couldn't load file.",10,0

align 4096
end_of_file:

