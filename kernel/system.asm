
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

;; Functions:
; enable_a20
; check_a20
; detect_memory
; verify_enough_memory
; go32
; go16
; remap_pic
; init_pit
; init_sse
; delay_execution
; show_detected_hardware

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
; Detects memory using BIOS E820

detect_memory:
	mov eax, 0xE801
	mov cx, 0
	mov dx, 0
	int 0x15
	jc .error

	cmp ah, 0x80
	je .error

	cmp ah, 0x86
	je .error

	cmp cx, 0
	je .use_ax

	mov ax, cx
	mov bx, dx

.use_ax:
	add ax, 1024
	mov [.lomem], ax
	mov [.himem], bx

	call go32

use32

	movzx eax, [.himem]
	mov ebx, 64
	mul ebx
	movzx ebx, [.lomem]
	add eax, ebx
	mov [usable_memory_kb], eax
	mov [total_memory_kb], eax

	mov eax, [usable_memory_kb]
	mov ebx, 1024
	;mov edx, 0
	div ebx
	mov [usable_memory_mb], eax
	mov [total_memory_mb], eax

	cmp dword[usable_memory_mb], 2048
	jge .maximum_size

	mov eax, [usable_memory_kb]
	mov ebx, 1024
	mov edx, 0
	mul ebx
	mov [usable_memory_bytes], eax

	jmp .finish

.maximum_size:
	mov dword[usable_memory_mb], 2048
	mov dword[total_memory_mb], 2048
	mov dword[usable_memory_kb], 2048*1024
	mov dword[total_memory_kb], 2048*1024
	mov dword[usable_memory_bytes], 2048*1024*1024

.finish:
	call go16

use16

	ret

.error:
	mov si, .fail_msg
	call print_string_16

	jmp $

.fail_msg			db "Boot error: BIOS function 0xE801 failed; couldn't detect memory...",0
.map_entries			dd 0
.tmp_size			dd 0
.tmp_size2			dd 0
.lomem				dw 0
.himem				dw 0

usable_memory_bytes		dd 0
usable_memory_bytes2		dd 0
usable_memory_kb		dd 0
usable_memory_mb		dd 0
total_memory_kb			dd 0
total_memory_mb			dd 0

is_paging_enabled		db 0

use16

; verify_enough_memory:
; Verifies there is enough RAM onboard

verify_enough_memory:
	cmp dword[usable_memory_mb], 32
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

	call enable_a20

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
	mov al, 0x20				; map IRQ 0-15 to INT 0x20-0x28
	mov ah, 0x28
	call remap_pic

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

	; restore BIOS configuration of the PIC
	; that is, IRQ 0-7 from INT 8 - 0x0F
	; and IRQ 8-15 from INT 0x70 - 0x77
	mov al, 8
	mov ah, 0x70
	call remap_pic

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
; Remaps vectors on the PIC
; In\	AL = Master PIC offset
; In\	AH = Slave PIC offset
; Out\	Nothing

remap_pic:
	pushfd
	cli

	mov [.master], al
	mov [.slave], ah

	in al, 0x21			; save masks
	mov [.data1], al
	call iowait

	in al, 0xA1
	mov [.data2], al
	call iowait

	mov al, 0x11			; initialize command
	out 0x20, al
	call iowait
	
	mov al, 0x11
	out 0xA0, al
	call iowait
	
	mov al, [.master]
	out 0x21, al
	call iowait

	mov al, [.slave]
	out 0xA1, al
	call iowait

	mov al, 4
	out 0x21, al
	call iowait

	mov al, 2
	out 0xA1, al
	call iowait

	mov al, 1
	out 0x21, al
	call iowait

	mov al, 1
	out 0xA1, al
	call iowait

	mov al, [.data1]
	out 0x21, al
	call iowait

	mov al, [.data2]
	out 0xA1, al
	call iowait

	popfd
	ret

.data1				db 0
.data2				db 0
.master				db 0
.slave				db 0

; iowait:
; Waits for an I/O operation to complete

iowait:
	pusha

	jmp 8:.1

.1:
	nop
	nop
	nop
	nop

	jmp 8:.2

.2:
	nop
	nop
	nop
	nop

	jmp 8:.3

.3:
	popa
	ret

; init_pit:
; Initializes the PIT to 100 Hz

init_pit:
	;mov al, 0x36
	;out 0x43, al

	call iowait

	mov eax, 11931		; 100 Hz
	out 0x40, al

	call iowait

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
	call go16

use16

	mov si, .no_sse_msg
	call print_string_16

	jmp $

.no_sse_msg				db "Boot error: This CPU doesn't support SSE: Streaming SIMD extensions.",0

use32

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

; show_detected_hardware:
; Shows detected hardware in debug messages

show_detected_hardware:
	mov esi, .msg
	call kdebug_print

.check_floppy:
	test word[hardware_bitflags], 1		; floppy disks
	jz .check_fpu

	movzx eax, word[hardware_bitflags]
	shr eax, 6
	and eax, 3
	add eax, 1
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .floppy
	call kdebug_print_noprefix

.check_fpu:
	test word[hardware_bitflags], 2		; x87
	jz .check_mouse

	mov esi, .fpu
	call kdebug_print_noprefix

.check_mouse:
	test word[hardware_bitflags], 4		; PS/2 pointing device
	jz .check_serial

	mov esi, .mouse
	call kdebug_print_noprefix

.check_serial:
	movzx eax, word[hardware_bitflags]
	shr eax, 9
	and eax, 7
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .serial
	call kdebug_print_noprefix

	ret

.msg				db "kernel: detected hardware: ",0
.floppy				db " floppy disks, ",0
.fpu				db "x87 FPU, ",0
.mouse				db "PS/2 pointing device, ",0
.serial				db " serial ports ",10,0

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

	; tss segment 0x38
	dw 104
	dw tss
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

