
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/isr.asm							;;
;; Interrupt Service Routines						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

; install_isr:
; Installs an ISR
; In\	AL = Interrupt number
; In\	EBP = Handler offset

install_isr:
	push ebp

	and eax, 0xFF
	mov ebx, 8
	mul ebx
	mov edi, idt
	add edi, eax

	pop eax
	mov word[edi], ax

	shr eax, 16
	mov word[edi+6], ax

	ret

; unhandled_isr:
; Default handler for any unhandled ISR

unhandled_isr:
	pusha

	mov al, 0x20
	out 0x20, al

	popa
	iret

; pit_irq:
; PIT IRQ 0 handler

pit_irq:
	pusha
	push ds
	push es
	push fs
	push gs

	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	inc dword[ticks]
	inc dword[.tmp_ticks]

	cmp dword[.tmp_ticks], 100
	je .second

.done:
	mov al, 0x20
	out 0x20, al

	pop gs
	pop fs
	pop es
	pop ds
	popa
	iret

.second:
	mov dword[.tmp_ticks], 0
	inc dword[uptime]

	jmp .done

.tmp_ticks			dd 0
ticks				dd 0
uptime				dd 0


