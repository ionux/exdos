
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/tasking.asm							;;
;; Kernel Multitasking							;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

align 32

; tss:
; Task State Segment

tss:
	.prev_tss			dd 0
	.esp0				dd 0
	.ss0				dd 0x10			; kernel stack segment
	.esp1				dd 0
	.ss1				dd 0
	.esp2				dd 0
	.ss2				dd 0
	.cr3				dd page_directory	; CR3 is the same for kernel and user
	.eip				dd 0			; these values are also used for hardware multitasking
	.eflags				dd 0
	.eax				dd 0
	.ecx				dd 0
	.edx				dd 0
	.ebx				dd 0
	.esp				dd 0
	.ebp				dd 0
	.esi				dd 0
	.edi				dd 0
	.es				dd 0x10			; kernel data segments
	.cs				dd 0x08
	.ss				dd 0x10
	.ds				dd 0x10
	.fs				dd 0x10
	.gs				dd 0x10
	.ldt				dd 0
	.trap				dw 0
	.iomap_base			dw 104			; prevent user programs from using IN/OUT instructions

; load_tss:
; Loads the task state segment

load_tss:
	cli

	mov eax, stack_area+stack_size
	mov dword[tss.esp0], eax
	mov dword[tss.esp], eax

	pushfd
	pop eax
	;or eax, 0x20202			; v8086, just for debugging..
	or eax, 0x202
	mov dword[tss.eflags], eax

	mov eax, tss
	and eax, 0xFFFFFF
	or [gdt_tss+2], eax

	mov eax, 0x3B
	ltr ax

	ret

; init_sysenter:
; Initializes SYSENTER/SYSEXIT instructions

init_sysenter:
	cli

	mov eax, 1
	cpuid

	test edx, 0x20			; does the CPU support MSR?
	jz .no_msr

	mov eax, 1
	cpuid

	test edx, 0x800			; does the CPU support SYSENTER/SYSEXIT?
	jz .no_sysenter

	mov ecx, 0x174
	mov eax, 8			; kernel code segment
	mov edx, 0
	wrmsr

	mov ecx, 0x175
	mov eax, stack_area+stack_size	; kernel stack
	mov edx, 0
	wrmsr

	mov ecx, 0x176
	mov eax, sysenter_main		; Sysenter entry point
	mov edx, 0
	wrmsr

	mov ecx, 0xFFFF

.delay:
	nop
	nop
	nop
	nop

	loop .delay

	;call enter_ring0		; for debugging
	;jmp $
	ret

.no_msr:
	mov ebx, 0x333333
	mov cx, 0
	mov dx, 218
	mov esi, 800
	mov edi, 160
	call alpha_fill_rect

	mov esi, .no_msr_msg
	mov bx, 32
	mov cx, 250
	mov edx, 0xDEDEDE
	call print_string_transparent

	mov esi, _boot_error_common
	mov bx, 32
	mov cx, 340
	mov edx, 0xDEDEDE
	call print_string_transparent

	jmp $

.no_sysenter:
	mov ebx, 0x333333
	mov cx, 0
	mov dx, 218
	mov esi, 800
	mov edi, 160
	call alpha_fill_rect

	mov esi, .no_sysenter_msg
	mov bx, 32
	mov cx, 250
	mov edx, 0xDEDEDE
	call print_string_transparent

	mov esi, _boot_error_common
	mov bx, 32
	mov cx, 340
	mov edx, 0xDEDEDE
	call print_string_transparent

	jmp $

.no_msr_msg			db "Boot error: This CPU doesn't support MSR: Model-Specific Registers.",0
.no_sysenter_msg		db "Boot error: ExDOS requires a Pentium II or better CPU.",0

use32

; sysenter_main:
; SYSENTER entry point

sysenter_main:
	mov ax, 0x10
	;mov ss, ax		; SYSENTER already did this for us
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	mov eax, [sysenter_esp]
	mov esp, eax

	;sti

	cmp byte[sysenter_custom], 1
	je .custom

	cli
	hlt

.custom:
	mov byte[sysenter_custom], 0
	mov eax, [sysenter_return]
	jmp eax

sysenter_custom			db 0
sysenter_return			dd 0
sysenter_esp			dd 0

; enter_ring0:
; puts the system in kernel mode

enter_ring0:
	mov byte[sysenter_custom], 1
	pop eax
	mov [sysenter_return], eax
	mov eax, esp
	mov [sysenter_esp], eax
	sysenter

; enter_ring3:
; Puts the system in user mode

enter_ring3:
	cli
	pop eax
	mov [.return], eax

	mov ax, 0x23
	;mov ss, ax
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	pushfd
	pop eax
	or eax, 0x202
	push eax
	popfd

	mov ecx, esp
	mov edx, .next
	sysexit

.next:
	pushfd
	pop eax
	or eax, 0x202
	push eax
	popfd

	mov eax, [.return]
	jmp eax

.return				dd 0

running_program			dd 0
is_program_running		db 0
program_return			dd 0
program_blocks			dd 0
program_return_stack		dd 0
program_phys_location		dd 0
program_name			dd 0

program_header:
	.magic			rb 5
	.version		rb 1
	.type			rb 1
	.program_size		rd 1
	.entry_point		rd 1
	.manufacturer		rd 1
	.program_name		rd 1
	.driver_type		rw 1
	.driver_hardware	rd 1
	.reserved		rd 1

program_header_size		= $ - program_header

; execute_program:
; Executes a program
; In\	ESI = Program path with parameters
; In\	EBX = Program return address
; Out\	EAX = Program exit code
; Out\	EBX = 0 on success, 0xDEADBEEF if program doesn't exist, 0xDEADC0DE if program caused errors

execute_program:
	mov [program_name], esi

	mov eax, dword[esp+4]
	mov [program_return], eax
	mov [program_return_stack], esp
	add dword[program_return_stack], 8

	mov esi, [program_name]
	mov edi, 0x40000			; load the program to a temporary location
	call load_file

	cmp eax, 0
	jne .not_found

	mov [.size], ecx
	mov eax, [.size]
	mov ebx, 1024
	mov edx, 0
	div ebx
	mov ebx, 4
	mov edx, 0
	div ebx

	add eax, 4
	mov [program_blocks], eax

	mov eax, 0x1400000
	mov ecx, [program_blocks]
	call pmm_find_free_block
	jc out_of_memory

	mov ebx, 0x8000000			; map the program to 128 MB
	mov ecx, [program_blocks]
	mov edx, 7
	call vmm_map_memory

	mov esi, 0x40000
	mov edi, 0x8000000
	mov ecx, [.size]
	rep movsb

	mov byte[is_program_running], 1

	call enter_ring3
	call 0x8000000

.return:
	;jmp $			; for debugging...
	call enter_ring0

	mov byte[is_program_running], 0
	;mov eax, ebx		; C/C++ returns exit codes in EAX, not EBX
	mov ebx, 0
	ret

.not_found:
	mov byte[is_program_running], 0
	mov eax, 0
	mov ebx, 0xDEADBEEF
	ret

.size				dd 0



