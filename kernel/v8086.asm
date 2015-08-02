
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/v8086.asm							;;
;; v8086 Monitor							;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

v8086_running			db 0

; run_v8086:
; Runs some 16-bit code
; In\	EAX = Code offset (must be below 1 MB)
; Out\	Nothing

run_v8086:
	call text_mode

	cli

	mov byte[v8086_running], 1

	push 0			; SS = 0
	mov ebp, esp
	add ebp, 4
	push ebp		; ESP, and fix stack
	pushfd
	pop ebp
	or ebp, 0x20202		; EFLAGS = v8086 | interrupts
	push ebp
	push 0			; CS = 0
	lea ebp, [.next]
	push ebp		; v8086 stub
	iretd

use16			; we're in v8086 mode now! :)

.next:
	mov ax, 0
	;mov ss, ax		; IRETD did this for us
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	nop
	nop
	nop
	nop

	mov ax, 0x80
	mov bx, 4
	mul bx
	mov di, ax
	mov ax, .nexta
	stosw
	mov ax, 0
	stosw

	int 0x80
	jmp $

.nexta:
	iret
	jmp $

;;
;; ExDOS v8086 monitor core functions
;;

use32

; v8086_gpf_handler:
; Default GPF handler for v8086

v8086_gpf_handler:
	mov bp, 0x10
	mov ds, bp
	mov es, bp
	mov fs, bp
	mov gs, bp

	pop ebp
	mov [.return], ebp
	pop ebp
	mov [.cs], ebp
	pop ebp
	mov [.eflags], ebp
	pop ebp
	mov [.esp], ebp
	pop ebp
	mov [.ss], ebp

	mov ebp, [.return]
	cmp byte[ebp], 0xCD		; INT
	je v8086_do_int

	cmp byte[ebp], 0xFA		; CLI
	je v8086_do_cli

	cmp byte[ebp], 0xFB		; STI
	je v8086_do_sti

	cmp byte[ebp], 0xCF
	je v8086_do_iret

	mov byte[v8086_running], 0
	int 13				; make a real GPF

.return				dd 0
.cs				dd 0
.eflags				dd 0
.esp				dd 0
.ss				dd 0

; v8086_gpf_return:
; Returns from the v8086 GPF handler

v8086_gpf_return:
	mov eax, [v8086_gpf_handler.ss]
	push eax
	mov eax, [v8086_gpf_handler.esp]
	push eax
	mov eax, [v8086_gpf_handler.eflags]
	push eax
	mov eax, [v8086_gpf_handler.cs]
	push eax
	mov eax, [v8086_gpf_handler.return]
	push eax

	iretd

; v8086_do_cli:
; Emulates a CLI instruction

v8086_do_cli:
	mov eax, [v8086_gpf_handler.eflags]
	and eax, 0xFFFFFDFF			; clear IF flag
	or eax, 2
	mov [v8086_gpf_handler.eflags], eax
	add dword[v8086_gpf_handler.return], 1	; CLI instruction is 1 byte in size

	jmp v8086_gpf_return

; v8086_do_sti:
; Emulates a STI instruction

v8086_do_sti:
	mov eax, [v8086_gpf_handler.eflags]
	or eax, 0x202
	mov [v8086_gpf_handler.eflags], eax
	add dword[v8086_gpf_handler.return], 1

	jmp v8086_gpf_return

; v8086_do_int:
; Raises an interrupt in v8086 mode

v8086_do_int:
	;mov [.stack], esp
	pusha
	cli

	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	;mov [.return], ebp
	add ebp, 1
	mov al, byte[ebp]

	and eax, 0xFF
	mov ebx, 4
	mul ebx

	mov ebp, eax
	mov ax, word[ebp]
	and eax, 0xFFFF
	mov [.offset], eax
	mov ax, word[ebp+2]
	and eax, 0xFFFF
	mov [.segment], eax

	;mov ax, 0
	;mov ds, ax
	;mov es, ax
	;mov fs, ax
	;mov gs, ax

	mov eax, [v8086_gpf_handler.ss]
	mov [.ss], eax
	mov eax, [v8086_gpf_handler.esp]
	mov [.esp], eax
	mov eax, [v8086_gpf_handler.cs]

	popa
	push dword[v8086_gpf_handler.ss]
	push dword[v8086_gpf_handler.esp]
	push dword[v8086_gpf_handler.eflags]
	push dword[v8086_gpf_handler.cs]
	push dword[v8086_gpf_handler.return]

	push dword[v8086_gpf_handler.ss]
	push dword[v8086_gpf_handler.esp]
	sub dword[esp], 20
	push dword[v8086_gpf_handler.eflags]
	push 0
	push .next
	iretd

use16

.next:
	pusha
	mov ax, 0
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	popa
	push word[.segment]
	push word[.offset]
	retf

.offset				dd 0
.segment			dd 0
.ss				dd 0
.esp				dd 0
.eflags				dd 0
.cs				dd 0
.eip				dd 0

use32

; v8086_do_iret:
; Emulates an IRET instruction

v8086_do_iret:
	mov [.backup_esp], esp
	pusha
	mov esp, [v8086_gpf_handler.esp]

	pop ebp
	;mov [.eip], ebp
	pop eax
	jmp $
	iretd

use16

.next:
	jmp $

.backup_esp			dd 0
.ss				dd 0
.esp				dd 0
.eflags				dd 0
.cs				dd 0
.eip				dd 0


