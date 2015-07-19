
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/cmos.asm							;;
;; CMOS RTC Driver							;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

cmos_bcd			db 0
cmos_24				db 0

; cmos_delay:
; Makes a short delay

cmos_delay:
	mov ecx, 0xFFFF

.delay:
	nop
	nop
	nop
	nop
	loop .delay

	ret

; wait_cmos:
; Waits for the CMOS to finish updating its clock

wait_cmos:
	mov al, 0xA
	out 0x70, al

	call cmos_delay

	in al, 0x71
	test al, 0x80
	jnz wait_cmos

	ret

; init_cmos:
; Initializes the CMOS RTC

init_cmos:
	call wait_cmos
	mov al, 0xB
	out 0x70, al

	call cmos_delay

	in al, 0x71
	test al, 2
	jnz .24

	mov byte[cmos_24], 0
	jmp .check_bcd

.24:
	mov byte[cmos_24], 1

.check_bcd:
	call wait_cmos
	mov al, 0xB
	out 0x70, al

	call cmos_delay

	in al, 0x71
	test al, 4
	jz .bcd

	mov byte[cmos_bcd], 0
	ret

.bcd:
	mov byte[cmos_bcd], 1
	ret

; get_time_24:
; Gets the time in 24 hour format
; In\	Nothing
; Out\	AH:AL = Hours:Minutes

get_time_24:
	pusha

	call wait_cmos
	mov al, 4
	out 0x70, al

	call cmos_delay

	in al, 0x71
	cmp byte[cmos_24], 0
	je .12_hour

	cmp byte[cmos_bcd], 1
	je .hour_bcd

	mov [.hour], al

	jmp .do_minute

.12_hour:
	test al, 0x80			; test AM or PM bit
	jnz .hour_pm

	cmp byte[cmos_bcd], 1
	je .hour_bcd

	mov [.hour], al

	jmp .do_minute

.hour_pm:
	and al, 0x7F			; mask off PM bit

	cmp byte[cmos_bcd], 1
	je .hour_pm_bcd

	mov [.hour], al

	jmp .do_minute

.hour_pm_bcd:
	call bcd_to_int
	add al, 12
	mov [.hour], al

	jmp .do_minute

.hour_bcd:
	call bcd_to_int
	mov [.hour], al

.do_minute:
	call wait_cmos
	mov al, 2
	out 0x70, al

	call cmos_delay
	in al, 0x71

	cmp byte[cmos_bcd], 1
	je .minutes_bcd

	mov [.minutes], al
	jmp .done

.minutes_bcd:
	call bcd_to_int
	mov [.minutes], al

.done:
	popa
	mov ah, [.hour]
	mov al, [.minutes]
	ret

.hour				db 0
.minutes			db 0

; get_time_12:
; Gets the time in 12-hour format
; In\	Nothing
; Out\	AH:AL = Hours:Minutes
; Out\	BL = 0 if AM, 1 if PM

get_time_12:
	; Why read the CMOS registers and convert BCD and integers here and there --
	; -- when we can just convert 24 hour time into 12 hour time! ;)

	call get_time_24

	cmp ah, 0
	je .midnight

	cmp ah, 12
	je .noon

	cmp ah, 12
	jg .pm

	mov bl, 0
	ret

.midnight:
	mov ah, 12				; in 24-hour time, midnight is 00:00 --
						; -- but in 12-hour time, we want 12:00 AM instead
	mov bl, 0
	ret

.noon:
	mov ah, 12
	mov bl, 1
	ret

.pm:
	sub ah, 12
	mov bl, 1
	ret

; get_time_string_24:
; Gets the current time in 24 hour format in an ASCIIZ string, it would look like "20:47"
; In\	Nothing
; Out\	ESI = Pointer to string

get_time_string_24:
	pusha
	call get_time_24

	mov [.hour], ah
	mov [.minute], al

.do_hour:
	mov al, [.hour]
	cmp al, 9
	jle .hour_small

	and eax, 0xFF
	call int_to_string
	mov edi, .string
	mov ecx, 2
	rep movsb

	jmp .do_minute

.hour_small:
	add al, 48
	mov edi, .string
	add edi, 1
	stosb

.do_minute:
	mov al, [.minute]
	cmp al, 9
	jle .minute_small

	and eax, 0xFF
	call int_to_string
	mov edi, .string
	add edi, 3
	mov ecx, 2
	rep movsb

	jmp .done

.minute_small:
	add al, 48
	mov edi, .string
	add edi, 4
	stosb

.done:
	popa
	mov esi, .string
	ret

.string				db "00:00",0
.hour				db 0
.minute				db 0

; get_time_string_12:
; Gets the current time in 12 hour format in an ASCIIZ string, it would look like "08:47 PM"
; In\	Nothing
; Out\	ESI = Pointer to string

get_time_string_12:
	pusha
	call get_time_12

	mov [.hour], ah
	mov [.minute], al
	mov [.am_pm], bl

.do_hour:
	mov al, [.hour]
	cmp al, 9
	jle .hour_small

	and eax, 0xFF
	call int_to_string
	mov edi, .string
	mov ecx, 2
	rep movsb

	jmp .do_minute

.hour_small:
	add al, 48
	mov edi, .string
	add edi, 1
	stosb

.do_minute:
	mov al, [.minute]
	cmp al, 9
	jle .minute_small

	and eax, 0xFF
	call int_to_string
	mov edi, .string
	add edi, 3
	mov ecx, 2
	rep movsb

	jmp .do_am_pm

.minute_small:
	add al, 48
	mov edi, .string
	add edi, 4
	stosb

.do_am_pm:
	cmp byte[.am_pm], 1
	je .pm

.am:
	mov esi, .am_string
	mov edi, .string
	add edi, 6
	mov ecx, 2
	rep movsb
	jmp .done

.pm:
	mov esi, .pm_string
	mov edi, .string
	add edi, 6
	mov ecx, 2
	rep movsb

.done:
	popa
	mov esi, .string
	ret

.string				db "00:00 AM",0
.hour				db 0
.minute				db 0
.am_pm				db 0
.am_string			db "AM"
.pm_string			db "PM"


