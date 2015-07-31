
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/system.asm							;;
;; Internal System Routines						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use16

bootdisk			db 0

boot_partition:
	.boot			db 0
	.chs			db 0
				db 0
				db 0
	.type			db 0
	.end_chs		db 0
				db 0
				db 0
	.lba			dd 0
	.size			dd 0

; enable_a20:
; Enables A20 gate
; In\	Nothing
; Out\	Nothing

enable_a20:
	mov ax, 0x2401					; try to use the BIOS to enable A20
	int 0x15
	jc .kbd						; on error, use the PS/2 keyboard controller fallback method

	cmp ah, 0x86
	je .kbd

	cmp ah, 0x80
	je .kbd

	ret

.kbd:
	cli
	call .a20wait
	mov al, 0xAD
	out 0x64, al

	call .a20wait
	mov al, 0xD0
	out 0x64, al

	call .a20wait2
	in al, 0x60
	push eax

	call .a20wait
	mov al, 0xD1
	out 0x64, al

	call .a20wait
	pop eax
	or al, 2
	out 0x60, al

	call .a20wait
	mov al, 0xAE
	out 0x64, al

	call .a20wait
	sti
	ret

.a20wait:
	in al, 0x64
	test al, 2
	jnz .a20wait
	ret

.a20wait2:
	in al, 0x64
	test al, 1
	jz .a20wait2
	ret

; check_a20:
; Checks if A20 is enabled
; In\	Nothing
; Out\	Nothing

check_a20:
	mov ecx, 0xFFFF			; According to DexOS source code, some PCs need a short delay

.delay:
	nop
	nop
	nop
	nop
	loop .delay

.check_a20:
	mov di, 0x500
	mov eax, 0
	stosd

	mov ax, 0xFFFF
	mov es, ax
	mov di, 0x510
	mov eax, "A20 "
	stosd

	mov ax, 0
	mov es, ax

	mov si, 0x500
	lodsd

	cmp eax, "A20 "
	je .not_enabled

.enabled:
	ret

.not_enabled:
	mov si, .fail_msg
	call print_string_16

.hlt:
	hlt
	jmp .hlt

.fail_msg			db "Boot error: A20 gate is not responding.",0

; detect_memory:
; Detects memory using BIOS E820, with E801 as a fallback method

detect_memory:
	mov word[.map_entries], 0
	mov di, memory_map
	mov ebx, 0

.loop:
	mov ecx, 24
	mov eax, 0xE820
	mov edx, 0x534D4150
	push di
	int 0x15
	pop di

	jc .error

	cmp eax, 0x534D4150
	jne .fail

	cmp ebx, 0
	je .e820_count_mem

	cmp cl, 20
	je .force_acpi3

	add di, 24
	add word[.map_entries], 1
	jmp .loop

.force_acpi3:
	mov dword[di+20], 0			; if the BIOS returned only 20 bytes, force a valid ACPI 3 entry to make 24 bytes

	add di, 24
	add word[.map_entries], 1
	jmp .loop

.error:
	cmp ebx, 0
	je .e820_count_mem

.fail:
	mov si, .fail_msg
	call print_string_16

	mov si, _crlf
	call print_string_16

	mov eax, 0xE801
	mov cx, 0
	mov dx, 0
	int 0x15
	jc .really_fail

	cmp ah, 0x86
	je .really_fail

	cmp ah, 0x80
	je .really_fail

	cmp cx, 0
	je .use_ax

	mov ax, cx
	mov bx, dx

.use_ax:
	add ax, 1024				; function E801 doesn't count the first MB
	mov [.lomem], ax
	mov [.himem], bx

	call go32

use32

	movzx eax, word[.himem]
	mov ebx, 64
	mul ebx
	movzx ebx, word[.lomem]
	add eax, ebx
	mov [total_memory_kb], eax

	mov ebx, 1024
	mov edx, 0
	div ebx
	mov [total_memory_mb], eax

	mov eax, [total_memory_kb]
	mov ebx, 1024
	mul ebx
	mov [total_memory_bytes], eax

	mov dword[acpi_reserved_memory], 0x100000	; let's assume ACPI needs 1 MB, because E801 can't get a memory map

	call go16

use16

	ret

.really_fail:
	mov si, .really_fail_msg
	call print_string_16

.hlt:
	hlt
	jmp .hlt

.e820_count_mem:
	call go32

use32
	cli

	movzx eax, word[.map_entries]
	mov ebx, 24
	mul ebx
	mov edi, memory_map
	add eax, edi
	mov [.map_size], eax

	mov edi, memory_map

.count_ram:
	cmp dword[edi+16], 1			; "Normal" usable RAM
	je .found_good_ram

	add edi, 24
	cmp edi, dword[.map_size]
	jg .done

	jmp .count_ram

.found_good_ram:
	mov eax, dword[edi+8]
	add dword[.tmp_size], eax
	mov eax, dword[edi+12]
	add dword[.tmp_size2], eax

	add edi, 24
	cmp edi, dword[.map_size]
	jg .done
	jmp .count_ram

.done:
	; Now, convert the calculated memory size into KB and MB
	mov eax, [.tmp_size]
	mov [total_memory_bytes], eax

	mov eax, [.tmp_size]
	mov edx, [.tmp_size2]
	mov ebx, 1024
	div ebx

	mov [total_memory_kb], eax

	mov ebx, 1024
	mov edx, 0
	div ebx

	mov [total_memory_mb], eax

	call go16

use16

	ret

.fail_msg			db "BIOS function E820 failed; using function E801 fallback.",0
.really_fail_msg		db "Boot error: Failed to detect memory... Broken BIOS?",0
.lomem				dw 0
.himem				dw 0
.map_entries			dw 0
.map_size			dd 0
.tmp				dd 0
.tmp_size			dd 0
.tmp_size2			dd 0

total_memory_bytes		dd 0
total_memory_kb			dd 0
total_memory_mb			dd 0

is_paging_enabled		db 0

; verify_enough_memory:
; Verifies there is enough RAM onboard

verify_enough_memory:
	cmp dword[total_memory_mb], 32
	jl .too_little

	ret

.too_little:
	mov si, .too_little_msg
	call print_string_16

	jmp $

.too_little_msg			db "Boot error: Less than 32 MB of usable RAM was found.",0

; go32:
; Enters 32-bit mode

go32:
	pop bp					; save return address
	push eax
	push ebx
	push ecx
	push edx

	cli
	lgdt [gdtr]
	lidt [idtr]

	mov eax, cr0
	or eax, 1
	mov cr0, eax

	jmp 8:.pmode

use32

.pmode:
	mov ax, 0x10
	mov ss, ax
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	movzx esp, sp				; 32-bit stack

	cmp byte[is_paging_enabled], 0
	je .done

	mov eax, page_directory
	mov cr3, eax

	mov eax, cr0
	or eax, 0x80000000
	mov cr0, eax

.done:
	sti

	pop edx
	pop ecx
	pop ebx
	pop eax

	;hlt

	and ebp, 0xFFFF
	jmp ebp

; go16:
; Enters 16-bit mode

go16:
	pop ebp

	push eax
	push ebx
	push ecx
	push edx

	cli

	mov eax, cr0
	and eax, 0x7FFFFFFF		; disable paging
	mov cr0, eax

	mov eax, 0
	mov cr3, eax			; clear page directory register

	jmp 0x28:.pmode16

use16

.pmode16:
	mov ax, 0x30
	mov ss, ax
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	movzx esp, sp

	mov eax, cr0
	and eax, 0xFFFFFFFE		; disable protection
	mov cr0, eax

	jmp 0:.rmode

.rmode:
	mov ax, 0
	mov ss, ax
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	lidt [ivt]

	sti

	pop edx
	pop ecx
	pop ebx
	pop eax

	;hlt

	and ebp, 0xFFFF
	jmp bp

use32

; remap_pic:
; Remaps IRQ 0-8 to INT 32-47

remap_pic:
	cli

	mov esi, .debug_msg
	call kdebug_print

	; remap the IRQs on the PIC
	mov al, 0x11
	out 0x20, al
	
	mov al, 0x11
	out 0xA0, al
	
	mov al, 0x20
	out 0x21, al
	
	mov al, 0x28
	out 0xA1, al
	
	mov al, 4
	out 0x21, al
	
	mov al, 2
	out 0xA1, al
	
	mov al, 1
	out 0x21, al
	
	mov al, 1
	out 0xA1, al
	
	mov al, 0
	out 0x21, al
	
	mov al, 0
	out 0xA1, al
	
	; remap the real mode IVT as well
	mov dword[.irq], 8

.loop:
	mov eax, [.irq]
	mov ebx, 4
	mul ebx
	
	mov esi, eax
	mov edx, dword[esi]
	push edx
	
	mov eax, [.irq]
	add eax, 24
	mov ebx, 4
	mul ebx
	
	pop edx
	
	mov edi, eax
	mov dword[edi], edx
	
	cmp dword[.irq], 23
	je .done
	
	add dword[.irq], 1
	jmp .loop
	
.done:
	;sti
	ret
	
.debug_msg					db "kernel: remapped PIC #1 offset to INT 32.",10,0
.irq						dd 0

; init_pit:
; Initializes the PIT to 100 Hz

init_pit:
	mov al, 0x36
	out 0x43, al

	mov eax, 11931		; 100 Hz
	out 0x40, al
	mov al, ah
	out 0x40, al

	mov al, 32
	mov ebp, pit_irq
	call install_isr

	ret

; init_sse:
; Enables SSE

init_sse:
	cli
	mov eax, 1
	cpuid

	test edx, 0x2000000
	jz .no_sse

	mov eax, cr0
	and eax, 0xFFFFFFFB
	or eax, 2
	mov cr0, eax

	mov eax, cr4
	or eax, 0x600
	mov cr4, eax

	ret

.no_sse:
	mov ebx, 0x333333
	mov cx, 0
	mov dx, 218
	mov esi, 800
	mov edi, 160
	call alpha_fill_rect

	mov esi, .no_sse_msg
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

.no_sse_msg				db "Boot error: This CPU doesn't support SSE: Streaming SIMD extensions.",0

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

; delay_execution:
; Pauses execution for a specified number of seconds
; In\	EAX = Seconds to wait
; Out\	Nothing

delay_execution:
	pushfd
	pusha
	sti

	mov ebx, 100
	mul ebx
	mov ebx, [ticks]
	add eax, ebx

.wait:
	cmp eax, [ticks]
	jle .done
	jmp .wait

.done:
	popa
	popfd
	ret

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

; gdt:
; Global Descriptor Table

align 32

gdt:
	dq 0					; x86 requires a null descriptor

	; kernel code segment 0x8
	dw 0xFFFF				; limit low
	dw 0					; base low
	db 0					; base middle
	db 10011010b				; access
	db 11001111b				; flags and limit high
	db 0					; base high

	; kernel data segment 0x10
	dw 0xFFFF
	dw 0
	db 0
	db 10010010b
	db 11001111b
	db 0

	; user code segment 0x18
	dw 0xFFFF				; limit low
	dw 0					; base low
	db 0					; base middle
	db 11111010b				; access
	db 11001111b				; flags and limit high
	db 0

	; user data segment 0x20
	dw 0xFFFF
	dw 0
	db 0
	db 11110010b
	db 11001111b
	db 0

	; 16-bit code segment 0x28
	dw 0xFFFF
	dw 0
	db 0
	db 10011010b
	db 10001111b
	db 0

	; 16-bit data segment 0x30
	dw 0xFFFF
	dw 0
	db 0
	db 10010010b
	db 10001111b
	db 0

gdt_tss:
	; tss segment 0x38
	dw 104
	dw 0
	db 0
	db 11101001b
	db 0
	db 0

end_of_gdt:

align 32

gdtr:
	dw end_of_gdt - gdt - 1
	dd gdt

; idt:
; Interrupt Descriptor Table

align 32

idt:
	times 256 dw unhandled_isr, 8, 0x8E00, 0

end_of_idt:

align 32

idtr:
	dw end_of_idt - idt - 1
	dd idt

; ivt:
; Interrupt Vector Table

align 32

ivt:
	dw 0x3FF
	dd 0

