
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

;; Functions:
; cmos_delay
; wait_cmos
; init_cmos
; get_time_24
; get_time_12
; get_date
; get_weekday_from_date
; get_time_string_24
; get_time_string_12
; get_date_string_am
; get_date_string_me
; get_long_date_string

use32

cmos_bcd			db 0
cmos_24				db 0
cmos_century			db 0x32		; century register should be taken from ACPI FADT
						; if the FADT doesn't have a century register, default to 0x32

; cmos_delay:
; Makes a short delay

cmos_delay:
	mov ecx, 0xFFFF

.delay:
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
	mov esi, .debug_msg
	call kdebug_print

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
	jmp .done

.bcd:
	mov byte[cmos_bcd], 1

.done:
	mov esi, .debug_msg2
	call kdebug_print

	call get_time_string_12
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	cmp byte[acpi_fadt.century], 0
	je .no_century

	mov esi, .debug_msg4
	call kdebug_print

	mov al, [acpi_fadt.century]
	call hex_byte_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	mov al, [acpi_fadt.century]
	mov [cmos_century], al

	jmp .get_date

.no_century:
	mov esi, .debug_msg3
	call kdebug_print

.get_date:
	mov esi, .debug_msg5
	call kdebug_print

	call get_long_date_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	ret

.debug_msg			db "cmos: initializing CMOS RTC...",10,0
.debug_msg2			db "cmos: the time is ",0
.debug_msg3			db "cmos: no century register found, defaulting to 32...",10,0
.debug_msg4			db "acpi: CMOS century register is ",0
.debug_msg5			db "cmos: the date is ",0

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

; get_date:
; Gets the system date
; In\	Nothing
; Out\	AL/AH/BX = Day/Month/Year

get_date:
	call wait_cmos			; wait for the CMOS to finish updating its clock...

	mov al, 7			; day of month
	out 0x70, al

	call cmos_delay
	in al, 0x71

	cmp byte[cmos_bcd], 1
	je .day_bcd

	mov [.day], al
	jmp .do_month

.day_bcd:
	and eax, 0xFF
	call bcd_to_int
	mov [.day], al

.do_month:
	mov al, 8			; month
	out 0x70, al

	call cmos_delay
	in al, 0x71

	cmp byte[cmos_bcd], 1
	je .month_bcd

	mov [.month], al
	jmp .do_year

.month_bcd:
	and eax, 0xFF
	call bcd_to_int
	mov [.month], al

.do_year:
	mov al, 9			; year
	out 0x70, al

	call cmos_delay
	in al, 0x71

	cmp byte[cmos_bcd], 1
	je .year_bcd

	and ax, 0xFF
	mov [.year], ax

	jmp .do_century

.year_bcd:
	and eax, 0xFF
	call bcd_to_int
	and eax, 0xFF
	mov [.year], ax

.do_century:
	mov al, [cmos_century]		; century
	out 0x70, al

	call cmos_delay
	in al, 0x71

	cmp byte[cmos_bcd], 1
	je .century_bcd

	mov [.century], al
	jmp .done

.century_bcd:
	and eax, 0xFF
	call bcd_to_int
	mov [.century], al

.done:
	movzx eax, byte[.century]
	mov ebx, 100
	mul ebx
	movzx ebx, word[.year]
	add eax, ebx
	mov [.year], ax

	mov al, [.day]
	mov ah, [.month]
	mov bx, [.year]
	ret

.day			db 0
.month			db 0
.year			dw 0
.century		db 0

; get_weekday_from_date:
; Gets the weekday from the date
; In\	AL/AH/BX = Day/Month/Year
; Out\	AL = Weekday (0 - Sunday)

get_weekday_from_date:
	mov [.day], al
	mov [.month], ah
	mov [.year], bx

.get_month_table:
	cmp byte[.month], 1
	je .january

	cmp byte[.month], 2
	je .february

	cmp byte[.month], 3
	je .march

	cmp byte[.month], 4
	je .april

	cmp byte[.month], 5
	je .may

	cmp byte[.month], 6
	je .june

	cmp byte[.month], 7
	je .july

	cmp byte[.month], 8
	je .august

	cmp byte[.month], 9
	je .september

	cmp byte[.month], 10
	je .october

	cmp byte[.month], 11
	je .november

	cmp byte[.month], 12
	je .december

.january:
	mov byte[.month], 0
	jmp .work

.february:
	mov byte[.month], 3
	jmp .work

.march:
	mov byte[.month], 3
	jmp .work

.april:
	mov byte[.month], 6
	jmp .work

.may:
	mov byte[.month], 1
	jmp .work

.june:
	mov byte[.month], 4
	jmp .work

.july:
	mov byte[.month], 6
	jmp .work

.august:
	mov byte[.month], 2
	jmp .work

.september:
	mov byte[.month], 5
	jmp .work

.october:
	mov byte[.month], 0
	jmp .work

.november:
	mov byte[.month], 3
	jmp .work

.december:
	mov byte[.month], 5

.work:
	; The formula is:
	; Weekday = [day + month + year + (year/4) + century) mod 7
	; 0 = Sunday, 6 = Saturday
	; month is the internal routine found above
	; Year is the last two digits
	; Century is 6 for the 21st century -- it's hardcoded here

	movzx eax, word[.year]
	call int_to_string

	mov edi, .tmp
	mov ecx, 4
	rep movsb

	mov esi, .tmp
	call get_string_size

	mov esi, .tmp
	add esi, eax
	sub esi, 1

	mov al, byte[esi]
	mov [.digit_lo], al

	sub esi, 1
	mov al, byte[esi]
	mov [.digit_hi], al

	sub byte[.digit_lo], 48
	sub byte[.digit_hi], 48

	movzx eax, byte[.digit_hi]
	mov ebx, 10
	mul ebx
	movzx ebx, byte[.digit_lo]
	add eax, ebx

	mov [.year], ax			; This is the last two digits of the year

	; Now, we do the bracket first
	; Year/4 first

	movzx eax, word[.year]
	mov ebx, 4
	mov edx, 0
	div ebx

	mov [.tmp2], eax

	movzx eax, byte[.day]
	movzx ebx, byte[.month]
	add eax, ebx
	movzx ebx, word[.year]
	add eax, ebx

	mov ebx, [.tmp2]
	add eax, ebx

	mov ebx, 6
	add eax, ebx

	mov ebx, 7
	mov edx, 0
	div ebx

	mov eax, edx
	and eax, 0xFF

	ret

.tmp:			times 5 db 0
.tmp2			dd 0
.day			db 0
.month			db 0
.year			dw 0
.digit_lo		db 0
.digit_hi		db 0

; get_date_string_am:
; Gets the date string in American format (MM/dd/YYYY)
; In\	Nothing
; Out\	ESI = Pointer to ASCIIZ string

get_date_string_am:
	call get_date

	mov [.day], al
	mov [.month], ah
	mov [.year], bx

.do_day:
	mov al, [.day]
	cmp al, 9
	jle .day_small

	and eax, 0xFF
	call int_to_string
	mov edi, .string+3
	mov ecx, 2
	rep movsb
	jmp .do_month

.day_small:
	add al, 48
	mov edi, .string+4
	stosb

.do_month:
	mov al, [.month]
	cmp al, 9
	jle .month_small

	and eax, 0xFF
	call int_to_string
	mov edi, .string
	mov ecx, 2
	rep movsb
	jmp .do_year

.month_small:
	add al, 48
	mov edi, .string+1
	stosb

.do_year:
	mov ax, [.year]
	and eax, 0xFFFF
	call int_to_string

	mov edi, .string+6
	mov ecx, 4
	rep movsb

	mov esi, .string
	ret

.day			db 0
.month			db 0
.year			dw 0
.string			db "00/00/0000",0

; get_date_string_me:
; Gets the date string in Eastern format (dd/MM/YYYY)
; In\	Nothing
; Out\	ESI = Pointer to ASCIIZ string

get_date_string_me:
	call get_date

	mov [.day], al
	mov [.month], ah
	mov [.year], bx

.do_day:
	mov al, [.day]
	cmp al, 9
	jle .day_small

	and eax, 0xFF
	call int_to_string
	mov edi, .string
	mov ecx, 2
	rep movsb
	jmp .do_month

.day_small:
	add al, 48
	mov edi, .string+1
	stosb

.do_month:
	mov al, [.month]
	cmp al, 9
	jle .month_small

	and eax, 0xFF
	call int_to_string
	mov edi, .string+3
	mov ecx, 2
	rep movsb
	jmp .do_year

.month_small:
	add al, 48
	mov edi, .string+4
	stosb

.do_year:
	mov ax, [.year]
	and eax, 0xFFFF
	call int_to_string

	mov edi, .string+6
	mov ecx, 4
	rep movsb

	mov esi, .string
	ret

.day			db 0
.month			db 0
.year			dw 0
.string			db "00/00/0000",0

; get_long_date_string:
; Gets the date in a long string (for example, Wednesday, 5 August, 2015)
; In\	Nothing
; Out\	ESI = Pointer to ASCIIZ string

get_long_date_string:
	call get_date

	mov [.day], al
	mov [.month], ah
	mov [.year], bx

	mov al, [.day]
	mov ah, [.month]
	mov bx, [.year]
	call get_weekday_from_date		; get the weekday

	mov [.weekday], al

	mov edi, .string
	mov eax, 0
	mov ecx, 48
	rep stosb

.do_weekday:
	mov al, [.weekday]
	cmp al, 0
	je .sunday

	cmp al, 1
	je .monday

	cmp al, 2
	je .tuesday

	cmp al, 3
	je .wednesday

	cmp al, 4
	je .thursday

	cmp al, 5
	je .friday

	cmp al, 6
	je .saturday

.sunday:
	mov esi, .sunday_str
	mov ecx, 6
	mov edi, .string
	rep movsb
	mov [.tmp], edi

	jmp .do_day

.monday:
	mov esi, .monday_str
	mov ecx, 6
	mov edi, .string
	rep movsb
	mov [.tmp], edi

	jmp .do_day

.tuesday:
	mov esi, .tuesday_str
	mov ecx, 7
	mov edi, .string
	rep movsb
	mov [.tmp], edi

	jmp .do_day

.wednesday:
	mov esi, .wednesday_str
	mov ecx, 9
	mov edi, .string
	rep movsb
	mov [.tmp], edi

	jmp .do_day

.thursday:
	mov esi, .thursday_str
	mov ecx, 8
	mov edi, .string
	rep movsb
	mov [.tmp], edi

	jmp .do_day

.friday:
	mov esi, .friday_str
	mov ecx, 6
	mov edi, .string
	rep movsb
	mov [.tmp], edi

	jmp .do_day

.saturday:
	mov esi, .saturday_str
	mov ecx, 8
	mov edi, .string
	rep movsb
	mov [.tmp], edi

.do_day:
	mov edi, [.tmp]
	mov esi, .comma
	mov ecx, 2
	rep movsb
	mov [.tmp], edi

	movzx eax, byte[.day]
	call int_to_string

	mov edi, [.tmp]
	movsb
	mov al, ' '
	stosb
	mov [.tmp], edi

.do_month:
	mov al, [.month]

	cmp al, 1
	je .january

	cmp al, 2
	je .february

	cmp al, 3
	je .march

	cmp al, 4
	je .april

	cmp al, 5
	je .may

	cmp al, 6
	je .june

	cmp al, 7
	je .july

	cmp al, 8
	je .august

	cmp al, 9
	je .september

	cmp al, 10
	je .october

	cmp al, 11
	je .november

	cmp al, 12
	je .december

.january:
	mov esi, .january_str
	mov edi, [.tmp]
	mov ecx, 7
	rep movsb
	mov [.tmp], edi
	jmp .do_year

.february:
	mov esi, .february_str
	mov edi, [.tmp]
	mov ecx, 8
	rep movsb
	mov [.tmp], edi
	jmp .do_year

.march:
	mov esi, .march_str
	mov edi, [.tmp]
	mov ecx, 5
	rep movsb
	mov [.tmp], edi
	jmp .do_year

.april:
	mov esi, .april_str
	mov edi, [.tmp]
	mov ecx, 5
	rep movsb
	mov [.tmp], edi
	jmp .do_year

.may:
	mov esi, .may_str
	mov edi, [.tmp]
	mov ecx, 3
	rep movsb
	mov [.tmp], edi
	jmp .do_year

.june:
	mov esi, .june_str
	mov edi, [.tmp]
	mov ecx, 4
	rep movsb
	mov [.tmp], edi
	jmp .do_year

.july:
	mov esi, .july_str
	mov edi, [.tmp]
	mov ecx, 4
	rep movsb
	mov [.tmp], edi
	jmp .do_year

.august:
	mov esi, .august_str
	mov edi, [.tmp]
	mov ecx, 6
	rep movsb
	mov [.tmp], edi
	jmp .do_year

.september:
	mov esi, .september_str
	mov edi, [.tmp]
	mov ecx, 9
	rep movsb
	mov [.tmp], edi
	jmp .do_year

.october:
	mov esi, .october_str
	mov edi, [.tmp]
	mov ecx, 7
	rep movsb
	mov [.tmp], edi
	jmp .do_year

.november:
	mov esi, .november_str
	mov edi, [.tmp]
	mov ecx, 8
	rep movsb
	mov [.tmp], edi
	jmp .do_year

.december:
	mov esi, .december_str
	mov edi, [.tmp]
	mov ecx, 8
	rep movsb
	mov [.tmp], edi

.do_year:
	mov edi, [.tmp]
	mov esi, .comma
	mov ecx, 2
	rep movsb
	mov [.tmp], edi

	movzx eax, word[.year]
	call int_to_string
	mov edi, [.tmp]
	mov ecx, 4
	rep movsb

	mov esi, .string
	ret

	

.string:		times 48 db 0
.tmp			dd 0
.day			db 0
.month			db 0
.year			dw 0
.weekday		db 0
.comma			db ", "

.sunday_str		db "Sunday"
.monday_str		db "Monday"
.tuesday_str		db "Tuesday"
.wednesday_str		db "Wednesday"
.thursday_str		db "Thursday"
.friday_str		db "Friday"
.saturday_str		db "Saturday"

.january_str		db "January"
.february_str		db "February"
.march_str		db "March"
.april_str		db "April"
.may_str		db "May"
.june_str		db "June"
.july_str		db "July"
.august_str		db "August"
.september_str		db "September"
.october_str		db "October"
.november_str		db "November"
.december_str		db "December"




