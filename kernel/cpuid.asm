
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

;; Functions:
; init_cpuid
; detect_cpu_speed

use32

; init_cpuid:
; Detects CPU vendor and brand string

init_cpuid:
	mov eax, 0
	cpuid

	mov edi, cpu_vendor
	mov dword[edi], ebx
	mov dword[edi+4], edx
	mov dword[edi+8], ecx

	mov eax, 0x80000000
	cpuid

	cmp eax, 0x80000004
	jl .no_extended

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

	mov esi, .debug_msg1
	call kdebug_print

	mov esi, cpu_brand
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	ret

.no_extended:
	mov esi, .no_vendor_msg
	jmp draw_boot_error

.debug_msg1			db "cpu: CPU brand is ",0
.no_vendor_msg			db "CPU doesn't support CPUID extended functions.",0

cpu_vendor:			times 13 db 0
cpu_brand:			times 50 db 0

; detect_cpu_speed:
; Detects CPU speed using TSC and PIT

detect_cpu_speed:
	sti

	mov esi, .debug_msg1
	call kdebug_print

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

	mov esi, .debug_msg2
	call kdebug_print

	movzx eax, word[cpu_speed]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg3
	call kdebug_print_noprefix

	ret

.no_tsc:
	mov esi, .no_tsc_msg
	jmp draw_boot_error

.no_tsc_msg			db "CPU doesn't support TSC: Timestamp Counter.",0
.high				dd 0
.low				dd 0
.debug_msg1			db "cpu: getting CPU speed using TSC...",10,0
.debug_msg2			db "cpu: CPU speed is ",0
.debug_msg3			db " MHz.",10,0

cpu_speed			dw 0

