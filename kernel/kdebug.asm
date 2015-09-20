
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/kdebug.asm							;;
;; Built-in Kernel Debugger						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Functions:
; kdebug_init
; kdebug_get_location
; kdebug_print
; kdebug_print_noprefix
; dump_registers
; kdebug_dump

kdebugger_location			= 0x20000		; 0x20000=>0x40000 (128 KB) is reserved for kernel debugger
kdebugger_free_location			dd 0

; Each debug message has this format:
; [SSSS.TTTTTTTT] component: message.
; Where SSSS is the uptime in seconds shown in hex, TTTTTTTT is the uptime in PIT IRQ0 shown in hex as well.

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
	call hex_dword_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	cmp byte[is_there_serial], 0
	je .no_serial_

	mov esi, .serial
	call kdebug_print

	mov ax, [serial_ioport]
	call hex_word_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	ret

.no_serial_:
	mov esi, .no_serial
	call kdebug_print

	ret

.done_msg			db "kernel: kernel debugger started at address 0x",0
.serial				db "serial: base IO port is 0x",0
.no_serial			db "serial: no serial port present.",10,0

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

	mov al, '['
	mov edi, .timestamp
	stosb

	mov ax, word[uptime]
	call hex_word_to_string
	mov edi, .timestamp+1
	mov ecx, 4
	rep movsb

	mov eax, dword[ticks]
	call hex_dword_to_string
	mov edi, .timestamp+6
	mov ecx, 8
	rep movsb

	mov esi, .timestamp
	call send_string_via_serial

	mov esi, .timestamp
	mov edi, [kdebugger_free_location]
	mov ecx, 16
	rep movsb
	mov [kdebugger_free_location], edi

	mov esi, [.string]
	call send_string_via_serial

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
.timestamp			db "[0000.00000000] ",0

; kdebug_print_noprefix:
; Prints a kernel debug message without the timestamp prefix
; In\	ESI = Message
; Out\	Nothing

kdebug_print_noprefix:
	pusha
	mov [.string], esi

	mov esi, [.string]
	call send_string_via_serial

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

; dump_registers:
; Dumps all registers to the kernel debugger

dump_registers:
	mov [.eax], eax
	mov [.ebx], ebx
	mov [.ecx], ecx
	mov [.edx], edx
	mov [.esp], esp
	mov [.ebp], ebp
	mov [.esi], esi
	mov [.edi], edi
	pushfd
	pop eax
	mov [.flags], eax
	mov eax, cr0
	mov [.cr0], eax
	mov eax, cr2
	mov [.cr2], eax
	mov eax, cr3
	mov [.cr3], eax
	mov eax, cr4
	mov [.cr4], eax

	mov eax, [.eax]
	call hex_dword_to_string
	mov edi, .msg2+8
	mov ecx, 8
	rep movsb

	mov eax, [.ebx]
	call hex_dword_to_string
	mov edi, .msg2+25
	mov ecx, 8
	rep movsb

	mov eax, [.ecx]
	call hex_dword_to_string
	mov edi, .msg2+42
	mov ecx, 8
	rep movsb

	mov eax, [.edx]
	call hex_dword_to_string
	mov edi, .msg2+59
	mov ecx, 8
	rep movsb

	mov eax, [.esp]
	call hex_dword_to_string
	mov edi, .msg3+8
	mov ecx, 8
	rep movsb

	mov eax, [.ebp]
	call hex_dword_to_string
	mov edi, .msg3+25
	mov ecx, 8
	rep movsb

	mov eax, [.flags]
	call hex_dword_to_string
	mov edi, .msg3+44
	mov ecx, 8
	rep movsb

	mov eax, [.cr0]
	call hex_dword_to_string
	mov edi, .msg3+59
	mov ecx, 8
	rep movsb

	mov eax, [.cr2]
	call hex_dword_to_string
	mov edi, .msg4+8
	mov ecx, 8
	rep movsb

	mov eax, [.cr3]
	call hex_dword_to_string
	mov edi, .msg4+25
	mov ecx, 8
	rep movsb

	mov eax, [.cr4]
	call hex_dword_to_string
	mov edi, .msg4+42
	mov ecx, 8
	rep movsb

	mov ax, [.cs]
	call hex_word_to_string
	mov edi, .msg4+58
	mov ecx, 4
	rep movsb

	mov ax, [.ds]
	call hex_word_to_string
	mov edi, .msg5+7
	mov ecx, 4
	rep movsb

	mov ax, [.es]
	call hex_word_to_string
	mov edi, .msg5+24
	mov ecx, 4
	rep movsb

	mov ax, [.fs]
	call hex_word_to_string
	mov edi, .msg5+41
	mov ecx, 4
	rep movsb

	mov ax, [.gs]
	call hex_word_to_string
	mov edi, .msg5+58
	mov ecx, 4
	rep movsb

	mov eax, [.esi]
	call hex_dword_to_string
	mov edi, .msg6+8
	mov ecx, 8
	rep movsb

	mov eax, [.edi]
	call hex_dword_to_string
	mov edi, .msg6+25
	mov ecx, 8
	rep movsb

	mov esi, .msg1
	call kdebug_print
	mov esi, .msg2
	call kdebug_print
	mov esi, .msg3
	call kdebug_print
	mov esi, .msg4
	call kdebug_print
	mov esi, .msg5
	call kdebug_print
	mov esi, .msg6
	call kdebug_print

	ret
	

.msg1				db "kernel: dumping all registers...",10,0
.msg2				db "  eax = 00000000   ebx = 00000000   ecx = 00000000   edx = 00000000",10,0
.msg3				db "  esp = 00000000   ebp = 00000000   flags = 00000000 cr0 = 00000000",10,0
.msg4				db "  cr2 = 00000000   cr3 = 00000000   cr4 = 00000000   cs = 0000",10,0
.msg5				db "  ds = 0000        es = 0000        fs = 0000        gs = 0000",10,0
.msg6				db "  esi = 00000000   edi = 00000000",10,0
.eax				dd 0
.ebx				dd 0
.ecx				dd 0
.edx				dd 0
.esp				dd 0
.ebp				dd 0
.flags				dd 0
.cr0				dd 0
.cr2				dd 0
.cr3				dd 0
.cr4				dd 0
.cs				dw 0
.ds				dw 0
.es				dw 0
.fs				dw 0
.gs				dw 0
.esi				dd 0
.edi				dd 0

; kdebug_dump:
; Dumps the kernel debug messages to the file kernel.log
; In\	Nothing
; Out\	EFLAGS = Carry clear on success

kdebug_dump:
	mov esi, kdebugger_location
	call get_string_size			; to know how many bytes we need to write to the disk...
	mov ecx, eax
	mov esi, .filename
	mov edi, kdebugger_location
	call write_file

	cmp eax, 0
	jne .error

	clc
	ret

.error:
	stc
	ret

.filename			db "kernel.log",0



