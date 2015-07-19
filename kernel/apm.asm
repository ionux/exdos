
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/apm.asm							;;
;; BIOS Advanced Power Management					;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

; apm_shutdown:
; Shuts down the system using APM BIOS

apm_shutdown:
	call go16

use16

	mov ax, 0x5300		; check if APM BIOS is supported
	mov bx, 0
	int 0x15
	jc .return

	cmp ah, 1		; we need at least APM version 1.2 to shut down
	jl .return

	cmp al, 2
	jl .return

	mov ax, 0x5301		; connect to APM real mode interface
	mov bx, 0
	int 0x15
	jc .return

	mov ax, 0x5308		; enable power management for all devices
	mov bx, 1
	mov cx, 1
	int 0x15
	jc .return

	mov ax, 0x5307
	mov bx, 1
	mov cx, 3		; set power state of all devices to off
	int 0x15

.return:
	call go32

use32

	ret


