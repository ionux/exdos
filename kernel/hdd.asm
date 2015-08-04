
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

	mov eax, 0
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

	mov eax, 0
	mov dl, [bootdisk]
	int 0x13
	jc .fail

	call go32

use32

	cli
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

	ret

use16

.fail:
	mov ax, 3
	int 0x10

	mov si, .fail_msg
	call print_string_16

	jmp $

.fail_msg			db "Boot error: Hard disk failure.",0
.debug_msg1			db "hdd: BIOS boot drive number is ",0
.debug_msg2			db "hdd: disk size is ",0
.debug_msg3			db " MB.",10,0

use32

; hdd_read_sectors:
; Reads a series of sectors from the hard disk
; In\	EAX = LBA
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
	mov ax, 0
	mov dl, [bootdisk]
	int 0x13
	jc .fail

	mov word[dap.segment], 0x4000
	mov word[dap.offset], 0
	mov eax, [.lba]
	mov dword[dap.lba], eax
	mov ebx, [.sectors]
	cmp ebx, 127
	jg .big
	mov word[dap.sectors], bx

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
