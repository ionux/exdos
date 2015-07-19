
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

.no_msr_msg			db "Boot error: This CPU doesn't support MSR: Model-Specific Registers.",0

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
	push eax
	ret

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

	push 0x23
	mov eax, esp
	push eax
	pushfd
	pop eax
	or eax, 0x202
	push eax
	push 0x1B
	lea eax, [.next]
	push eax

	iretd

.next:
	mov eax, [.return]
	push eax
	ret
	
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
; Out\	EBX = 0 on success, 0xDEADC0DE if program is corrupted, 0xDEADBEEF is program doesn't exist, 0xFEFE if not enough memory

execute_program:
	mov [program_return], ebx
	mov [program_name], esi

	mov [program_return_stack], ebp
	add dword[program_return_stack], 24	; fix stack

	mov esi, [program_name]
	mov edi, disk_buffer
	call load_file				; load program to a temporary location

	cmp eax, 0
	jne .file_not_found

	mov esi, disk_buffer
	mov edi, program_header
	mov ecx, program_header_size
	rep movsb

	mov esi, disk_buffer
	mov edi, .program_magic
	mov ecx, 5
	rep cmpsb
	jne .corrupted

	mov eax, [program_header.program_size]
	test eax, 0xFFF				; make sure program size is a multiple of 4096
	jnz .corrupted

	cmp byte[program_header.type], 0	; make sure we're executing a program and not a driver
	jne .corrupted

	cmp byte[program_header.version], 1	; until I think of something else, I only have one version of the executable format
	jne .corrupted

	mov eax, [program_header.program_size]
	mov edx, 0
	mov ebx, 1024
	div ebx

	mov edx, 0
	mov ebx, 4
	div ebx

	mov [program_blocks], eax		; program size in 4 KB blocks

	mov ecx, [program_blocks]
	mov eax, 0x1400000
	call pmm_find_free_block		; find a free memory block
	jc .no_memory

	mov [program_phys_location], eax

	mov eax, [program_phys_location]
	mov ebx, 0x8000000
	mov ecx, [program_blocks]
	mov edx, 7
	call vmm_map_memory

	mov esi, disk_buffer
	mov edi, 0x8000000
	mov ecx, [program_header.program_size]
	rep movsb				; copy program to virtual address 128 MB

	mov byte[is_program_running], 1
	call enter_ring3

	add esp, 24				; clean stack
	mov ebp, [program_header.entry_point]
	jmp ebp

.no_memory:
	mov ebx, 0xFEFE
	ret

.corrupted:
	mov ebx, 0xDEADC0DE
	ret

.file_not_found:
	mov ebx, 0xDEADBEEF
	ret

.program_magic			db "ExDOS"

; terminate_program:
; Terminates a running program
; In\	EBX = Exit code
; Out\	Nothing

terminate_program:
	mov [.exit_code], ebx

	; First, let's free the memory used by the program so that other programs can use it
	mov eax, 0x8000000
	mov ecx, [program_blocks]
	call vmm_unmap_memory			; free the virtual memory

	mov eax, [program_phys_location]
	mov ecx, [program_blocks]
	call pmm_free_memory			; free physical memory too

	mov byte[is_program_running], 0

	call enter_ring3

	mov ebp, [program_return_stack]
	mov esp, ebp
	mov ebp, [program_return]

	mov eax, [.exit_code]
	mov ebx, 0
	jmp ebp

.exit_code				dd 0


