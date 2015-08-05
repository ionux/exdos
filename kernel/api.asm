
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/os_api.asm							;;
;; Kernel API								;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

os_api_max_function		= 35

; os_api:
; Kernel API Entry Point
; In\	EAX = Function number
; In\	All other registers = Depends on function input
; Out\	All registers = Depends on function output

os_api:
	pusha
	call enter_ring0		; ensure the API runs in ring 0
	popa

	pusha
	cmp eax, os_api_max_function
	jg .bad
	popa

	pusha
	mov ebx, 4
	mul ebx
	mov edi, os_api_table
	add edi, eax
	mov eax, dword[edi]
	mov [.tmp], eax
	popa

	mov eax, [.tmp]
	call eax

	pusha
	call enter_ring3		; ensure we continue execution in user mode
	popa
	ret

.bad:
	popa
	call enter_ring3
	mov eax, 0xBADFBADF
	ret

.tmp			dd 0

; os_api_table:
; Call table for API functions

os_api_table:
	; Core routines
	dd execute_program
	dd mem_info
	dd kernel_info
	dd kdebug_get_location			; Changed my mind, v8086 should be available for drivers only, not programs.

	; Display routines
	dd clear_screen
	dd print_string_graphics_cursor
	dd print_string_graphics
	dd print_string_transparent
	dd move_cursor_graphics
	dd put_pixel
	dd draw_horz_line
	dd fill_rect
	dd alpha_draw_horz_line
	dd alpha_fill_rect
	dd alpha_blend_colors
	dd draw_image

	; Keyboard routines
	dd get_char_wait
	dd get_char_no_wait
	dd get_string_echo

	; String-based routines
	dd get_string_size
	dd chomp_string
	dd .int_to_string
	dd .hex_byte_to_string
	dd .hex_word_to_string
	dd .hex_dword_to_string
	dd compare_strings

	; Power-based routines
	dd reboot
	dd shutdown

	; Time-based routines
	dd get_time_24
	dd get_time_12
	dd get_time_string_24
	dd get_time_string_12
	dd get_date
	dd get_date_string_am
	dd get_date_string_me
	dd get_long_date_string

.int_to_string:
	mov eax, ebx
	call int_to_string
	ret

.hex_byte_to_string:
	mov eax, ebx
	call hex_byte_to_string
	ret

.hex_word_to_string:
	mov eax, ebx
	call hex_word_to_string
	ret

.hex_dword_to_string:
	mov eax, ebx
	call hex_dword_to_string
	ret

; mem_info:
; Gets memory information
; In\	Nothing
; Out\	EAX = Total memory in KB
; Out\	EBX = Free memory in KB
; Out\	ECX = Used memory in KB

mem_info:
	mov eax, [free_memory]
	mov ebx, 4
	mul ebx
	mov [.free], eax
	mov eax, [used_memory]
	mov ebx, 4
	mul ebx
	mov [.used], eax
	mov eax, [total_memory_kb]
	mov ebx, [.free]
	mov ecx, [.used]

	ret

.used			dd 0
.free			dd 0

; kernel_info:
; Gets kernel information
; In\	Nothing
; Out\	ESI = Kernel version string
; Out\	EAX = API version

kernel_info:
	mov esi, _kernel_version
	mov eax, [_api_version]

	ret

