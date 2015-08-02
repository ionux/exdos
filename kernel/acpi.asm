
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

	ret

.checksum_error:
	mov ebx, 0x333333
	mov cx, 0
	mov dx, 218
	mov esi, 800
	mov edi, 160
	call alpha_fill_rect

	mov esi, .checksum_error_msg
	mov bx, 32
	mov cx, 250
	mov edx, 0xDEDEDE
	call print_string_transparent

	mov esi, _boot_error_common
	mov bx, 32
	mov cx, 340
	mov edx, 0xDEDEDE
	call print_string_transparent

	sti
	jmp $

.no_acpi:
	mov ebx, 0x333333
	mov cx, 0
	mov dx, 218
	mov esi, 800
	mov edi, 160
	call alpha_fill_rect

	mov esi, .no_acpi_msg
	mov bx, 32
	mov cx, 250
	mov edx, 0xDEDEDE
	call print_string_transparent

	mov esi, _boot_error_common
	mov bx, 32
	mov cx, 340
	mov edx, 0xDEDEDE
	call print_string_transparent

	sti
	jmp $

.rsd_ptr			db "RSD PTR "
.rsdt_signature			db "RSDT"
.debug_msg1			db "acpi: initializing ACPI...",10,0
.debug_msg2			db "acpi: RSD PTR found at ",0
.debug_msg3			db "acpi: ACPI revision ",0
.debug_msg4			db ", OEM ID ",0
.debug_msg5			db "acpi: RSDT found at ",0
.checksum_error_msg		db "Boot error: ACPI checksum error.",0
.no_acpi_msg			db "Boot error: This PC doesn't support ACPI.",0
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
	mov ebx, 0x333333
	mov cx, 0
	mov dx, 218
	mov esi, 800
	mov edi, 160
	call alpha_fill_rect

	mov esi, .no_fadt_msg
	mov bx, 32
	mov cx, 250
	mov edx, 0xDEDEDE
	call print_string_transparent

	mov esi, _boot_error_common
	mov bx, 32
	mov cx, 340
	mov edx, 0xDEDEDE
	call print_string_transparent

	sti
	jmp $

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
	mov ecx, acpi_fadt_size
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
	mov esi, [acpi_s5]
	add esi, 7
	mov ax, word[esi]
	mov [acpi_slp_typa], ax
	mov ax, word[esi+2]
	mov [acpi_slp_typb], ax

	mov ax, 0
	or ax, 0x2000					; set bit 13 (SLP_EN)
	mov [acpi_slp_en], ax

	ret

.checksum_error:
	mov ebx, 0x333333
	mov cx, 0
	mov dx, 218
	mov esi, 800
	mov edi, 160
	call alpha_fill_rect

	mov esi, .checksum_error_msg
	mov bx, 32
	mov cx, 250
	mov edx, 0xDEDEDE
	call print_string_transparent

	mov esi, _boot_error_common
	mov bx, 32
	mov cx, 340
	mov edx, 0xDEDEDE
	call print_string_transparent

	sti
	jmp $

.no_s5:
	mov ebx, 0x333333
	mov cx, 0
	mov dx, 218
	mov esi, 800
	mov edi, 160
	call alpha_fill_rect

	mov esi, .no_s5_msg
	mov bx, 32
	mov cx, 250
	mov edx, 0xDEDEDE
	call print_string_transparent

	mov esi, _boot_error_common
	mov bx, 32
	mov cx, 340
	mov edx, 0xDEDEDE
	call print_string_transparent

	sti
	jmp $

.facp				db "FACP"
.fadt				dd 0
.no_fadt_msg			db "Boot error: ACPI FADT table not found.",0
.checksum_error_msg		db "Boot error: ACPI FADT checksum error.",0
.no_s5_msg			db "Boot error: ACPI \_S5 object not found.",0
.s5_signature			db "_S5_"
.debug_msg1			db "acpi: FADT found at ",0
.debug_msg2			db "acpi: system is already in ACPI mode.",10,0
.debug_msg3			db "acpi: system is not in ACPI mode, enabling ACPI...",10,0
.debug_msg4			db "acpi: DSDT found at ",0

acpi_s5				dd 0
acpi_slp_typa			dw 0
acpi_slp_typb			dw 0
acpi_slp_en			dw 0

; acpi_shutdown:
; Shuts down the system using ACPI

acpi_shutdown:
	cli

	mov esi, .debug
	call kdebug_print

	mov ax, [acpi_slp_en]
	mov bx, [acpi_slp_typa]
	or ax, bx
	mov [.a], ax

	mov ax, [acpi_slp_en]
	mov bx, [acpi_slp_typb]
	or ax, bx
	mov [.b], ax

	mov edx, [acpi_fadt.pm1a_control_block]
	mov ax, [.a]
	out dx, ax

	cmp dword[acpi_fadt.pm1b_control_block], 0
	je .fail

	mov edx, [acpi_fadt.pm1b_control_block]
	mov ax, [.b]
	out dx, ax

.fail:
	mov esi, .fail_msg
	call kdebug_print

	ret

.a				dw 0
.b				dw 0
.debug				db "acpi: entering sleep state S5...",10,0
.fail_msg			db "acpi: failed.",10,0

; acpi_reset:
; Resets the system using ACPI

acpi_reset:
	; According to Linux, the ACPI reset register exists only in version 2+ of the FADT

.fail:
	ret

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

	.boot_arch_flags	rb 1

	.reserved2		rw 1
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



