
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

process_list			= 0x60000
process_list_entry_size		= 8
maximum_processes		= 255
process_list_size		= maximum_processes*process_list_entry_size	; 2 KB

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

running_processes		db 0

; get_program_info:
; Gets the memory info on a specified program
; In\	EAX = Slot number
; Out\	EDI = Pointer to program information

get_program_info:
	mov ebx, process_list_entry_size
	mul ebx
	mov edi, eax
	add edi, process_list
	ret

; execute_program:
; Executes a program
; In\	ESI = Program file name with parameters, ASCIIZ
; Out\	EAX = Program exit code
; Out\	EBX = 0 on success, 0xDEADBEEF if program doesn't exist, 0xDEADC0DE if program caused errors, 0xBADC0DE if program is corrupt, 0xFFFFFFFF if program can't fit in memory

execute_program:
	mov [program_name], esi

	cmp byte[running_processes], maximum_processes
	je .too_little_memory

	mov edi, program_path
	mov ecx, 256
	mov eax, 0
	rep stosb

	mov edi, program_params
	mov ecx, 256
	mov eax, 0
	rep stosd

	mov esi, [program_name]
	call get_string_size
	mov esi, [program_name]
	mov edi, program_path
	mov ecx, eax
	rep movsb

	mov esi, program_path
	call get_string_size
	mov ecx, eax
	mov esi, program_path
	mov dl, ' '
	call find_byte_in_string
	jc .no_params

	mov edi, esi
	mov al, 0
	stosb

	mov esi, edi
	push esi
	call get_string_size
	pop esi
	mov ecx, eax
	mov edi, program_params
	rep movsb

	mov edi, program_params
	push edi
	jmp .load_program

.no_params:
	mov eax, 0
	push eax
	jmp .load_program

.load_program:
	mov esi, program_path
	mov ecx, 11
	mov dl, '.'
	call find_byte_in_string
	jc .no_extension

	jmp .load_file

.no_extension:
	mov esi, program_path
	call get_string_size
	mov edi, program_path
	add edi, eax
	mov eax, ".exe"		; put the extension if the user didn't put it in
	stosd
	mov al, 0		; the filesystem driver only accepts ASCIIZ file names
	stosb

.load_file:
	mov esi, program_path
	mov edi, 0x40000
	call load_file
	cmp eax, 0
	jne .not_found

	mov esi, 0x40000
	mov edi, program_header
	mov ecx, program_header_size
	rep movsb

	mov esi, program_header
	mov edi, .program_magic
	mov ecx, 5
	rep cmpsb
	jne .corrupt

	cmp byte[program_header.version], 1
	jne .corrupt

	cmp byte[program_header.type], 0
	jne .corrupt

	test dword[program_header.program_size], 0xFFF
	jnz .corrupt

.allocate_memory:
	mov eax, [program_header.program_size]
	mov ebx, 1024
	mov edx, 0
	div ebx
	mov ebx, 4
	mov edx, 0
	div ebx

	push eax
	mov ecx, eax
	mov eax, 0x1400000			; 20 MB
	call pmm_find_free_block
	jc .too_little_memory

	pop ecx
	push eax
	push ecx
	inc byte[running_processes]
	movzx eax, [running_processes]
	call get_program_info

	pop ecx
	pop eax
	push eax
	push ecx

	mov [edi], eax
	mov [edi+4], ecx

	mov esi, .debug_msg1
	call kdebug_print

	mov esi, [program_name]
	call kdebug_print_noprefix

	mov esi, .debug_msg2
	call kdebug_print_noprefix

	movzx eax, [running_processes]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	pop ecx
	pop eax
	mov ebx, 0x8000000			; 128 MB
	mov edx, 7				; User | Present | Read/write
	call vmm_map_memory

	mov esi, 0x40000
	mov edi, 0x8000000
	mov ecx, [program_header.program_size]
	rep movsb

	call enter_ring3

.execute:
	mov ebx, [program_header.entry_point]
	movzx eax, [running_processes]
	call ebx

.next:
	call enter_ring0
	add esp, 4
	dec byte[running_processes]

	cmp byte[running_processes], 0
	je panic_no_processes

	mov [.return], eax

	movzx eax, [running_processes]
	inc eax
	call get_program_info

	mov eax, 0x8000000
	mov ecx, [edi+4]
	call vmm_unmap_memory

	movzx eax, [running_processes]
	call get_program_info

	mov eax, [edi]
	mov ecx, [edi+4]
	mov ebx, 0x8000000
	mov edx, 7
	call vmm_map_memory

	mov ebx, 0
	ret

.not_found:
	add esp, 4
	mov eax, 0
	mov ebx, 0xDEADBEEF
	ret

.corrupt:
	add esp, 4
	mov eax, 0
	mov ebx, 0xBADC0DE
	ret

.too_little_memory:
	add esp, 4
	mov eax, 0
	mov ebx, 0xFFFFFFFF
	ret

.program_magic			db "ExDOS"
.size				dd 0
.debug_msg1			db "kernel: creating process '",0
.debug_msg2			db "' with PID ",0
.return				dd 0
.is_there_params		db 0

program_path:			rb 256
program_params:			rb 256

; panic_no_processes:
; Kernel panic when there are no processes

panic_no_processes:
	mov esi, .msg
	call draw_panic_screen

.msg				db "There are no processes to execute!",0


