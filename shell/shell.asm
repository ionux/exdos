
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; shell/shell.asm							;;
;; ExDOS Shell								;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32
org 0x1000000

include			"shell/kapi.asm"

main:
	mov ebx, 0
	os_api clear_screen

	mov esi, crlf
	os_api print_string_cursor

	mov esi, title_msg
	mov ecx, 0
	mov edx, 0x2020BF
	os_api print_string_cursor

cmd:
	mov esi, crlf
	os_api print_string_cursor

	mov esi, prompt
	mov ecx, 0
	mov edx, 0x9F2020
	os_api print_string_cursor

	mov esi, input_buffer
	mov ebx, 0xDFDF00
	mov ecx, 0
	os_api get_string

	cmp byte[input_buffer], 0
	je cmd

	mov esi, input_buffer
	mov edi, help_command
	os_api compare_strings

	cmp eax, 0
	je help

	mov esi, input_buffer
	mov edi, clear_command
	os_api compare_strings

	cmp eax, 0
	je clear

	mov esi, input_buffer
	os_api execute_program

	cmp ebx, 0
	je cmd

	mov esi, bad_command
	mov ecx, 0
	mov edx, 0x9F2020
	os_api print_string_cursor

	mov esi, crlf
	os_api print_string_cursor

	jmp cmd

help:
	mov esi, help_msg
	mov ecx, 0
	mov edx, 0x2020BF
	os_api print_string_cursor

	mov esi, crlf
	os_api print_string_cursor

	jmp cmd

clear:
	mov ebx, 0
	os_api clear_screen

	jmp cmd

crlf			db 13,10,0
title_msg		db "ExDOS -- version 0.1 pre-alpha",13,10
			db "(C) 2015 by Omar Mohammad.",13,10
			db "All rights reserved.",13,10,0
prompt			db ">",0
bad_command		db "No such command or file name.",0
help_command		db "help",0
clear_command		db "clear",0
help_msg		db "ExDOS -- version 0.1 pre-alpha",13,10
			db "Command list:",13,10,13,10
			db " clear        -- Clears the screen",13,10
			db " exit         -- Shuts down the system",0

input_buffer:

