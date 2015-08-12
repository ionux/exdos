
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/apm.asm							;;
;; Advanced Power Management						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Functions:
; apm_shutdown

use32

; apm_shutdown:
; Shuts down the system using APM BIOS

apm_shutdown:
	mov esi, .debug_msg
	call kdebug_print

	call go16

use16

	mov ax, 0x5300		; check if APM BIOS is supported
	mov bx, 0
	int 0x15
	jc .return

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

	mov esi, .fail_msg
	call kdebug_print

	ret

.debug_msg			db "apm: attempting APM shutdown...",10,0
.fail_msg			db "apm: shutdown failed.",10,0




