
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
	os_api show_text_cursor			; show text cursor

	mov bx, 8				; mouse width 8
	mov cx, 16				; height 16
	mov edx, 0x7F7F7F			; color dark gray
	os_api set_mouse_cursor
	os_api show_mouse_cursor		; and show the cursor

	mov esi, crlf
	os_api print_string_cursor

	mov esi, prompt
	mov ecx, 0
	mov edx, 0x209F20
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
	mov edi, exit_command
	os_api compare_strings

	cmp eax, 0
	je exit

	mov esi, input_buffer
	mov edi, reboot_command
	os_api compare_strings

	cmp eax, 0
	je reboot_

	mov esi, input_buffer
	mov edi, kdebug_command
	os_api compare_strings

	cmp eax, 0
	je kdebug

	mov esi, input_buffer
	mov edi, meminfo_command
	os_api compare_strings

	cmp eax, 0
	je meminfo

	mov esi, input_buffer
	mov edi, time_command
	os_api compare_strings

	cmp eax, 0
	je time

	mov esi, input_buffer
	mov edi, date_command
	os_api compare_strings

	cmp eax, 0
	je date

	mov esi, input_buffer
	os_api execute_program

	cmp ebx, 0
	je cmd

	cmp ebx, 0xDEADC0DE
	je error_program

	cmp ebx, 0xBADC0DE
	je corrupt_program

	cmp ebx, 0xFFFFFFFF
	je mem_error_program

	mov esi, bad_command
	mov ecx, 0
	mov edx, 0x9F2020
	os_api print_string_cursor

	mov esi, crlf
	os_api print_string_cursor

	jmp cmd

error_program:
	mov esi, error_msg
	mov ecx, 0
	mov edx, 0x9F2020
	os_api print_string_cursor

	mov esi, crlf
	os_api print_string_cursor

	jmp cmd

corrupt_program:
	mov esi, corrupt_msg
	mov ecx, 0
	mov edx, 0x9F2020
	os_api print_string_cursor

	mov esi, crlf
	os_api print_string_cursor

	jmp cmd

mem_error_program:
	mov esi, not_enough_mem_msg
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

exit:
	os_api shutdown

reboot_:
	os_api reboot

kdebug:
	os_api kdebug_get_location		; get location of kernel debugger in EAX

	mov esi, eax
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor		; and print all debug messages :)

	jmp cmd

meminfo:
	os_api get_memory_info
	mov [.total], eax
	mov [.free], ebx
	mov [.used], ecx

	mov eax, [.total]
	mov ebx, 1024
	mov edx, 0
	div ebx
	mov [.total], eax

	mov eax, [.free]
	mov ebx, 1024
	mov edx, 0
	div ebx
	mov [.free], eax

	mov eax, [.used]
	mov ebx, 1024
	mov edx, 0
	div ebx
	mov [.used], eax

	mov esi, .total_memory
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov ebx, [.total]
	os_api int_to_string
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov esi, .mb
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov esi, .free_memory
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov ebx, [.free]
	os_api int_to_string
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov esi, .mb
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov esi, .used_memory
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov ebx, [.used]
	os_api int_to_string
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov esi, .mb
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	jmp cmd

.total			dd 0
.free			dd 0
.used			dd 0
.total_memory		db "Total memory: ",0
.used_memory		db "Used memory: ",0
.free_memory		db "Free memory: ",0
.mb			db " MB",10,0

time:
	os_api get_time_string_12
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov esi, crlf
	os_api print_string_cursor
	jmp cmd

date:
	os_api get_long_date_string
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov esi, crlf
	os_api print_string_cursor
	jmp cmd

crlf			db 13,10,0
title_msg		db "ExDOS -- version 0.1 pre-alpha",13,10
			db "(C) 2015 by Omar Mohammad.",13,10
			db "All rights reserved.",13,10,0
prompt			db ">",0
bad_command		db "No such command or file name.",0
error_msg		db "This program has caused an error and has been forcefully terminated.",13,10
			db "Run kdebug for more information.",0
corrupt_msg		db "Program file is corrupt or not valid.",0
not_enough_mem_msg	db "Program is too large to fit in memory.",0
help_command		db "help",0
clear_command		db "clear",0
exit_command		db "exit",0
kdebug_command		db "kdebug",0
reboot_command		db "reboot",0
meminfo_command		db "meminfo",0
time_command		db "time",0
date_command		db "date",0
help_msg		db "ExDOS -- version 0.1 pre-alpha",13,10
			db "Command list:",13,10,13,10
			db " clear        -- Clears the screen",13,10
			db " date         -- Shows the date",13,10
			db " exit         -- Shuts down the system",13,10
			db " kdebug       -- Shows kernel messages",13,10
			db " meminfo      -- Shows memory usage",13,10
			db " reboot       -- Reboots the PC",13,10
			db " time         -- Shows the time",0

input_buffer:

