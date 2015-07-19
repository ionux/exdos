
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

os_api_return				dd 0
os_api_eflags				dd 0
os_api_esp				dd 0

; os_api:
; Kernel API Entry Point
; In\	EAX = Function number
; In\	All other registers = Depends on function input
; Out\	All registers = Depends on function output

os_api:
	pop ebp
	add ebp, 2
	mov [os_api_return], ebp
	pop ebp				; CS
	pop ebp				; EFLAGS
	mov [os_api_eflags], ebp
	pop ebp				; ESP
	mov [os_api_esp], ebp
	pop ebp

	sti

	cmp eax, max_call
	jg .bad_call

	push ebx
	push edi
	mov ebx, 4
	mul ebx
	mov edi, api_call_table
	add edi, eax
	mov eax, dword[edi]
	pop edi
	pop ebx

	call eax

	jmp os_api_quit

.bad_call:
	mov eax, 0xBADFBADF
	jmp os_api_quit

; os_api_quit:
; Quits from an API call

os_api_quit:
	mov ebp, [os_api_eflags]
	or ebp, 0x202
	push ebp
	popfd

	mov ecx, [os_api_esp]
	mov edx, .next
	sysexit				; SYSEXIT is easier than IRET, and doesn't require TSS and shit like that

.next:
	mov bp, 0x23
	mov ds, bp
	mov es, bp
	mov fs, bp
	mov gs, bp

	mov ebp, [os_api_eflags]
	or ebp, 0x202			; enable interrupts
	push ebp
	popfd

	mov ebp, [os_api_return]
	jmp ebp

; api_call_table:
; Lookup table for kernel API

api_call_table:
	dd terminate_program
	dd execute_program
	dd kernel_info
	dd system_info
	dd clear_screen
	dd .print_string_graphics_cursor
	dd print_string_transparent
	dd print_string_graphics
	dd move_cursor_graphics
	dd get_char_wait
	dd get_char_no_wait
	dd get_string_echo
	dd get_string_size
	dd compare_strings

.print_string_graphics_cursor:
	mov edx, ebx
	call print_string_graphics_cursor

	ret

max_call			= 0x0D

; kernel_info:
; Gets basic kernel information
; In\	Nothing
; Out\	EAX = Kernel API version
; Out\	ESI = Kernel version string

kernel_info:
	mov eax, api_version
	mov esi, _kernel_version

	ret

; system_info:
; Gets basic system information
; In\	Nothing
; Out\	AX = Screen width
; Out\	BX = Screen height
; Out\	ECX = Total memory in 4 KB blocks
; Out\	EDX = Used memory in 4 KB blocks

system_info:
	mov ax, [syswidth]
	mov bx, [sysheight]
	mov ecx, [total_memory]
	mov edx, [used_memory]

	ret


