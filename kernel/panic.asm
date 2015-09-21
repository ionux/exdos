
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

;; Functions:
; init_exceptions
; draw_panic_screen

use32

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

; draw_panic_screen:
; Draws the panic screen
; In\	ESI = Message
; Out\	Nothing

draw_panic_screen:
	mov [ss:.string], esi

	push eax
	mov eax, [ss:esp+4]
	mov [ss:.return], eax
	mov eax, [ss:esp+8]
	mov [ss:dump_registers.cs], ax
	pop eax

	mov [ss:dump_registers.ds], ds
	mov [ss:dump_registers.es], es
	mov [ss:dump_registers.fs], fs
	mov [ss:dump_registers.gs], gs

	mov ax, 0x10			; fix segment registers
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	pusha
	mov esi, .debug_string_prefix
	call kdebug_print
	mov esi, [.string]
	call kdebug_print_noprefix
	mov esi, .debug_string_suffix
	call kdebug_print_noprefix
	mov eax, [.return]
	call hex_dword_to_string
	call kdebug_print_noprefix
	mov esi, _crlf
	call kdebug_print_noprefix
	popa
	call dump_registers

	call hide_text_cursor
	call hide_mouse_cursor

	mov ebx, 0
	mov cx, 0
	mov dx, 0
	mov esi, [screen.width]
	mov edi, [screen.height]
	call alpha_fill_rect
	mov ebx, 0
	mov cx, 0
	mov dx, 0
	mov esi, [screen.width]
	mov edi, [screen.height]
	call alpha_fill_rect

	call get_screen_center
	mov dx, cx
	mov cx, bx
	and edx, 0xFFFF
	and ecx, 0xFFFF
	sub edx, 56
	sub ecx, 408/2
	mov [.x], ecx
	mov [.y], edx
	mov esi, 408
	mov edi, 112
	mov ebx, 0x80
	call alpha_fill_rect

	mov esi, .panic_text1
	mov ebx, [.x]
	mov ecx, [.y]
	add ebx, 17
	add ecx, 33
	mov edx, 0
	call print_string_transparent

	mov esi, .panic_text1
	mov ebx, [.x]
	mov ecx, [.y]
	add ebx, 16
	add ecx, 32
	mov edx, 0xEFEFEF
	call print_string_transparent

	mov esi, [.string]
	mov ebx, [.x]
	mov ecx, [.y]
	add ebx, 17
	add ecx, 65
	mov edx, 0
	call print_string_transparent

	mov esi, [.string]
	mov ebx, [.x]
	mov ecx, [.y]
	add ebx, 16
	add ecx, 64
	mov edx, 0xEFEFEF
	call print_string_transparent

	call kdebug_dump
	jc .error

	mov esi, .panic_text2
	mov ebx, [.x]
	mov ecx, [.y]
	add ebx, 17
	add ecx, 49
	mov edx, 0
	call print_string_transparent

	mov esi, .panic_text2
	mov ebx, [.x]
	mov ecx, [.y]
	add ebx, 16
	add ecx, 48
	mov edx, 0xEFEFEF
	call print_string_transparent

	jmp .done

.error:
	mov esi, .panic_text3
	mov ebx, [.x]
	mov ecx, [.y]
	add ebx, 17
	add ecx, 49
	mov edx, 0
	call print_string_transparent

	mov esi, .panic_text3
	mov ebx, [.x]
	mov ecx, [.y]
	add ebx, 16
	add ecx, 48
	mov edx, 0xEFEFEF
	call print_string_transparent

.done:
	call get_char_wait
	call reboot

.x				dd 0
.y				dd 0
.return				dd 0
.string				dd 0
.debug_string_prefix		db "kernel: ",0
.debug_string_suffix		db " exception occured at EIP 0x",0
.panic_text1			db "An unrecoverable error has occured.",0
.panic_text2			db "Details have been saved in the kernel log file.",0
.panic_text3			db "Failed to save details of the error...",0

;;
;; EXCEPTION HANDLERS
;;

divide_error:
	mov esi, divide_error_msg
	jmp draw_panic_screen

debug_error:
	mov esi, debug_error_msg
	jmp draw_panic_screen

nmi_error:
	mov esi, nmi_error_msg
	jmp draw_panic_screen

breakpoint_error:
	mov esi, breakpoint_error_msg
	jmp draw_panic_screen

overflow_error:
	mov esi, overflow_error_msg
	jmp draw_panic_screen

bound_error:
	mov esi, bound_error_msg
	jmp draw_panic_screen

opcode_error:
	mov esi, opcode_error_msg
	jmp draw_panic_screen

device_error:
	mov esi, device_error_msg
	jmp draw_panic_screen

double_fault_error:
	add esp, 4
	mov esi, double_fault_msg
	jmp draw_panic_screen

coprocessor_segment_error:
	mov esi, coprocessor_segment_error_msg
	jmp draw_panic_screen

tss_error:
	add esp, 4
	mov esi, tss_error_msg
	jmp draw_panic_screen

segment_error:
	add esp, 4
	mov esi, segment_error_msg
	jmp draw_panic_screen

stack_error:
	add esp, 4
	mov esi, stack_error_msg
	jmp draw_panic_screen

gpf_error:
	add esp, 4

	cmp byte[ss:v8086_running], 1			; if a v8086 task is running --
	je v8086_monitor				; -- it's likely the GPF really isn't an error

	mov esi, gpf_error_msg
	jmp draw_panic_screen

page_error:
	add esp, 4
	mov esi, page_error_msg
	jmp draw_panic_screen

reserved_error:
	mov esi, reserved_error_msg
	jmp draw_panic_screen

fpu_error:
	mov esi, fpu_error_msg
	jmp draw_panic_screen

alignment_error:
	add esp, 4
	mov esi, alignment_error_msg
	jmp draw_panic_screen

machine_error:
	mov esi, machine_error_msg
	jmp draw_panic_screen

simd_error:
	add esp, 4
	mov esi, simd_error_msg
	jmp draw_panic_screen

virtualization_error:
	mov esi, virtualization_error_msg
	jmp draw_panic_screen

security_error:
	add esp, 4
	mov esi, security_error_msg
	jmp draw_panic_screen

;; 
;; ERROR MESSAGES
;;

divide_error_msg			db "Divide error",0
debug_error_msg				db "Debug error",0
nmi_error_msg				db "Non-maskable interrupt",0
breakpoint_error_msg			db "Breakpoint",0
overflow_error_msg			db "Overflow error",0
bound_error_msg				db "BOUND error",0
opcode_error_msg			db "Invalid opcode error",0
device_error_msg			db "Device not present",0
double_fault_msg			db "Double fault",0
coprocessor_segment_error_msg		db "Coprocessor segment error",0
tss_error_msg				db "Corrupt TSS",0
segment_error_msg			db "Stack segment error",0
stack_error_msg				db "Stack error",0
gpf_error_msg				db "General protection fault",0
page_error_msg				db "Page fault",0
reserved_error_msg			db "Reserved exception",0
fpu_error_msg				db "FPU exception",0
alignment_error_msg			db "Alignment check",0
machine_error_msg			db "Machine check",0
simd_error_msg				db "SIMD floating point exception",0
virtualization_error_msg		db "Virtualization error",0
security_error_msg			db "Security error",0
out_of_memory_msg			db "Out of memory",0

