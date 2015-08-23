
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

;; Functions:
; load_tss
; init_sysenter
; sysenter_main
; enter_ring0
; enter_ring3
; execute_program

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
	mov eax, stack_area+stack_size
	mov dword[tss.esp0], eax
	mov dword[tss.esp], eax

	pushfd
	pop eax
	;or eax, 0x202			; interrupts are always enabled
	or eax, 2
	mov dword[tss.eflags], eax

	mov eax, 0x3B			; RPL 3
	ltr ax				; load the TSS

	ret

; init_sysenter:
; Initializes SYSENTER/SYSEXIT instructions

init_sysenter:
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
	mov esi, .no_msr_msg
	jmp draw_boot_error

.no_sysenter:
	mov esi, .no_sysenter_msg
	jmp draw_boot_error

.no_msr_msg			db "CPU doesn't support MSR: Model-Specific Registers.",0
.no_sysenter_msg		db "CPU doesn't support SYSENTER/SYSEXIT.",0

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

	mov eax, dword[stack_area]
	mov dword[stack_area], 0
	mov esp, eax
	pop eax
	jmp eax

; enter_ring0:
; puts the system in kernel mode

enter_ring0:
	mov eax, esp
	mov dword[stack_area], eax
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
; Out\	EBX = 0 on success, 0xDEADBEEF if program doesn't exist, 0xDEADC0DE if program caused errors, 0xBADC0DE if program is corrupt, 0xFFFFFFFF if program can't fit in memory

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

	mov esi, 0x40000
	mov edi, program_header
	mov ecx, program_header_size
	rep movsb

	mov esi, program_header.magic
	mov edi, .program_magic
	mov ecx, 5
	rep cmpsb
	jne .corrupt

	cmp byte[program_header.type], 0
	jne .corrupt

	mov eax, [program_header.program_size]
	test eax, 0xFFF			; program size must be multiple of 4 KB
	jnz .corrupt

	mov eax, [program_header.program_size]
	mov ebx, 1024
	mov edx, 0
	div ebx
	mov ebx, 4
	mov edx, 0
	div ebx
	mov [.size], eax

	mov ecx, [.size]		; enough memory for the program
	mov eax, 0x1400000		; look for free memory starting at 20 MB
	call pmm_find_free_block
	jc .too_little_memory

	mov ebx, 0x8000000		; map the program to 128 MB
	mov ecx, [.size]
	mov edx, 7			; present | user | read/write
	call vmm_map_memory

	mov esi, 0x40000
	mov edi, 0x8000000
	mov ecx, [program_header.program_size]
	rep movsb

	mov byte[is_program_running], 1

	call enter_ring3

	mov eax, [program_header.entry_point]
	call eax

	pusha
	call enter_ring0

	mov eax, 0x8000000
	mov ecx, [.size]
	call vmm_unmap_memory		; free the memory used by the program

	popa

	mov byte[is_program_running], 0
	mov ebx, 0
	ret

.not_found:
	mov byte[is_program_running], 0
	mov eax, 0
	mov ebx, 0xDEADBEEF
	ret

.corrupt:
	mov byte[is_program_running], 0
	mov eax, 0
	mov ebx, 0xBADC0DE
	ret

.too_little_memory:
	mov byte[is_program_running], 0
	mov eax, 0
	mov ebx, 0xFFFFFFFF
	ret

.program_magic			db "ExDOS"
.size				dd 0



