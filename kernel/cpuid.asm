
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/cpuid.asm							;;
;; CPUID Parser								;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

; init_cpuid:
; Detects CPU vendor and brand string

init_cpuid:
	cli
	mov eax, 0
	cpuid

	mov edi, cpu_vendor
	mov dword[edi], ebx
	mov dword[edi+4], edx
	mov dword[edi+8], ecx

	mov eax, 0x80000002
	cpuid

	mov esi, cpu_brand
	mov dword[esi], eax
	add esi, 4
	mov dword[esi], ebx
	add esi, 4
	mov dword[esi], ecx
	add esi, 4
	mov dword[esi], edx
	add esi, 4

	mov eax, 0x80000003
	cpuid

	mov dword[esi], eax
	add esi, 4
	mov dword[esi], ebx
	add esi, 4
	mov dword[esi], ecx
	add esi, 4
	mov dword[esi], edx
	add esi, 4

	mov eax, 0x80000004
	cpuid

	mov dword[esi], eax
	add esi, 4
	mov dword[esi], ebx
	add esi, 4
	mov dword[esi], ecx
	add esi, 4
	mov dword[esi], edx
	add esi, 4

	mov eax, cpu_brand
	call chomp_string

	ret

cpu_vendor:			times 13 db 0
cpu_brand:			times 50 db 0

; detect_cpu_speed:
; Detects CPU speed using TSC and PIT

detect_cpu_speed:
	sti

	mov eax, 1
	cpuid

	test edx, 0x10
	jz .no_tsc

	mov ebx, [ticks]

.wait_for_irq:
	cmp ebx, [ticks]
	je .wait_for_irq

	rdtsc
	mov [.high], edx
	mov [.low], eax

	mov ebx, [ticks]

.wait_for_another_irq:
	cmp ebx, [ticks]
	je .wait_for_another_irq

	rdtsc
	sub edx, dword[.high]
	sub eax, dword[.low]

	mov ebx, 10000			; assumes PIT is initialized to 100 Hz
	div ebx

	mov [cpu_speed], ax
	ret

.no_tsc:
	mov ebx, 0x333333
	mov cx, 0
	mov dx, 218
	mov esi, 800
	mov edi, 160
	call alpha_fill_rect

	mov esi, .no_tsc_msg
	mov bx, 32
	mov cx, 250
	mov edx, 0xDEDEDE
	call print_string_transparent

	mov esi, _boot_error_common
	mov bx, 32
	mov cx, 340
	mov edx, 0xDEDEDE
	call print_string_transparent

	sti
	jmp $

.no_tsc_msg			db "Boot error: This CPU doesn't support TSC: Timestamp counter.",0
.high				dd 0
.low				dd 0

cpu_speed			dw 0

