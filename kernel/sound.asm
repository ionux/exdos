
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/sound.asm							;;
;; PC Speaker Driver							;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Functions:
; play_note
; stop_speaker
; play_buffer

use32

; play_note:
; Plays a single note using the PC speaker
; In\	EDX = Frequency
; Out\	Nothing

play_note:
	pusha

	in al, 0x61
	and al, 0xFC			; stop playing
	call wait_ps2_write
	out 0x61, al
	call iowait			; wait for I/O operation to complete

	mov ebx, edx
	mov edx, 0
	mov eax, 1193180
	div ebx

	push eax			; save the result
	mov al, 0xB6
	out 0x43, al

	call iowait

	pop eax
	out 0x42, al			; low byte
	mov al, ah
	out 0x42, al			; high byte

	in al, 0x61
	or al, 3			; turn on PC speaker
	call wait_ps2_write
	out 0x61, al

	call iowait

	popa
	ret

; stop_speaker:
; Turns off the PC speaker

stop_speaker:
	pusha

	in al, 0x61
	and al, 0xFC
	call wait_ps2_write
	out 0x61, al

	call iowait
	popa
	ret

; play_buffer:
; Plays a sound buffer
; In\	ESI = Pointer to buffer (20 notes per second)
; In\	ECX = Size of buffer in dwords
; Out\	Nothing

play_buffer:
	mov [.buffer], esi
	mov [.size], ecx

.loop:
	mov esi, [.buffer]
	mov edx, [esi]
	add dword[.buffer], 4
	call play_note

	mov ebx, [ticks]
	add ebx, 5

.wait_for_ticks:
	mov eax, [ticks]
	cmp eax, ebx
	jge .next_note
	jmp .wait_for_ticks

.next_note:
	loop .loop

	call stop_speaker
	ret

.buffer				dd 0
.size				dd 0



