
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/pmm.asm							;;
;; Physical Memory Manager						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

free_memory			dd 0
used_memory			dd 0
total_memory			dd 0

; pmm_init:
; Initializes the physical memory manager

pmm_init:
	mov esi, .debug_msg
	call kdebug_print

	mov eax, [total_memory_mb]
	call int_to_string

	call kdebug_print_noprefix

	mov esi, .debug_msg2
	call kdebug_print_noprefix

	mov dword[used_memory], 0

	mov eax, [total_memory_kb]
	mov ebx, 4
	mov edx, 0
	div ebx

	mov [free_memory], eax
	mov [total_memory], eax

	mov eax, 0
	mov edi, pmm_table
	mov ecx, 0x100000
	rep stosd

	ret

.debug_msg			db "pmm: starting with ",0
.debug_msg2			db " MB of RAM.",10,0

; pmm_allocate_memory:
; Allocates physical memory
; In\	EAX = Physical location of memory (4 KB aligned)
; In\	ECX = Numbers of 4 KB blocks to allocate
; Out\	EAX = 0 on success, 1 if alignment error, 2 if too little memory

pmm_allocate_memory:
	mov [.physical], eax
	mov [.blocks], ecx

	mov esi, .debug_msg1
	call kdebug_print

	mov eax, [.blocks]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg2
	call kdebug_print_noprefix

	mov eax, [.physical]
	call hex_dword_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	mov eax, [.physical]
	test eax, 0xFFF
	jnz .alignment_error

	mov eax, [.blocks]
	mov ebx, 4
	mul ebx
	mov ebx, 1024
	mul ebx
	add eax, dword[.physical]

	cmp eax, [total_memory_bytes]
	jge .too_little_memory

	mov eax, [.physical]
	mov ebx, 1024
	mov edx, 0
	div ebx
	mov ebx, 4
	mov edx, 0
	div ebx

	mov edi, pmm_table
	add edi, eax

	mov al, 1
	mov ecx, [.blocks]
	rep stosb

	mov ecx, [.blocks]
	add dword[used_memory], ecx
	mov ecx, [.blocks]
	sub dword[free_memory], ecx

	mov eax, [used_memory]
	mov ebx, [free_memory]
	add eax, ebx
	mov [total_memory], eax

	mov eax, 0
	ret

.too_little_memory:
	mov esi, .debug_msg3
	call kdebug_print

	mov eax, 2
	ret

.alignment_error:
	mov esi, .debug_msg4
	call kdebug_print

	mov eax, 1
	ret

.physical			dd 0
.blocks				dd 0
.debug_msg1			db "pmm: allocating ",0
.debug_msg2			db " blocks of memory at location ",0
.debug_msg3			db "pmm: too little memory.",10,0
.debug_msg4			db "pmm: alignment error.",10,0

; pmm_free_memory:
; Frees physical memory
; In\	EAX = Physical location of memory (4 KB aligned)
; In\	ECX = Numbers of 4 KB blocks to free
; Out\	EAX = 0 on success, 1 if alignment error, 2 if too little memory

pmm_free_memory:
	mov [.physical], eax
	mov [.blocks], ecx

	mov esi, .debug_msg1
	call kdebug_print

	mov eax, [.blocks]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg2
	call kdebug_print_noprefix

	mov eax, [.physical]
	call hex_dword_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	mov eax, [.physical]
	test eax, 0xFFF
	jnz .alignment_error

	mov eax, [.blocks]
	mov ebx, 4
	mul ebx
	mov ebx, 1024
	mul ebx
	add eax, dword[.physical]

	cmp eax, [total_memory_bytes]
	jge .too_little_memory

	mov eax, [.physical]
	mov ebx, 1024
	mov edx, 0
	div ebx
	mov ebx, 4
	mov edx, 0
	div ebx

	mov edi, pmm_table
	add edi, eax

	mov al, 0
	mov ecx, [.blocks]
	rep stosb

	mov ecx, [.blocks]
	add dword[free_memory], ecx
	mov ecx, [.blocks]
	sub dword[used_memory], ecx

	mov eax, [used_memory]
	mov ebx, [free_memory]
	add eax, ebx
	mov [total_memory], eax

	mov eax, 0
	ret

.too_little_memory:
	mov esi, .debug_msg3
	call kdebug_print

	mov eax, 2
	ret

.alignment_error:
	mov esi, .debug_msg4
	call kdebug_print

	mov eax, 1
	ret

.physical			dd 0
.blocks				dd 0
.debug_msg1			db "pmm: freeing ",0
.debug_msg2			db " blocks of memory at location ",0
.debug_msg3			db "pmm: too little memory.",10,0
.debug_msg4			db "pmm: alignment error.",10,0

; pmm_find_free_block:
; Finds a free physical memory block
; In\	EAX = Starting address (must be 4 KB aligned)
; In\	ECX = Number of 4 KB blocks
; Out\	EAX = Address of free block
; Out\	EFLAGS = Carry set on error

pmm_find_free_block:
	pusha
	mov [.address], eax
	mov [.blocks], ecx

	mov eax, [.address]
	test eax, 0xFFF
	jnz .error

	mov eax, [.address]
	mov [.start], eax

	mov eax, [.address]
	mov ebx, 1024
	mov edx, 0
	div ebx
	mov ebx, 4
	mov edx, 0
	div ebx
	push eax
	cmp eax, [total_memory]
	jge .error2

	pop eax

	mov esi, pmm_table
	add esi, eax
	mov [.pmm_table], esi

	mov esi, pmm_table
	mov eax, [total_memory]
	add esi, eax
	mov [.end_pmm_table], esi

	mov esi, [.pmm_table]

.find_empty_blocks:
	cmp byte[esi], 1
	je .used_block

	add dword[.tmp_blocks], 1
	;add dword[.start], 4096
	mov ecx, [.tmp_blocks]
	cmp ecx, [.blocks]
	jge .done

	add dword[.pmm_table], 1
	mov esi, [.pmm_table]
	cmp esi, dword[.end_pmm_table]
	jge .error
	jmp .find_empty_blocks

.used_block:
	add dword[.start], 4096
	add dword[.pmm_table], 1
	mov dword[.tmp_blocks], 0

	mov esi, [.pmm_table]
	cmp esi, dword[.end_pmm_table]
	jge .error
	jmp .find_empty_blocks

.error2:
	pop eax

.error:
	popa
	stc
	mov eax, 0
	ret

.done:
	popa
	clc
	mov eax, [.start]
	ret

.address			dd 0
.blocks				dd 0
.tmp_blocks			dd 0
.pmm_table			dd 0
.end_pmm_table			dd 0
.start				dd 0

; segmented_to_linear:
; Converts a segment:offset address to a linear address
; In\	CX:DX = Segment:Offset
; Out\	EAX = Linear address

segmented_to_linear:
	push edx
	movzx eax, cx
	mov ebx, 0x10
	mul ebx
	pop edx
	and edx, 0xFFFF
	add eax, edx

	ret





