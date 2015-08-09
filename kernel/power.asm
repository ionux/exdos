
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/power.asm							;;
;; Basic Power Routines							;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

; reboot:
; Reboots the PC

reboot:
	cmp byte[is_program_running], 0
	jne .program

	mov esi, .debug_msg
	call kdebug_print

	cli
	call acpi_reset				; try ACPI reset

	mov esi, .debug_msg2
	call kdebug_print

	call wait_ps2_write			; if it failed, try the PS/2 keyboard method
	mov al, 0xFE
	out 0x64, al

	lidt [.idtr]				; if all failed, load an empty IDT and triple fault the CPU
	int 0

	hlt

.idtr:
	dw 0
	dd 0

.program:
	mov esi, .error_msg
	call kdebug_print

	mov esi, [program_name]
	call kdebug_print_noprefix

	mov esi, .error_msg2
	call kdebug_print_noprefix

	mov esp, [program_return_stack]
	mov ebp, [program_return]
	mov ebx, 0xDEADC0DE
	jmp ebp

.error_msg			db "task: program ",0
.error_msg2			db " attempted to reboot system; access denied.",10,0
.debug_msg			db "kernel: reboot requested.",10,0
.debug_msg2			db "kernel: attempting PS/2 reset...",10,0

; shutdown:
; Shuts down the PC

shutdown:
	cmp byte[is_program_running], 0
	jne .program

	mov esi, .debug_msg
	call kdebug_print

	; dim the display and print "It's now safe to power-off your PC."
	mov ebx, 0
	mov cx, 0
	mov dx, 0
	mov esi, [screen.width]
	mov edi, [screen.height]
	call alpha_fill_rect

	mov ebx, 0
	mov cx, 0
	mov dx, 0
	mov esi, [screen.width]
	mov edi, [screen.height]
	call alpha_fill_rect

	; draw the blue square
	call get_screen_center
	sub bx, 159
	sub cx, 32
	mov esi, 317
	mov edi, 64
	mov dx, cx
	mov cx, bx
	mov ebx, 0x000080
	call alpha_fill_rect

	; print the message
	call get_screen_center
	sub bx, 139
	sub cx, 7
	mov edx, 0
	mov esi, .safe_msg
	call print_string_transparent

	call get_screen_center
	sub bx, 140
	sub cx, 8
	mov edx, 0xEFEFEF
	mov esi, .safe_msg
	call print_string_transparent

	call acpi_shutdown			; try ACPI shutdown
	call apm_shutdown			; if that failed, try APM shutdown

	; if all failed, just hang
	sti

.hang:
	hlt
	jmp .hang

.program:
	mov esi, .error_msg
	call kdebug_print

	mov esi, [program_name]
	call kdebug_print_noprefix

	mov esi, .error_msg2
	call kdebug_print_noprefix

	mov esp, [program_return_stack]
	mov ebp, [program_return]
	mov ebx, 0xDEADC0DE
	jmp ebp

.error_msg			db "task: program ",0
.error_msg2			db " attempted to shut down system; access denied.",10,0
.safe_msg			db "It's now safe to power-off your PC.",0
.debug_msg			db "kernel: shutdown requested.",10,0



