
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
; In\	EAX = Code offset (must be below 1 MB!)
; Out\	Nothing

run_v8086:
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

	;out dx, al		; for debugging

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
	

; v8086_do_cli:
; Emulates a CLI instruction

v8086_do_cli:
	pushfd
	pop eax
	;and eax, 

v8086_do_sti:

; v8086_do_int:
; Raises an interrupt in v8086 mode

v8086_do_int:
	add ebp, 1
	mov al, byte[ebp]
	and eax, 0xFF			; get segment:offset of interrupt handler in IVT
	mov ebx, 4
	mul ebx
	mov ebp, eax

	mov ax, word[ebp]
	mov bx, word[ebp+2]

	mov [.offset], ax
	mov [.segment], bx

	mov eax, [v8086_gpf_handler.ss]
	push ax
	push sp
	pushf
	mov eax, [v8086_gpf_handler.cs]
	push ax
	mov eax, [v8086_gpf_handler.return]
	push ax


	jmp $

.offset				dw 0
.segment			dw 0

