
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/vmm.asm							;;
;; Virtual Memory Manager						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

; vmm_init:
; Initializes the paging system and the virtual memory manager

vmm_init:
	cli
	cld

	mov esi, .debug_msg1
	call kdebug_print

	; first, let's clear the page directory and page tables
	mov edi, page_directory
	mov eax, 0
	mov ecx, 1024
	rep stosd

	mov edi, page_table
	mov eax, 0
	mov ecx, 0x100000
	rep stosd

	; now, let's fill the page directory with the page table offsets
	mov edi, page_directory
	mov ebx, page_table
	mov ecx, 0

.fill_directory:
	mov eax, ebx
	or eax, 7
	stosd

	add ebx, 4096
	cmp ebx, end_of_page_table
	jg .filled_directory
	jmp .fill_directory

.filled_directory:
	; identify page the first 1 MB of RAM, so that BIOS can work
	mov eax, 0				; map 0x0 --
	mov ebx, 0				; -- to 0x0
	mov ecx, 256				; 256*4 KB blocks = 1 MB
	mov edx, 7
	call vmm_map_memory

	; identify page 6 MB of RAM, which is the location of the physical memory bitmap
	mov eax, 0x600000
	mov ebx, 0x600000
	mov ecx, 257				; 257*4 KB blocks = 1 MB + 4 KB
	mov edx, 3				; 3 = read/write for kernel only
	call vmm_map_memory

	mov byte[is_paging_enabled], 1

	mov eax, page_directory
	mov cr3, eax

	mov eax, cr0
	or eax, 0x80000000			; set bit 31 (Paging) bit
	mov cr0, eax

	ret

.debug_msg1			db "vmm: starting up...",10,0

; vmm_map_memory:
; Maps physical memory to a virtual address
; In\	EAX = Physical address (must be 4 KB aligned)
; In\	EBX = Virtual address (must be 4 KB aligned)
; In\	ECX = Number of 4 KB blocks to map
; In\	EDX = Attributes
; Out\	EAX = 0 on success, 1 on error

vmm_map_memory:
	pusha
	mov [.physical], eax
	mov [.virtual], ebx
	mov [.blocks], ecx
	mov [.attributes], edx

	mov esi, .debug_msg1
	call kdebug_print

	mov eax, [.blocks]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg2
	call kdebug_print_noprefix

	mov eax, [.virtual]
	call hex_dword_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	pushfd
	cli

	cmp byte[is_paging_enabled], 1
	jne .work

.disable_paging:
	; disable paging to prevent page faults
	mov eax, cr0
	and eax, 0x7FFFFFFF			; clear paging bit
	mov cr0, eax

	mov eax, 0
	mov cr3, eax

.work:
	; make sure the addresses are 4KB aligned
	mov eax, [.physical]	
	test eax, 0xFFF
	jnz .error

	mov eax, [.virtual]
	test eax, 0xFFF
	jnz .error

	mov eax, [.virtual]
	mov ebx, 1024
	mov edx, 0
	div ebx

	mov [.virtual_copy], eax
	mov eax, [.virtual_copy]
	mov edi, page_table
	add edi, eax

	mov ecx, 0
	mov ebx, [.physical]

.fill_table:
	mov eax, ebx
	mov edx, [.attributes]
	or eax, edx
	stosd
	add ebx, 4096
	add ecx, 1
	cmp ecx, dword[.blocks]
	jge .done
	jmp .fill_table

.done:
	cmp dword[.virtual], 0xE0000000		; if we're allocating a VESA frame buffer --
	je .really_quit				; -- don't allocate physical memory --
						; -- because the framebuffer is not part of physical RAM.

	mov eax, [.physical]
	mov ecx, [.blocks]
	call pmm_allocate_memory

.really_quit:
	mov ebp, .quit
	cmp byte[is_paging_enabled], 1
	jne .quit

	jmp .enable_paging

.quit:
	popfd
	popa
	mov eax, 0
	ret

.error:
	mov esi, .debug_msg3
	call kdebug_print

	mov ebp, .quit_error
	cmp byte[is_paging_enabled], 1
	jne .quit_error

.enable_paging:
	mov eax, page_directory
	mov cr3, eax

	mov eax, cr0
	or eax, 0x80000000
	mov cr0, eax

	jmp ebp

.quit_error:
	popfd
	popa
	mov eax, 1
	ret

.physical			dd 0
.virtual			dd 0
.virtual_copy			dd 0
.blocks				dd 0
.attributes			dd 0
.debug_msg1			db "vmm: mapping ",0
.debug_msg2			db " blocks of physical memory to virtual address ",0
.debug_msg3			db "vmm: alignment error.",10,0

; vmm_unmap_memory:
; Frees a virtual address
; In\	EAX = Virtual address
; In\	ECX = Number of 4 KB blocks to free
; Out\	EAX = 0 on success, 1 on error

vmm_unmap_memory:
	mov [.virtual], eax
	mov [.blocks], ecx

	mov esi, .debug_msg1
	call kdebug_print

	mov eax, [.blocks]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg2
	call kdebug_print_noprefix

	mov eax, [.virtual]
	call hex_dword_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	pushfd
	cli

	cmp byte[is_paging_enabled], 1
	jne .work

.disable_paging:
	; disable paging to prevent page faults
	mov eax, cr0
	and eax, 0x7FFFFFFF			; clear paging bit
	mov cr0, eax

	mov eax, 0
	mov cr3, eax

.work:
	mov eax, [.virtual]
	test eax, 0xFFF
	jnz .error

	mov eax, [.virtual]
	mov edx, 0
	mov ebx, 1024
	div ebx

	mov [.virtual_copy], eax
	mov eax, [.virtual_copy]
	mov edi, page_table
	add edi, eax

	mov eax, 0
	mov ecx, [.blocks]
	rep stosd

.done:
	mov ebp, .quit
	cmp byte[is_paging_enabled], 1
	jne .quit

	jmp .enable_paging

.quit:
	popfd
	mov eax, 0
	ret

.error:
	mov esi, .debug_msg3
	call kdebug_print

	mov ebp, .quit_error
	cmp byte[is_paging_enabled], 1
	jne .quit_error

.enable_paging:
	mov eax, page_directory
	mov cr3, eax

	mov eax, cr0
	or eax, 0x80000000
	mov cr0, eax

	jmp ebp

.quit_error:
	popfd
	mov eax, 1
	ret

.virtual			dd 0
.virtual_copy			dd 0
.blocks				dd 0
.debug_msg1			db "vmm: freeing ",0
.debug_msg2			db " blocks of virtual memory at address ",0
.debug_msg3			db "vmm: alignment error.",10,0


