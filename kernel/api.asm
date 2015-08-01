
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

os_api_max_function		= 27

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
	dd 0			; TO-DO: This should be run_v8086, but when v8086 monitor is completed...

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
	dd int_to_string
	dd hex_byte_to_string
	dd hex_word_to_string
	dd hex_dword_to_string
	dd compare_strings

	; Power-based routines
	dd reboot
	dd shutdown

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

