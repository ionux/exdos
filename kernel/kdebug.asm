
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; shell/kdebug.asm							;;
;; Built-in Kernel Debugger						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

kdebugger_location			= 0x20000		; 128 KB is reserved for kernel debugger
kdebugger_free_location			dd 0

; kdebug_init:
; Initializes the kernel debugger

kdebug_init:
	mov eax, kdebugger_location
	mov [kdebugger_free_location], eax

	mov edi, kdebugger_location
	mov ecx, 0x40000-kdebugger_location
	mov eax, 0
	rep stosb

	mov esi, _kernel_version
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	mov esi, .done_msg
	call kdebug_print

	mov eax, kdebugger_location
	mov ebx, kdebugger_location
	mov ecx, 32
	mov edx, 5				; user, present, read-only
	call vmm_map_memory

	mov eax, cr0
	and eax, 0xFFFEFFFF			; ensure the kernel can write to read-only pages
	mov cr0, eax

	ret

.done_msg			db "kernel: kernel debugger started.",10,0

; kdebug_get_location:
; Gets location of kernel debugger
; In\	Nothing
; Out\	EAX = Location of kernel debugger

kdebug_get_location:
	mov eax, kdebugger_location
	ret

; kdebug_print:
; Prints a kernel debug message
; In\	ESI = Kernel message
; Out\	Nothing

kdebug_print:
	pusha
	mov [.string], esi

	mov edi, [kdebugger_free_location]
	mov al, '['
	stosb
	mov [kdebugger_free_location], edi

	mov eax, [uptime]
	call hex_word_to_string

	mov edi, [kdebugger_free_location]
	mov ecx, 4
	rep movsb

	mov al, '.'
	stosb
	mov [kdebugger_free_location], edi

	mov eax, [ticks]
	call hex_dword_to_string

	mov edi, [kdebugger_free_location]
	mov ecx, 8
	rep movsb

	mov al, ']'
	stosb
	mov al, ' '
	stosb

	mov [kdebugger_free_location], edi
	mov esi, [.string]
	call get_string_size

	mov ecx, eax
	mov esi, [.string]
	mov edi, [kdebugger_free_location]
	rep movsb

	mov [kdebugger_free_location], edi
	popa
	ret

.string				dd 0

; kdebug_print_noprefix:
; Prints a kernel debug message without the timestamp prefix
; In\	ESI = Message
; Out\	Nothing

kdebug_print_noprefix:
	pusha
	mov [.string], esi

	mov esi, [.string]
	call get_string_size

	mov ecx, eax
	mov esi, [.string]
	mov edi, [kdebugger_free_location]
	rep movsb

	mov [kdebugger_free_location], edi
	popa
	ret

.string				dd 0

