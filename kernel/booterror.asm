
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/booterror.asm							;;
;; Boot Error Interface							;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

; draw_boot_error:
; Draws the boot error screen
; In\	ESI = Error message
; Out\	Nothing

draw_boot_error:
	mov [.string], esi

	mov ebx, 0x003050
	call clear_screen

	mov ebx, 0x0060B0
	mov cx, 0
	mov dx, 0
	mov esi, [screen.width]
	mov edi, 64
	call fill_rect

	mov ebx, 0x601010
	mov cx, 0
	mov dx, 64
	mov esi, [screen.width]
	mov edi, 1
	call fill_rect

	mov ebx, 0x0060B0
	mov cx, 0
	mov edx, [screen.height]
	sub edx, 64
	mov esi, [screen.width]
	mov edi, 64
	call fill_rect

	mov ebx, 0x601010
	mov cx, 0
	mov edx, [screen.height]
	sub edx, 64
	mov esi, [screen.width]
	mov edi, 1
	call fill_rect

	mov esi, .title
	mov bx, 16
	mov cx, 92
	mov edx, 0xFFFFFF
	call print_string_transparent

	mov esi, [.string]
	mov bx, 16
	mov cx, 172
	mov edx, 0xFFFFFF
	call print_string_transparent

	mov esi, [.string]
	mov bx, 17
	mov cx, 172
	mov edx, 0xFFFFFF
	call print_string_transparent

	mov esi, .copyright
	mov bx, 0
	mov ecx, [screen.height]
	sub ecx, 80
	mov edx, 0xFFFFFF
	call print_string_transparent

	mov esi, .copyright
	mov bx, 1
	mov ecx, [screen.height]
	sub ecx, 80
	mov edx, 0xFFFFFF
	call print_string_transparent

	cli
	hlt

.string					dd 0
.title					db "ExDOS has failed to start. ",13,10
					db "This may be the result of incompatible hardware. ",13,10
					db "For now, please record the error information below and reboot your PC.",13,10,13,10
					db "Error information: ",0
.copyright				db "Copyright (C) 2015 by Omar Mohammad, all rights reserved.",0


