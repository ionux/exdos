
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/panic.asm							;;
;; Kernel Panic (aka BSoD)						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

exception_running			db 0

; draw_panic_screen:
; Draws the panic interface
; In\	ESI = Error type
; Out\	Nothing

draw_panic_screen:
	mov [.str], esi

	mov ax, 0x10
	mov ss, ax
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	mov ax, 640
	mov bx, 480
	mov cl, 32
	call set_vesa_mode

	cmp eax, 0
	jne .try_24bpp

	jmp .vesa_done

.try_24bpp:
	mov ax, 640
	mov bx, 480
	mov cl, 24
	call set_vesa_mode

.vesa_done:
	mov ebx, 0x7F
	call clear_screen

	mov esi, .panic_title
	mov bx, 288
	mov cx, 160
	mov eax, 0xC0C0C0
	mov edx, 0x7F
	call print_string_graphics

	mov esi, .hint
	mov bx, 32
	mov cx, 192
	mov edx, 0xFFFFFF
	call print_string_transparent

	mov esi, .error_type
	mov bx, 32
	mov cx, 256
	mov edx, 0xFFFFFF
	call print_string_transparent

	mov esi, [.str]
	mov bx, 128
	mov cx, 256
	mov edx, 0xFFFFFF
	call print_string_transparent

	mov esi, .reboot_msg
	mov bx, 208
	mov cx, 336
	mov edx, 0xFFFFFF
	call print_string_transparent

	cmp byte[.custom_exception], 1
	je .custom

	call get_char_wait
	call reboot

.custom:
	ret

.custom_exception		db 0
.str				dd 0
.panic_title			db " ExDOS ",0
.hint				db "An internal kernel error has occured and your PC must be rebooted.",13,10
				db "Any information you were working on may be lost. We're sorry for any",13,10
				db "inconvenience.",0
.error_type			db "Error type: ",0
.reboot_msg			db "Press any key to reboot.",0

; init_exceptions:
; Installs exception handlers into the IDT

init_exceptions:
	mov al, 0
	mov ebp, divide_error
	call install_isr

	mov al, 1
	mov ebp, debug_error
	call install_isr

	mov al, 2
	mov ebp, nmi_error
	call install_isr

	mov al, 3
	mov ebp, breakpoint_error
	call install_isr

	mov al, 4
	mov ebp, overflow_error
	call install_isr

	mov al, 5
	mov ebp, bound_error
	call install_isr

	mov al, 6
	mov ebp, opcode_error
	call install_isr

	mov al, 7
	mov ebp, device_error
	call install_isr

	mov al, 8
	mov ebp, double_fault_error
	call install_isr

	mov al, 9
	mov ebp, coprocessor_segment_error
	call install_isr

	mov al, 10
	mov ebp, tss_error
	call install_isr

	mov al, 11
	mov ebp, segment_error
	call install_isr

	mov al, 12
	mov ebp, stack_error
	call install_isr

	mov al, 13
	mov ebp, gpf_error
	call install_isr

	mov al, 14
	mov ebp, page_error
	call install_isr

	mov al, 15
	mov ebp, reserved_error
	call install_isr

	mov al, 16
	mov ebp, fpu_error
	call install_isr

	mov al, 17
	mov ebp, alignment_error
	call install_isr

	mov al, 18
	mov ebp, machine_error
	call install_isr

	mov al, 19
	mov ebp, simd_error
	call install_isr

	mov al, 20
	mov ebp, virtualization_error
	call install_isr

	mov al, 30
	mov ebp, security_error
	call install_isr

	ret

;;
;; EXCEPTION HANDLERS
;;

divide_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Divide error.",0

debug_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Debug interrupt.",0

nmi_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Non-maskable interrupt.",0

breakpoint_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Breakpoint.",0

overflow_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Overflow error.",0

bound_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "BOUND error.",0

opcode_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Invalid opcode error.",0

device_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Device not available.",0

double_fault_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Double fault.",0

coprocessor_segment_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Coprocessor segment overrun.",0

tss_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Invalid TSS.",0

segment_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Requested segment not present.",0

stack_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Stack segment fault.",0

gpf_error:
	pop ebp				; get rid of error code

	cmp byte[ss:v8086_running], 1
	je v8086_gpf_handler		; if we're running a v8086 task, give control to the v8086 monitor

	pop ebp
	push ebp
	mov [.return], ebp
	cmp word[ebp], 0x5FCD		; INT 0x5F (user API)
	je .api

	;cmp word[ebp], 0x6FCD		; INT 0x6F (driver API)
	;je .driver

	mov esi, .msg
	call draw_panic_screen

.msg				db "General protection fault.",0

.api:
	mov bp, 0x10
	mov ds, bp
	mov es, bp
	mov fs, bp
	mov gs, bp

	jmp os_api

.driver:
	mov bp, 0x10
	mov ds, bp
	mov es, bp
	mov fs, bp
	mov gs, bp

	jmp driver_api

.return				dd 0

page_error:
	mov byte[draw_panic_screen.custom_exception], 1
	mov esi, .msg
	call draw_panic_screen

	mov byte[x_cur], 4
	mov byte[y_cur], 17

	mov esi, .error_info
	mov ecx, 0x7F
	mov edx, 0xFFFFFF
	call print_string_graphics_cursor

	pop eax
	mov [.error_code], eax

.parse_error_code:
	mov eax, [.error_code]
	test eax, 4
	jz .print_kernel

	mov esi, .user
	mov ecx, 0x7F
	mov edx, 0xFFFFFF
	call print_string_graphics_cursor

	jmp .check_read_write

.print_kernel:
	mov esi, .kernel
	mov ecx, 0x7F
	mov edx, 0xFFFFFF
	call print_string_graphics_cursor

.check_read_write:
	mov eax, [.error_code]
	test eax, 2
	jz .print_read

	mov esi, .write
	mov ecx, 0x7F
	mov edx, 0xFFFFFF
	call print_string_graphics_cursor

	jmp .check_error_type

.print_read:
	mov esi, .read
	mov ecx, 0x7F
	mov edx, 0xFFFFFF
	call print_string_graphics_cursor

.check_error_type:
	mov eax, [.error_code]
	test eax, 1
	jz .print_non_present

	mov esi, .fault
	mov ecx, 0x7F
	mov edx, 0xFFFFFF
	call print_string_graphics_cursor

	jmp .done

.print_non_present:
	mov esi, .non_present
	mov ecx, 0x7F
	mov edx, 0xFFFFFF
	call print_string_graphics_cursor

.done:
	mov byte[x_cur], 4
	add byte[y_cur], 1

	mov esi, .virtual_address
	mov ecx, 0x7F
	mov edx, 0xFFFFFF
	call print_string_graphics_cursor

	mov eax, cr2
	call hex_dword_to_string
	mov ecx, 0x7F
	mov edx, 0xFFFFFF
	call print_string_graphics_cursor

	call get_char_wait
	call reboot

.msg				db "Page fault.",0
.error_info			db "Details: ",0
.kernel				db "Kernel ",0
.user				db "User ",0
.read				db "tried to read ",0
.write				db "tried to write to ",0
.non_present			db "a non-present page.",0
.fault				db "a page and caused a protection fault.",0
.virtual_address		db "Virtual address: ",0
.error_code			dd 0

reserved_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Reserved error.",0

fpu_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "FPU exception.",0

alignment_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Alignment check.",0

machine_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Machine check.",0

simd_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "SIMD floating point exception.",0

virtualization_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Virtualization exception.",0

security_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Security exception.",0

stack_overflow_error:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Stack overflow.",0

out_of_memory:
	mov esi, .msg
	call draw_panic_screen

.msg				db "Out of memory, no usable memory was found.",0

