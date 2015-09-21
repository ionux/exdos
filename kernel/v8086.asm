
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

;; Functions:
; run_v8086

use32

v8086_running			db 0

; run_v8086:
; Runs some 16-bit code
; In\	CX:DX = Segment:Offset
; Out\	Nothing
; Note:	To quit the v8086 task, the 16-bit task must call end_v8086 and pass its return value in EAX.

run_v8086:
	mov [.segment], cx
	mov [.offset], dx

	mov byte[v8086_running], 1

	mov eax, 0
	mov ebx, 0
	mov ecx, 256
	mov edx, 7				; user, present, read/write
	call vmm_map_memory

	mov esi, .debug_msg1
	call kdebug_print

	mov ax, [.segment]
	call hex_word_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg2
	call kdebug_print_noprefix

	mov ax, [.offset]
	call hex_word_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	cli
	mov ebp, esp
	push 0			; SS
	push ebp		; ESP
	pushfd
	pop eax
	or eax, 0x20202		; VM | IF | PF
	push eax
	push 0			; CS
	push .next		; EIP
	iret

use16

.next:
	; Welcome to v8086 mode!
	mov ax, 0
	;mov ss, ax		; IRET did this for us
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	jmp $

.segment			dw 0
.offset				dw 0
.debug_msg1			db "v8086: creating 16-bit task at segment:offset 0x",0
.debug_msg2			db ":0x",0

; v8086_debug_print:
; Test routine for I/O functions in v8086 mode, prints a string to the Bochs console using port 0xE9 hack
; In\	DS:SI = ASCIIZ string
; Out\	Nothing

v8086_debug_print:
	lodsb
	cmp al, 0
	je .done
	out 0xE9, al
	jmp v8086_debug_print

.done:
	ret

;; V8086 MONITOR CORE

use32

; v8086_monitor:
; v8086 monitor entry point

v8086_monitor:
	push ebp

	mov ebp, esp
	add ebp, 4

	push ds
	push es
	push fs
	push gs

	push 0x10		; fix segment registers without playing with general purpose registers
	pop ds
	push ds
	pop es
	push es
	pop fs
	push fs
	pop gs

	push ebp
	mov ebp, [esp+24]

	cmp byte[ebp], 0xFA		; CLI
	je v8086_cli

	cmp byte[ebp], 0xFB		; STI
	je v8086_sti

	cmp byte[ebp], 0xF4		; HLT
	je v8086_hlt

	cmp byte[ebp], 0xE6		; OUT imm8, AL
	je v8086_out_imm8_al

	cmp byte[ebp], 0xE7		; OUT imm8, AX
	je v8086_out_imm8_ax

	cmp word[ebp], 0xE766		; OUT imm8, EAX
	je v8086_out_imm8_eax

	cmp byte[ebp], 0xE4		; IN AL, imm8
	je v8086_in_imm8_al

	cmp byte[ebp], 0xE5		; IN AX, imm8
	je v8086_in_imm8_ax

	cmp word[ebp], 0xE566		; IN EAX, imm8
	je v8086_in_imm8_eax

	cmp byte[ebp], 0xEE		; OUT DX, AL
	je v8086_out_dx_al

	cmp byte[ebp], 0xEF		; OUT DX, AX
	je v8086_out_dx_ax

	cmp word[ebp], 0xEF66		; OUT DX, EAX
	je v8086_out_dx_eax

	cmp byte[ebp], 0xEC		; IN AL, DX
	je v8086_in_al_dx

	cmp byte[ebp], 0xED		; IN AX, DX
	je v8086_in_ax_dx

	cmp word[ebp], 0xED66		; IN EAX, DX
	je v8086_in_eax_dx

	cmp byte[ebp], 0x6C		; INSB
	je v8086_insb

	cmp word[ebp], 0x6CF3		; REP INSB
	je v8086_rep_insb

	cmp byte[ebp], 0x6D		; INSW
	je v8086_insw

	cmp word[ebp], 0x6DF3		; REP INSW
	je v8086_rep_insw

	cmp byte[ebp], 0x6E		; OUTSB
	je v8086_outsb

	cmp word[ebp], 0x6EF3		; REP OUTSB
	je v8086_rep_outsb

	cmp byte[ebp], 0x6F		; OUTSW
	je v8086_outsw

	cmp word[ebp], 0x6FF3		; REP OUTSW
	je v8086_rep_outsw

	pop ebp
	pop gs
	pop fs
	pop es
	pop ds
	pop ebp
	mov byte[ss:v8086_running], 0
	int 13			; make a real GPF

; v8086_return_to_task:
; Quits the monitor and returns to the 16-bit task

v8086_return_to_task:
	pop gs
	pop fs
	pop es
	pop ds
	pop ebp
	iret

; v8086_cli:
; Emulates CLI instruction

v8086_cli:
	pop ebp
	add dword[ss:ebp], 1		; CLI instruction is 1 byte in size
	and dword[ss:ebp+8], 0xFFFFFDFF	; clear IF
	jmp v8086_return_to_task

; v8086_sti:
; Emulates STI instruction

v8086_sti:
	pop ebp
	add dword[ss:ebp], 1
	or dword[ss:ebp+8], 0x200
	jmp v8086_return_to_task

; v8086_hlt:
; Emulates HLT instruction

v8086_hlt:
	pop ebp
	add dword[ss:ebp], 1
	hlt
	jmp v8086_return_to_task

; v8086_out_imm8_al:
; Emulates OUT instruction (out imm8, al)

v8086_out_imm8_al:
	push edx
	mov dl, byte[ebp+1]
	and dx, 0xFF
	out dx, al			; do the I/O requested
	call iowait
	pop edx

	pop ebp
	add dword[ss:ebp], 2
	jmp v8086_return_to_task

; v8086_out_imm8_ax:
; Emulates OUT instruction (out imm8, ax)

v8086_out_imm8_ax:
	push edx
	mov dl, byte[ebp+1]
	and dx, 0xFF
	out dx, ax			; do the I/O requested
	call iowait
	pop edx

	pop ebp
	add dword[ss:ebp], 2
	jmp v8086_return_to_task

; v8086_out_imm8_eax:
; Emulates OUT instruction (out imm8, eax)

v8086_out_imm8_eax:
	push edx
	mov dl, byte[ebp+2]
	and dx, 0xFF
	out dx, eax			; do the I/O requested
	call iowait
	pop edx

	pop ebp
	add dword[ss:ebp], 3
	jmp v8086_return_to_task

; v8086_in_imm8_al:
; Emulates IN instruction (in al, imm8)

v8086_in_imm8_al:
	push edx
	mov dl, byte[ebp+1]
	and dx, 0xFF
	in al, dx
	call iowait
	pop edx

	pop ebp
	add dword[ss:ebp], 2
	jmp v8086_return_to_task

; v8086_in_imm8_ax:
; Emulates IN instruction (in ax, imm8)

v8086_in_imm8_ax:
	push edx
	mov dl, byte[ebp+1]
	and dx, 0xFF
	in ax, dx
	call iowait
	pop edx

	pop ebp
	add dword[ss:ebp], 2
	jmp v8086_return_to_task

; v8086_in_imm8_eax:
; Emulates IN instruction (in eax, imm8)

v8086_in_imm8_eax:
	push edx
	mov dl, byte[ebp+1]
	and dx, 0xFF
	in eax, dx
	call iowait
	pop edx

	pop ebp
	add dword[ss:ebp], 3
	jmp v8086_return_to_task

; v8086_out_dx_al:
; Emulates OUT instruction (out dx, al)

v8086_out_dx_al:
	out dx, al
	call iowait

	pop ebp
	add dword[ss:ebp], 1
	jmp v8086_return_to_task

; v8086_out_dx_ax:
; Emulates OUT instruction (out dx, ax)

v8086_out_dx_ax:
	out dx, ax
	call iowait

	pop ebp
	add dword[ss:ebp], 1
	jmp v8086_return_to_task

; v8086_out_dx_eax:
; Emulates OUT instruction (out dx, eax)

v8086_out_dx_eax:
	out dx, eax
	call iowait

	pop ebp
	add dword[ss:ebp], 2
	jmp v8086_return_to_task

; v8086_in_al_dx:
; Emulates IN instruction (in al, dx)

v8086_in_al_dx:
	in al, dx
	call iowait

	pop ebp
	add dword[ss:ebp], 1
	jmp v8086_return_to_task

; v8086_in_ax_dx:
; Emulates IN instruction (in ax, dx)

v8086_in_ax_dx:
	in ax, dx
	call iowait

	pop ebp
	add dword[ss:ebp], 1
	jmp v8086_return_to_task

; v8086_in_eax_dx:
; Emulates IN instruction (in eax, dx)

v8086_in_eax_dx:
	in eax, dx
	call iowait

	pop ebp
	add dword[ss:ebp], 2
	jmp v8086_return_to_task

; v8086_insb:
; Emulates INSB instruction

v8086_insb:
	insb
	call iowait

	pop ebp
	add dword[ss:ebp], 1
	jmp v8086_return_to_task

; v8086_rep_insb:
; Emulates INSB instruction with REP prefix

v8086_rep_insb:
	rep insb
	call iowait

	pop ebp
	add dword[ss:ebp], 2
	jmp v8086_return_to_task

; v8086_insw:
; Emulates INSW instruction

v8086_insw:
	insw
	call iowait

	pop ebp
	add dword[ss:ebp], 1
	jmp v8086_return_to_task

; v8086_rep_insw:
; Emulates INSW instruction with REP prefix

v8086_rep_insw:
	rep insw
	call iowait

	pop ebp
	add dword[ss:ebp], 2
	jmp v8086_return_to_task

; v8086_outsb:
; Emulates OUTSB instruction

v8086_outsb:
	outsb
	call iowait

	pop ebp
	add dword[ss:ebp], 1
	jmp v8086_return_to_task

; v8086_rep_outsb:
; Emulates OUTSB instruction with REP prefix

v8086_rep_outsb:
	rep outsb
	call iowait

	pop ebp
	add dword[ss:ebp], 2
	jmp v8086_return_to_task

; v8086_outsw:
; Emulates OUTSW instruction

v8086_outsw:
	outsw
	call iowait

	pop ebp
	add dword[ss:ebp], 1
	jmp v8086_return_to_task

; v8086_rep_outsw:
; Emulates OUTSW instruction with REP prefix

v8086_rep_outsw:
	rep outsw
	call iowait

	pop ebp
	add dword[ss:ebp], 2
	jmp v8086_return_to_task





