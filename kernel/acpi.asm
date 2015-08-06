
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/acpi.asm							;;
;; ACPI Driver								;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

acpi_reserved_memory		dd 0x100000		; reserve at least 1 MB for ACPI
rsd_ptr				dd 0
rsdt				dd 0
rsdt_size			dd 0
is_there_acpi			db 0

; init_acpi:
; Initializes ACPI

init_acpi:
	sti

	mov esi, .debug_msg1
	call kdebug_print

	; First, we need to find the RSDP
	mov esi, .rsd_ptr
	mov edi, 0xE0000

.loop:
	pusha
	mov ecx, 8
	rep cmpsb
	je .found_rsdp
	popa
	add edi, 1
	cmp edi, 0xFFFFF
	jge .no_acpi
	jmp .loop

.found_rsdp:
	popa
	mov [rsd_ptr], edi

	mov esi, .debug_msg2
	call kdebug_print

	mov eax, [rsd_ptr]
	call hex_dword_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	mov esi, .debug_msg3
	call kdebug_print

	mov esi, [rsd_ptr]
	add esi, 15
	mov al, byte[esi]
	and eax, 0xFF
	add al, 1
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg4
	call kdebug_print_noprefix

	mov esi, [rsd_ptr]
	add esi, 9
	mov edi, .oemid
	mov ecx, 6
	rep movsb

	mov esi, .oemid
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	; Now, let's verify the checksum
	mov esi, [rsd_ptr]
	mov edi, [rsd_ptr]
	add edi, 20
	mov eax, 0

.rsdp_verify_checksum:
	mov bl, byte[esi]
	add al, bl
	inc esi
	cmp esi, edi
	je .rsdp_checksum_done
	jmp .rsdp_verify_checksum

.rsdp_checksum_done:
	cmp al, 0
	jne .checksum_error

.find_rsdt:
	; Now, we need to find the RSDT
	mov esi, [rsd_ptr]
	add esi, 16
	mov eax, [esi]
	mov [rsdt], eax

	mov esi, .debug_msg5
	call kdebug_print

	mov eax, [rsdt]
	call hex_dword_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	mov eax, [rsdt]
	mov ebx, [rsdt]
	and eax, 0xFFFFF000
	and ebx, 0xFFFFF000
	mov ecx, 4096
	mov edx, 3
	call vmm_map_memory

	mov esi, [rsdt]
	mov eax, 0x15000
	add esi, eax
	mov [rsdt_size], esi

	mov byte[is_there_acpi], 1
	ret

.checksum_error:
	mov esi, .debug_msg6
	call kdebug_print

.no_acpi:
	mov esi, .debug_msg7
	call kdebug_print

	ret

.rsd_ptr			db "RSD PTR "
.rsdt_signature			db "RSDT"
.debug_msg1			db "acpi: initializing ACPI...",10,0
.debug_msg2			db "acpi: RSD PTR found at ",0
.debug_msg3			db "acpi: ACPI revision ",0
.debug_msg4			db ", OEM ID ",0
.debug_msg5			db "acpi: RSDT found at ",0
.debug_msg6			db "acpi: checksum error, ignoring ACPI tables...",10,0
.debug_msg7			db "acpi: system doesn't support ACPI...",10,0
.oemid:				times 7 db 0

; acpi_find_table:
; Finds an ACPI table
; In\	ESI = ACPI table signature
; Out\	EAX = Status (0 - success, 1 - table not found)
; Out\	ESI = Pointer to ACPI table

acpi_find_table:
	mov [.signature], esi
	mov esi, [rsdt]
	add esi, 4
	mov eax, [esi]
	sub eax, 36			; subtract size of ACPI header
	mov ebx, 4
	mov edx, 0
	div ebx
	mov [.rsdt_entries], eax

	mov ecx, 0
	mov esi, [rsdt]
	add esi, 36

.find_table:
	pusha
	mov eax, dword[esi]
	mov ebx, eax
	push ebx
	and eax, 0xFFFFF000
	and ebx, 0xFFFFF000
	mov ecx, 1024
	mov edx, 3
	call vmm_map_memory

	pop ebx
	push ebx
	mov esi, ebx
	mov edi, [.signature]
	mov ecx, 4
	rep cmpsb
	je .found

	pop eax
	and eax, 0xFFFFF000
	mov ecx, 1024
	call vmm_unmap_memory
	popa

	add ecx, 1
	cmp ecx, [.rsdt_entries]
	jge .not_found

	add esi, 4
	jmp .find_table

.found:
	pop eax
	mov [.tmp], esi
	popa

	mov esi, [.tmp]
	sub esi, 4
	mov eax, 0
	ret

.not_found:
	mov eax, 1
	mov esi, 0
	ret

.tmp					dd 0
.rsdt_entries				dd 0
.signature				dd 0

; init_acpi_power:
; Initialize ACPI power management

init_acpi_power:
	cmp byte[is_there_acpi], 1
	jne .no_acpi

	mov esi, .facp
	call acpi_find_table

	cmp eax, 0
	jne .no_fadt

	mov [.fadt], esi

	mov esi, .debug_msg1
	call kdebug_print

	mov eax, [.fadt]
	call hex_dword_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	jmp .verify_checksum

.no_fadt:
	mov esi, .no_fadt_msg
	call kdebug_print

	mov word[acpi_slp_typa], 0xFFFF
	ret

.verify_checksum:
	mov esi, [.fadt]
	mov eax, dword[esi+4]
	mov edi, esi
	add edi, eax

	mov eax, 0

.checksum_loop:
	mov bl, byte[esi]
	add al, bl
	inc esi
	cmp esi, edi
	je .checksum_done
	jmp .checksum_loop

.checksum_done:
	cmp al, 0
	jne .checksum_error

	mov esi, [.fadt]
	mov edi, acpi_fadt
	mov ecx, end_of_acpi_fadt - acpi_fadt
	rep movsb

	cmp byte[acpi_fadt.acpi_enable], 0		; is ACPI enabled?
	je .already_enabled

	cmp dword[acpi_fadt.smi_command_port], 0
	je .already_enabled

	mov esi, .debug_msg3
	call kdebug_print

	; If we're here, then ACPI is not enabled
	mov edx, [acpi_fadt.smi_command_port]
	mov al, [acpi_fadt.acpi_enable]
	out dx, al					; enable ACPI

	mov eax, 3					; wait 3 seconds for the hardware to change modes
	call delay_execution

	jmp .enabled

.already_enabled:
	mov esi, .debug_msg2
	call kdebug_print

.enabled:

.find_s5:
	mov esi, .debug_msg4
	call kdebug_print

	mov eax, [acpi_fadt.dsdt]
	call hex_dword_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	; identity-page the DSDT
	mov eax, [acpi_fadt.dsdt]
	mov ebx, [acpi_fadt.dsdt]
	and eax, 0xFFFFF000
	and ebx, 0xFFFFF000
	mov ecx, 512
	mov edx, 3
	call vmm_map_memory

	; Now, let's parse the DSDT and find the \_S5 object
	mov esi, .s5_signature
	mov edi, [acpi_fadt.dsdt]

.find_s5_loop:
	pusha
	mov ecx, 4
	rep cmpsb
	je .found_s5
	popa

	add edi, 1
	cmp edi, [rsdt_size]
	jge .no_s5
	jmp .find_s5_loop

.found_s5:
	popa
	mov [acpi_s5], edi
	mov edi, [acpi_s5]
	cmp byte[edi+4], 0x12
	jne .bad_s5

	cmp byte[edi+6], 4
	jne .bad_s5

	;ov esi, [acpi_s5]
	;add esi, 7
	;mov ax, word[esi]
	;mov [acpi_slp_typa], ax
	;mov ax, word[esi+2]
	;mov [acpi_slp_typb], ax
	mov edi, [acpi_s5]

	mov dl, byte[edi+6]

	mov esi, [acpi_s5]
	add esi, 7
	mov ecx, 0
	cmp byte[esi], 0
	jz .next

	cmp byte[esi], 0xA
	jnz .bad_s5

	add esi, 1
	mov cl, [esi]

.next:
	add esi, 1
	cmp dl, 2
	jb .next2

	cmp byte[esi], 0
	jz .next2

	cmp byte[esi], 0xA
	jnz .bad_s5

	add esi, 1
	mov ch, [esi]

.next2:
	mov [acpi_slp_typa], cx

	mov ax, 0
	or ax, 0x2000					; set bit 13 (SLP_EN)
	mov [acpi_slp_en], ax

	mov esi, .irq_msg
	call kdebug_print

	movzx eax, [acpi_fadt.sci_interrupt]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .int_msg
	call kdebug_print_noprefix

	mov ax, [acpi_fadt.sci_interrupt]
	add ax, 32
	call hex_byte_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	mov ax, [acpi_fadt.sci_interrupt]
	add ax, 32					; we mapped IRQ 0-15 to INT 32-47
	mov ebp, acpi_irq				; install the IRQ handler
	call install_isr

	ret

.checksum_error:
	mov esi, .debug_msg5
	call kdebug_print

	mov word[acpi_slp_typa], 0xFFFF
	ret

.bad_s5:
	mov word[acpi_slp_typa], 0xFFFF
	ret

.no_s5:
	mov word[acpi_slp_typa], 0xFFFF
	ret

.no_acpi:
	mov word[acpi_slp_typa], 0xFFFF
	ret

.facp				db "FACP"
.fadt				dd 0
.s5_signature			db "_S5_",0
.debug_msg1			db "acpi: FADT found at ",0
.debug_msg2			db "acpi: system is already in ACPI mode.",10,0
.debug_msg3			db "acpi: system is not in ACPI mode, enabling ACPI...",10,0
.debug_msg4			db "acpi: DSDT found at ",0
.irq_msg			db "acpi: using IRQ ",0
.debug_msg5			db "acpi: checksum error...",10,0
.no_fadt_msg			db "acpi: FADT not found.",10,0

.int_msg			db ", INT ",0

acpi_s5				dd 0
acpi_slp_typa			dw 0
acpi_slp_typb			dw 0
acpi_slp_en			dw 0

; acpi_shutdown:
; Shuts down the system using ACPI

acpi_shutdown:
	mov esi, .debug
	call kdebug_print

	cmp word[acpi_slp_typa], 0xFFFF
	je .fail

	; First, we need to write the value SLP_TYPa into the PM1a_control_block
	mov cx, [acpi_slp_typa]
	and cx, 0x707
	shl cx, 2
	or cx, 0x2020
	mov edx, [acpi_fadt.pm1a_control_block]
	in ax, dx
	and ax, 0x203
	or ah, cl
	out dx, ax

	; If the system is not powered off yet, it may be one of two possibilities:
	; - ACPI shutdown somehow failed.
	; - We need to do PM1b_control_block too.
	; Luckily for us, ACPI says that if PM1b_control_block is not zero, we need to write the value to it too.
	; This means that if PM1b_control_block is zero and we're still not powered off, then shutdown failed.

	mov edx, [acpi_fadt.pm1b_control_block]
	cmp edx, 0
	je .fail
	in ax, dx
	and ax, 0x203
	or ah, ch
	out dx, ax

.fail:
	mov esi, .fail_msg
	call kdebug_print

	ret

.a				dw 0
.b				dw 0
.debug				db "acpi: attempting ACPI shutdown...",10,0
.fail_msg			db "acpi: failed...",10,0

; acpi_reset:
; Resets the system using ACPI

acpi_reset:
	mov esi, .debug_msg
	call kdebug_print

	cli

	; According to Linux, the ACPI reset register exists only in version 2+ of the FADT
	cmp byte[acpi_fadt.revision], 2
	jl .fail

	mov eax, [acpi_fadt.flags]
	test eax, 0x400						; is the reset register supported?
	jz .fail

	; The ACPI reset can only be done via memory mapped I/O, the I/O bus, or the PCI bus.
	cmp byte[acpi_reset_register.address_space], 0		; memory mapped I/O
	je .memory

	cmp byte[acpi_reset_register.address_space], 1		; I/O
	je .io

	; TO-DO: Implement ACPI PCI reset
	;cmp byte[acpi_reset_register.address_space], 2		; PCI
	;je .pci

	jmp .fail

.memory:
	mov esi, .debug_msg3
	call kdebug_print

	cmp dword[acpi_reset_register.address], 0
	je .fail

	cmp byte[acpi_reset_register.access_size], 0
	je .fail

	mov edi, dword[acpi_reset_register.address]
	movzx eax, byte[acpi_reset_value]

	cmp byte[acpi_reset_register.access_size], 1
	je .memory_byte

	cmp byte[acpi_reset_register.access_size], 2
	je .memory_word

	cmp byte[acpi_reset_register.access_size], 3
	je .memory_dword

	jmp .fail

.memory_byte:
	stosb
	jmp .fail

.memory_word:
	stosw
	jmp .fail

.memory_dword:
	stosd
	jmp .fail

.io:
	mov esi, .debug_msg4
	call kdebug_print

	mov edx, dword[acpi_reset_register.address]
	movzx eax, byte[acpi_reset_value]

	cmp byte[acpi_reset_register.access_size], 1
	je .io_byte

	cmp byte[acpi_reset_register.access_size], 2
	je .io_word

	cmp byte[acpi_reset_register.access_size], 3
	je .io_dword

	jmp .fail

.io_byte:
	out dx, al
	jmp .fail

.io_word:
	out dx, ax
	jmp .fail

.io_dword:
	out dx, eax

.fail:
	mov esi, .debug_msg2
	call kdebug_print

	ret

.debug_msg			db "acpi: attempting ACPI reset...",10,0
.debug_msg2			db "acpi: failed...",10,0
.debug_msg3			db "acpi: memory mapped reset...",10,0
.debug_msg4			db "acpi: I/O bus reset...",10,0
;.debug_msg5			db "acpi: PCI bus reset...",10,0

; acpi_irq:
; ACPI IRQ handler

acpi_irq:
	pusha
	push ds
	push es
	push fs
	push gs

	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	mov esi, .debug_msg
	call kdebug_print

	cmp word[acpi_fadt.sci_interrupt], 8
	jge .slave

	mov al, 0x20
	out 0x20, al

	pop gs
	pop fs
	pop es
	pop ds
	popa
	iret

.slave:
	mov al, 0x20
	out 0xA0, al
	out 0x20, al

	pop gs
	pop fs
	pop es
	pop ds
	popa
	iret

.debug_msg			db "acpi: ACPI IRQ received.",10,0

align 32

acpi_fadt:
	; ACPI SDT header
	.signature		rb 4
	.length			rd 1
	.revision		rb 1
	.checksum		rb 1
	.oemid			rb 6
	.oem_table_id		rb 8
	.oem_revision		rd 1
	.creator_id		rd 1
	.creator_revision	rd 1

	; FADT table itself
	.firmware_control	rd 1
	.dsdt			rd 1
	.reserved		rb 1

	.preffered_profile	rb 1
	.sci_interrupt		rw 1
	.smi_command_port	rd 1
	.acpi_enable		rb 1
	.acpi_disable		rb 1
	.s4bios_req		rb 1
	.pstate_control		rb 1
	.pm1a_event_block	rd 1
	.pm1b_event_block	rd 1
	.pm1a_control_block	rd 1
	.pm1b_control_block	rd 1
	.pm2_control_block	rd 1
	.pm_timer_block		rd 1
	.gpe0_block		rd 1
	.gpe1_block		rd 1
	.pm1_event_length	rb 1
	.pm1_control_length	rb 1
	.pm2_control_length	rb 1
	.pm_timer_length	rb 1
	.gpe0_length		rb 1
	.gpe1_length		rb 1
	.gpe1_base		rb 1
	.cstate_control		rb 1
	.worst_c2_latency	rw 1
	.worst_c3_latency	rw 1
	.flush_size		rw 1
	.flush_stride		rw 1
	.duty_offset		rb 1
	.duty_width		rb 1
	.day_alarm		rb 1
	.month_alarm		rb 1
	.century		rb 1

	.boot_arch_flags	rw 1
	.reserved2		rb 1
	.flags			rd 1

acpi_reset_register:
	.address_space		rb 1
	.bit_width		rb 1
	.bit_offset		rb 1
	.access_size		rb 1
	.address		rq 1

acpi_reset_value		rb 1

end_of_acpi_fadt:

acpi_fadt_size			= end_of_acpi_fadt - acpi_fadt



