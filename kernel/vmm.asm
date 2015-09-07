
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

;; Functions:
; vmm_init
; vmm_map_memory
; vmm_unmap_memory
; vmm_get_phys_address

use32

page_directory			= 0x50000
page_table			= 0x100000			; page table takes up 4 MB of RAM
								; it can't be located in low memory
end_of_page_table		= 0x500000
pmm_table			= 0x600000
end_of_pmm_table		= 0x700000

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
	mov ecx, 4096
	rep stosb

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
	mov edx, 5				; user, present, read-only
	call vmm_map_memory

	mov eax, stack_area			; map stack area to itself
	mov ebx, stack_area
	mov ecx, 1				; 4 KB
	mov edx, 7				; user, present, read/write
	call vmm_map_memory

	; identify page 6 MB of RAM, which is the location of the physical memory bitmap
	mov eax, 0x600000
	mov ebx, 0x600000
	mov ecx, 257				; 257*4 KB blocks = 1 MB + 4 KB
	mov edx, 3				; present, read/write
	call vmm_map_memory

	; 10 MB of RAM, which is the location of the heap tables
	mov eax, heap_table
	mov ebx, heap_table
	mov ecx, 257
	mov edx, 3				; present, read/write
	call vmm_map_memory

	; identify page the kernel debugger, but without write access to the user
	mov eax, kdebugger_location
	mov ebx, kdebugger_location
	mov ecx, 32
	mov edx, 5				; user, present, read-only
	call vmm_map_memory

	mov byte[is_paging_enabled], 1

	mov eax, page_directory
	mov cr3, eax

	mov eax, cr0
	or eax, 0x80000000			; enable paging
	and eax, 0xDFFFFFFF			; disable write-through caching
	and eax, 0xBFFFFFFF			; disable caching
	and eax, 0xFFFEFFFF			; ensure the kernel can write to read-only pages
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
.debug_msg2			db " blocks of physical memory to virtual address 0x",0
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

	mov eax, [.virtual]
	call vmm_get_phys_address
	mov [.physical], eax

	cmp dword[.physical], 0xFFFFFFFF
	je .no_memory

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
	mov eax, [.physical]
	mov ecx, [.blocks]
	call pmm_free_memory

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

.no_memory:
	mov esi, .debug_msg4
	call kdebug_print

	mov eax, [.virtual]
	call hex_dword_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	ret

.physical			dd 0
.virtual			dd 0
.virtual_copy			dd 0
.blocks				dd 0
.debug_msg1			db "vmm: freeing ",0
.debug_msg2			db " blocks of virtual memory at address 0x",0
.debug_msg3			db "vmm: alignment error.",10,0
.debug_msg4			db "vmm: failed; there is no memory allocated at virtual address ",0

; vmm_get_phys_address:
; Gets physical address of a virtual address
; In\	EAX = Virtual address
; Out\	EAX = Physical address (0xDEADBEEF if address if not properly aligned, 0xFFFFFFFF if there is no memory at virtual address)

vmm_get_phys_address:
	pushfd
	cli

	mov [.virtual], eax

	cmp byte[is_paging_enabled], 1
	je .disable_paging

	jmp .work

.disable_paging:
	mov eax, cr0
	and eax, 0x7FFFFFFF
	mov cr0, eax

	mov eax, 0
	mov cr3, eax

.work:
	mov eax, [.virtual]
	test eax, 0xFFF
	jnz .error

	mov eax, [.virtual]
	mov ebx, 1024
	mov edx, 0
	div ebx

	;mov ebx, 4
	;mov edx, 0
	;div ebx

	mov esi, page_table
	add esi, eax

	mov eax, dword[esi]
	and eax, 0xFFFFF000

	mov [.physical], eax
	cmp dword[.physical], 0
	je .no_memory

	mov ebp, .done

	cmp byte[is_paging_enabled], 1
	je .enable_paging

.done:
	popfd
	mov eax, [.physical]
	ret

.enable_paging:
	mov eax, page_directory
	mov cr3, eax

	mov eax, cr0
	or eax, 0x80000000
	mov cr0, eax

	jmp ebp

.error:
	mov ebp, .done_error

	cmp byte[is_paging_enabled], 1
	je .enable_paging

.done_error:
	popfd
	mov eax, 0xDEADBEEF
	ret

.no_memory:
	mov ebp, .no_memory_quit

	cmp byte[is_paging_enabled], 1
	je .enable_paging

.no_memory_quit:
	popfd
	mov eax, 0xFFFFFFFF
	ret

.physical			dd 0
.virtual			dd 0

; vmm_get_free_page:
; Gets location of a free virtual address
; In\	EAX = Starting address
; In\	ECX = Number of free pages
; Out\	EFLAGS = Carry set on error
; Out\	EAX = Free page location

vmm_get_free_page:
	mov [.address], eax
	mov [.pages], ecx

	mov dword[.tmp], 0

	test dword[.address], 0xFFF
	jnz .error

	cmp dword[.pages], 0
	je .error

	; disable paging...
	mov eax, cr0
	and eax, 0x7FFFFFFF
	mov cr0, eax

	mov eax, 0
	mov cr3, eax

	mov eax, [.address]
	mov ebx, 1024
	mov edx, 0
	div ebx
	;mov ebx, 4
	;mov edx, 0
	;div ebx

	mov esi, page_table
	add esi, eax
	mov ecx, [.pages]

.find_free_block:
	mov eax, dword[esi]
	cmp eax, 0
	jne .find_another_block

	add esi, 4
	add dword[.tmp], 1
	cmp ecx, dword[.tmp]
	je .done

	jmp .find_free_block

.find_another_block:
	mov dword[.tmp], 0
	add dword[.address], 4096
	add esi, 4
	jmp .find_free_block

.done:
	; enable paging
	mov eax, page_directory
	mov cr3, eax

	mov eax, cr0
	or eax, 0x80000000
	mov cr0, eax

	mov eax, [.address]
	clc
	ret

.error:
	stc
	mov eax, 0
	ret

.address			dd 0
.pages				dd 0
.tmp				dd 0

heap_table			= 0xA00000
heap_free_area			dd heap_table

; The heap table is an array of QWORDS.
; The low DWORD is the virtual address of allocated memory, and the high dword is size of allocated memory in pages.

; malloc:
; Allocates memory
; In\	EDX = Bytes to allocate
; Out\	EAX = Location of free memory, 0 on error

malloc:
	cmp edx, 0
	je .error

	mov eax, edx
	mov ebx, 4096
	call round_forward
	mov ebx, 1024
	mov edx, 0
	div ebx
	mov ebx, 4
	mov edx, 0
	div ebx
	mov [.size], eax

	mov eax, 0x1400000
	mov ecx, [.size]
	call pmm_find_free_block
	jc .error

	mov [.physical], eax
	mov eax, 0x8000000
	mov ecx, [.size]
	call vmm_get_free_page
	jc .error

	mov [.virtual], eax

	mov eax, [.physical]
	mov ebx, [.virtual]
	mov ecx, [.size]
	mov edx, 7
	call vmm_map_memory

	mov edi, [heap_free_area]
	mov eax, [.virtual]
	stosd
	mov eax, [.size]
	stosd
	mov [heap_free_area], edi

	mov eax, [.virtual]
	ret

.error:
	mov eax, 0
	ret

.size				dd 0
.physical			dd 0
.virtual			dd 0

; free:
; Frees allocated memory
; In\	EDX = Allocated memory location
; Out\	EAX = 0

free:
	mov [.memory], edx

	mov eax, [.memory]
	mov esi, heap_table

.loop:
	cmp eax, dword[esi]
	je .found_memory

	add esi, 8
	cmp esi, heap_table+0x100000
	jge .done

.found_memory:
	mov eax, dword[esi]
	mov ecx, dword[esi+4]		; size in pages
	call vmm_unmap_memory

.done:
	mov eax, 0			; return a null pointer
	ret

.memory				dd 0

