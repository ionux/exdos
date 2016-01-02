
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/math.asm							;;
;; Math Routines							;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Functions:
; bcd_to_int
; rand
; srand
; is_number_multiple
; round
; round_forward
; float_add
; float_sub
; float_mul
; float_div
; power

use32

; bcd_to_int:
; Converts a binary coded decimal to a binary number
; In\	AL = BCD number
; Out\	AL = Binary number

bcd_to_int:
	mov [.tmp], al
	and eax, 0xF
	mov [.tmp2], ax
	mov al, [.tmp]
	and eax, 0xF0
	shr eax, 4
	and eax, 0xF

	mov ebx, 10
	mul ebx
	mov bx, [.tmp2]
	add ax, bx
	and eax, 0xFF

	ret

.tmp			db 0
.tmp2			dw 0

; rand:
; Generates a random number between a specified range
; In\	ECX = Low range
; In\	EDX = High range
; Out\	EAX = Random number

rand:
	mov [.low], ecx
	mov [.high], edx

	mov eax, [.high]
	mov ebx, [.low]
	sub eax, ebx
	mov [.range], eax

	mov eax, [ticks]
	shl eax, 8
	mov ebx, [.range]
	mov edx, 0
	div ebx

	add edx, dword[.low]
	mov eax, edx

	ret

.range			dd 0
.low			dd 0
.high			dd 0

; srand:
; Generates a signed random number between a specified range
; In\	ECX = Low range
; In\	EDX = High range
; Out\	EAX = Random number

srand:
	mov [.low], ecx
	mov [.high], edx

	mov ecx, 0
	mov edx, 100
	call rand

	test eax, 1
	jz .positive

	mov ecx, [.low]
	mov edx, [.high]
	and ecx, 0x80000000
	and edx, 0x80000000
	call rand

	or eax, 0x80000000
	ret

.positive:
	mov ecx, [.low]
	mov edx, [.high]
	and ecx, 0x80000000
	and edx, 0x80000000
	call rand

	and eax, 0x7FFFFFFF
	ret

.low			dd 0
.high			dd 0

; is_number_multiple:
; Checks if a number is a multiple of another
; In\	EAX = Number to check
; In\	EBX = Multiplier
; Out\	Carry clear if number is multiple, registers preserved

is_number_multiple:
	pusha

	cmp ebx, 0			; prevent divide by zero errors
	je .no

	mov edx, 0
	div ebx
	cmp edx, 0
	je .yes

.no:
	popa
	stc
	ret

.yes:
	popa
	clc
	ret

; round:
; Rounds a number
; In\	EAX = Number to approximate
; In\	EBX = Number to get nearest to
; Out\	EAX = Approximated number
; Out\	Carry clear on success

round:
	pusha
	mov [.number], eax
	mov [.nearest], ebx

	cmp dword[.nearest], 0		; prevent divide by zero
	je .error

	mov eax, [.number]
	mov ebx, [.nearest]
	call is_number_multiple		; if it is a multiple --
	jnc .finish			; -- then don't do anything

	mov eax, [.nearest]
	shr eax, 1			; quick divide by 2
	mov [.half_nearest], eax

	mov eax, [.number]
	and eax, dword[.half_nearest]
	cmp eax, [.half_nearest]
	jl .less			; if the number to be approximated is less than the number we're trying to be nearest to --
					; -- we make the number smaller, not bigger
					; lol, first time I use math in real life xD

.more:
	mov eax, [.number]
	mov ebx, [.nearest]
	call is_number_multiple
	mov [.number], eax
	jnc .finish

	add dword[.number], 1
	jmp .more

.less:
	mov eax, [.number]
	mov ebx, [.nearest]
	call is_number_multiple
	mov [.number], eax
	jnc .finish

	sub dword[.number], 1
	jmp .less

.finish:
	popa
	mov eax, [.number]
	clc
	ret

.error:
	popa
	mov eax, 0
	stc
	ret

.number			dd 0
.nearest		dd 0
.half_nearest		dd 0

; round_forward:
; Rounds a number to another number by incrementing only
; In\	EAX = Number to be rounded
; In\	EBX = Number to round to
; Out\	EFLAGS = Carry clear on success
; Out\	EAX = Number

round_forward:
	cmp ebx, 0
	je .error

	mov [.number1], eax
	mov [.number2], ebx

.loop:
	mov eax, [.number1]
	mov ebx, [.number2]
	call is_number_multiple
	jnc .done

	add dword[.number1], 1
	jmp .loop

.done:
	mov eax, [.number1]
	clc
	ret

.error:
	stc
	ret

.number1		dd 0
.number2		dd 0

; float_add:
; Adds two floating point numbers
; In\	EDX:EAX = Number 1
; In\	ECX:EBX = Number 2
; Out\	EDX:EAX = Result

float_add:
	pusha
	mov dword[.number1], eax
	mov dword[.number1+4], edx
	mov dword[.number2], ebx
	mov dword[.number2+4], ecx

	finit				; clear all registers
	fwait

	fld qword[.number1]
	fld qword[.number2]

	fadd st0, st1
	fwait
	fst qword[.number1]

	popa
	mov eax, dword[.number1]
	mov edx, dword[.number1+4]
	ret

.number1			dq 0
.number2			dq 0

; float_sub:
; Subtracts two floating point numbers
; In\	EDX:EAX = Number 1
; In\	ECX:EBX = Number 2
; Out\	EDX:EAX = Result

float_sub:
	pusha
	mov dword[.number1], eax
	mov dword[.number1+4], edx
	mov dword[.number2], ebx
	mov dword[.number2+4], ecx

	finit				; clear all registers
	fwait

	fld qword[.number1]
	fld qword[.number2]

	fsub st0, st1
	fwait
	fst qword[.number1]

	popa
	mov eax, dword[.number1]
	mov edx, dword[.number1+4]
	ret

.number1			dq 0
.number2			dq 0

; float_mul:
; Multiplies two floating point numbers
; In\	EDX:EAX = Number 1
; In\	ECX:EBX = Number 2
; Out\	EDX:EAX = Result

float_mul:
	pusha
	mov dword[.number1], eax
	mov dword[.number1+4], edx
	mov dword[.number2], ebx
	mov dword[.number2+4], ecx

	finit				; clear all registers
	fwait

	fld qword[.number1]
	fld qword[.number2]

	fmul st0, st1
	fwait
	fst qword[.number1]

	popa
	mov eax, dword[.number1]
	mov edx, dword[.number1+4]
	ret

.number1			dq 0
.number2			dq 0

; float_div:
; Divides two floating point numbers
; In\	EDX:EAX = Number 1
; In\	ECX:EBX = Number 2
; Out\	EDX:EAX = Result

float_div:
	pusha
	mov dword[.number1], eax
	mov dword[.number1+4], edx
	mov dword[.number2], ebx
	mov dword[.number2+4], ecx

	finit				; clear all registers
	fwait

	fld qword[.number1]
	;fld qword[.number2]

	fdiv qword[.number2]
	fwait
	fst qword[.number1]

	popa
	mov eax, dword[.number1]
	mov edx, dword[.number1+4]
	ret

.number1			dq 0
.number2			dq 0

; int_to_float:
; Converts an integer to a double-precision floating point
; In\	EDX = Integer
; Out\	EDX:EAX = Floating point number

int_to_float:
	finit			; clear FPU registers
	fwait

	mov [.number], edx
	fild dword[.number]
	fst qword[.result]

	mov eax, dword[.result]
	mov edx, dword[.result+4]
	ret

.number				dd 0
.result				dq 0

; float_to_int:
; Converts a double-precision floating point to an integer
; In\	ECX:EBX = Floating point number
; Out\	EAX = Integer

float_to_int:
	finit
	fwait

	mov dword[.number+4], ecx
	mov dword[.number], ebx

	fld qword[.number]
	fist dword[.result]
	mov eax, [.result]
	ret

.number				dq 0
.result				dd 0

; power:
; Raises a number to a power
; In\	EAX = Base (integer)
; In\	EBX = Power (integer)
; Out\	EDX:EAX = Result in floating point

power:
	mov [.base], eax
	mov [.power], ebx

	; If the base is negative, make it positive because it won't have any difference anyway
	test dword[.base], 0x80000000
	jnz .base_negative

	jmp .start

.base_negative:
	not dword[.base]		; change to positive
	inc dword[.base]

.start:
	; test if power is negative...
	test dword[.power], 0x80000000
	jnz .power_negative

	mov edx, [.base]
	call int_to_float

	mov dword[.base2], eax
	mov dword[.base2+4], edx

	mov edx, dword[.base2+4]
	mov eax, dword[.base2]
	mov ecx, dword[.base2+4]
	mov ebx, dword[.base2]
	mov edi, [.power]
	dec edi

.positive_loop:
	call float_mul
	dec edi
	cmp edi, 0
	jne .positive_loop

	ret

.power_negative:
	not dword[.power]

	mov edx, [.base]
	call int_to_float

	mov dword[.base2], eax
	mov dword[.base2+4], edx

	mov edx, dword[.base2+4]
	mov eax, dword[.base2]
	mov ecx, dword[.base2+4]
	mov ebx, dword[.base2]
	mov edi, [.power]

.negative_loop:
	call float_mul
	dec edi
	cmp edi, 0
	jne .negative_loop

	mov dword[.result], eax
	mov dword[.result+4], edx

	mov edx, 1
	call int_to_float

	mov ecx, dword[.result+4]
	mov ebx, dword[.result]
	;xchg ecx, edx
	;xchg ebx, eax
	call float_div

	ret

.base			dd 0
.power			dd 0

.base2			dq 0
.power2			dq 0

.result			dq 0

