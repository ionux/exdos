
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
	cli
	call wait_ps2_write
	mov al, 0xFE
	out 0x64, al

	lidt [.idtr]
	int 0

.idtr:
	dw 0
	dd 0

; shutdown:
; Shuts down the PC

shutdown:
	; dim the display
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

	mov ebx, 0
	mov cx, 0
	mov dx, 0
	mov esi, [screen.width]
	mov edi, [screen.height]
	call alpha_fill_rect

	call apm_shutdown		; try APM BIOS shutdown
	call acpi_shutdown		; if that didn't work, try ACPI shutdown

	; if shutdown failed, print "It's now safe to power-off your PC." message
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

	sti

.halt:
	hlt			; save energy...
	jmp .halt

.safe_msg			db "It's now safe to power-off your PC.",0




