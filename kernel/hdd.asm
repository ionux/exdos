
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/hdd.asm							;;
;; Hard disk "driver"							;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Functions:
; init_hdd
; init_edd_info
; hdd_read_sectors
; hdd_write_sectors
; hdd_get_info

use32

align 32

dap:
	.size			db 0x10
	.reserved		db 0
	.sectors		dw 0
	.offset			dw 0
	.segment		dw 0
	.lba			dd 0
				dd 0

diskstat:
	.read			dd 0
	.write			dd 0

disk_size_sectors		dd 0
disk_size_kb			dd 0
disk_size_mb			dd 0

; init_hdd:
; Initializes the hard disk

init_hdd:
	mov esi, .debug_msg1
	call kdebug_print

	mov al, [bootdisk]
	call hex_byte_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	call go16

use16

	mov ax, 0
	mov dl, [bootdisk]
	int 0x13
	jc .fail

	mov ah, 0x15
	mov dl, [bootdisk]
	int 0x13
	jc .fail

	movzx eax, cx
	shl eax, 16
	mov ax, dx
	mov [disk_size_sectors], eax

	mov ah, 0x41
	mov bx, 0x55AA
	mov dl, [bootdisk]
	int 0x13
	jc .no_edd

	mov [edd_version], ah

	call go32

use32

	mov eax, [disk_size_sectors]
	mov ebx, 2
	mov edx, 0
	div ebx
	mov [disk_size_kb], eax

	mov ebx, 1024
	mov edx, 0
	div ebx

	mov [disk_size_mb], eax

	mov esi, .debug_msg2
	call kdebug_print

	mov eax, [disk_size_mb]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg3
	call kdebug_print_noprefix

	mov esi, .debug_msg4
	call kdebug_print

	movzx eax, [edd_version]
	call bcd_to_int
	and eax, 0xFF
	call int_to_string
	push esi

	mov al, [esi]
	mov byte[.tmp], al

	mov esi, .tmp
	call kdebug_print_noprefix

	mov esi, .debug_msg5
	call kdebug_print_noprefix

	pop esi
	mov al, [esi+1]
	mov byte[.tmp], al

	mov esi, .tmp
	call kdebug_print_noprefix

	mov esi, .debug_msg6
	call kdebug_print_noprefix

	mov esi, .msg
	mov ecx, 0xC0C0C0
	mov edx, 0
	call print_string_graphics_cursor

	ret

use16

.fail:
	call go32

use32

	mov esi, .fail_msg
	jmp draw_boot_error

use16

.no_edd:
	call go32

use32

	mov esi, .no_edd_msg
	jmp draw_boot_error

.msg				db "Initialized hard disk.",13,10,0
.fail_msg			db "Failed to access the boot drive: hard disk failure.",0
.debug_msg1			db "hdd: BIOS boot drive number is 0x",0
.debug_msg2			db "hdd: disk size is ",0
.debug_msg3			db " MB.",10,0
.debug_msg4			db "hdd: EDD version ",0
.debug_msg5			db ".",0
.debug_msg6			db " present.",10,0
.no_edd_msg			db "Boot drive doesn't support EDD extensions.",0
.tmp:				times 2 db 0

edd_version			db 0

; init_edd_info:
; Gets hard disk information from EDD BIOS

init_edd_info:
	call go16

use16

	mov al, [edd_version]
	shr al, 4

	cmp al, 1			; EDD version 1
	je .1

	cmp al, 2
	je .2

	cmp al, 3
	je .3

	jmp init_hdd.no_edd

.1:
	mov word[edd_drive_params.size], 0x1A
	jmp .work

.2:
	mov word[edd_drive_params.size], 0x1E
	jmp .work

.3:
	mov word[edd_drive_params.size], 0x42

.work:
	mov ah, 0x48			; get EDD parameters
	mov dl, [bootdisk]
	mov si, edd_drive_params
	int 0x13
	jc init_hdd.no_edd

	call go32

use32

	mov esi, .debug_msg1
	call kdebug_print

	mov eax, [edd_drive_params.cylinders]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg2
	call kdebug_print_noprefix

	mov eax, [edd_drive_params.heads]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg2
	call kdebug_print_noprefix

	mov eax, [edd_drive_params.sectors_per_track]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	cmp word[edd_drive_params], 0x30
	jl .quit

	mov esi, .debug_msg3
	call kdebug_print

	mov esi, edd_drive_params.host_bus
	call kdebug_print_noprefix

	mov esi, .debug_msg4
	call kdebug_print_noprefix

	mov esi, edd_drive_params.interface_type
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

.quit:
	mov esi, .msg
	mov ecx, 0xC0C0C0
	mov edx, 0
	call print_string_graphics_cursor

	ret

.debug_msg1				db "hdd: C/H/S ",0
.debug_msg2				db "/",0
.debug_msg3				db "hdd: host bus is ",0
.debug_msg4				db ", interface type is ",0
.msg					db "Detected EDD BIOS.",13,10,0

; edd_drive_params:
; EDD drive parameters

edd_drive_params:
	; EDD 1.0
	.size				dw 0
	.information_flags		dw 0
	.cylinders			dd 0
	.heads				dd 0
	.sectors_per_track		dd 0
	.total_sectors			dq 0
	.bytes_per_sector		dw 0

	; EDD 2.x
	.edd_configuration_params	dd 0

	; EDD 3.0
	.signature			dw 0
	.device_path_info		db 0
	.reserved:			times 3 db 0
	.host_bus:			times 4 db 0
	.interface_type:		times 8 db 0
	.interface_path:		times 8 db 0
	.device_path:			times 8 db 0
	.reserved2			db 0
	.checksum			db 0

; hdd_read_sectors:
; Reads a series of sectors from the hard disk
; In\	EAX = LBA sector
; In\	EBX = Number of sectors to read
; In\	EDI = Buffer to read sectors
; Out\	Carry clear on success
; Out\	AH = Error code on failure

hdd_read_sectors:
	or ebx, 1			; Force EBX to be an odd number
	mov [.buffer], edi
	mov [.lba], eax
	add ebx, 1
	mov [.sectors], ebx
	add eax, ebx
	mov [.max_lba], eax
	mov dword[.copy], 0

	call go16

use16

.read:
	;mov ax, 0
	;mov dl, [bootdisk]
	;int 0x13
	;jc .fail

	mov word[dap.segment], 0x4000
	mov word[dap.offset], 0
	mov eax, [.lba]
	mov dword[dap.lba], eax
	mov ebx, [.sectors]
	cmp ebx, 127
	jg .big
	mov word[dap.sectors], bx

	mov byte[dap.size], 0x10
	mov byte[dap.reserved], 0
	mov dword[dap.lba+4], 0

	mov ah, 0x42
	mov dl, [bootdisk]
	mov si, dap
	int 0x13
	jc .fail

	movzx ebx, word[dap.sectors]
	add dword[diskstat.read], ebx

	jmp .done

.big:
	mov word[dap.sectors], 127

	mov byte[dap.size], 0x10
	mov byte[dap.reserved], 0
	mov dword[dap.lba+4], 0

	mov ah, 0x42
	mov dl, [bootdisk]
	mov si, dap
	int 0x13
	jc .fail

	add dword[diskstat.read], 127
	add dword[.lba], 127

.copy_big:
	sub word[.sectors], 127
	call go32

use32

	mov esi, 0x40000
	mov edi, [.buffer]
	add edi, dword[.copy]
	mov ecx, 65024
	rep movsb

	call go16

use16

.continue_big:
	add dword[.copy], 65024
	jmp .read

.fail:
	call go32

use32

	stc
	ret

use16

.done:
	call go32

use32

	movzx eax, word[dap.sectors]
	mov ebx, 512
	mul ebx

	mov ecx, eax
	mov esi, 0x40000
	mov edi, [.buffer]
	add edi, dword[.copy]
	rep movsb

	clc
	ret


.buffer			dd 0
.lba			dd 0
.sectors		dd 0
.max_lba		dd 0
.copy			dd 0

; hdd_write_sectors:
; Writes a series of sectors to the hard disk
; In\	EAX = LBA sector
; In\	EBX = Sectors to write
; In\	ESI = Buffer to write sectors
; Out\	Carry clear on success
; Out\	AH = Error code on failure

hdd_write_sectors:
	mov [.lba], eax
	mov [.sectors], ebx
	mov [.buffer], esi

.start:
	cmp dword[.sectors], 0
	je .done

	cmp dword[.sectors], 127
	jg .big

	mov esi, [.buffer]
	mov edi, 0x40000
	mov ecx, [.sectors]
	shl ecx, 9			; quick multiply by 512
	rep movsb

	call go16

use16

	mov eax, [.lba]
	mov [dap.lba], eax
	mov word[dap.segment], 0x4000
	mov word[dap.offset], 0
	mov eax, [.sectors]
	mov [dap.sectors], ax

	mov ax, 0
	mov dl, [bootdisk]
	int 0x13
	jc .error

	mov byte[dap.size], 0x10
	mov byte[dap.reserved], 0
	mov dword[dap.lba+4], 0

	mov ah, 0x43			; extended write sectors
	mov dl, [bootdisk]
	mov si, dap
	int 0x13
	jc .error

	mov edx, [.sectors]
	add dword[diskstat.write], edx

	call go32

use32

	clc
	ret

.big:
	mov esi, [.buffer]
	mov ecx, 127*512
	mov edi, 0x40000
	rep movsb
	add dword[.buffer], 127*512

	call go16

use16

	mov eax, [.lba]
	mov [dap.lba], eax
	mov word[dap.segment], 0x4000
	mov word[dap.offset], 0
	mov word[dap.sectors], 127

	mov ax, 0
	mov dl, [bootdisk]
	int 0x13
	jc .error

	mov byte[dap.size], 0x10
	mov byte[dap.reserved], 0
	mov dword[dap.lba+4], 0

	mov ah, 0x43
	mov dl, [bootdisk]
	mov si, dap
	int 0x13
	jc .error

	add dword[diskstat.write], 127
	add dword[.lba], 127
	sub dword[.sectors], 127

	call go32

use32

	jmp .start

.done:
	clc
	mov eax, 0
	ret

use16

.error:
	call go32

use32

	stc
	ret

.lba			dd 0
.sectors		dd 0
.buffer			dd 0

; hdd_get_info:
; Gets hard disk I/O stats
; In\	Nothing
; Out\	EAX = Hard disk size in MB
; Out\	EBX = Number of sectors read since boot
; Out\	ECX = Number of sectors written since boot

hdd_get_info:
	mov eax, [disk_size_mb]
	mov ebx, [diskstat.read]
	mov ecx, [diskstat.write]
	ret





