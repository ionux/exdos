
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/ata.asm							;;
;; ATA Disk Driver							;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

disk_model			= 0x36
ata_disk_model:			times 40 db 0
ata_spt				db 0
ata_heads			db 0
ata_disk			db 0

; ata_init:
; Initializes the ATA disk drive

ata_init:
	call go16

use16

	mov ah, 8
	mov dl, [bootdisk]
	int 0x13
	jc .error

	add dh, 1
	mov [ata_heads], dh

	and cl, 0x3F
	mov [ata_spt], cl

	mov eax, 0
	mov dl, [bootdisk]
	int 0x13

	call go32

use32

	mov ah, 1
	mov al, 1
	call pci_get_device		; scan the PCI bus for an IDE controller

	cmp ax, 0xFFFF
	je .no_ata

	cmp bl, 0xFF
	je .no_ata

	mov al, 0xA0			; check for the primary disk drive
	mov byte[ata_disk], al
	call ata_identify
	jc .try_secondary		; if not, maybe we booted from the secondary disk driver

	jmp .done

.try_secondary:
	mov al, 0xB0			; secondary disk driver
	mov byte[ata_disk], al
	call ata_identify
	jnc .done

.no_ata:
	; If we make it here, there are no ATA disk drives installed
	ret

.done:
	mov esi, ata_identify_structure
	add esi, disk_model
	mov edi, ata_disk_model

	mov al, byte[esi]
	mov byte[edi+1], al
	mov al, byte[esi+1]
	mov byte[edi], al
	mov al, byte[esi+2]
	mov byte[edi+3], al
	mov al, byte[esi+3]
	mov byte[edi+2], al
	mov al, byte[esi+4]
	mov byte[edi+5], al
	mov al, byte[esi+5]
	mov byte[edi+4], al
	mov al, byte[esi+6]
	mov byte[edi+7], al
	mov al, byte[esi+7]
	mov byte[edi+6], al
	mov al, byte[esi+8]
	mov byte[edi+9], al
	mov al, byte[esi+9]
	mov byte[edi+8], al
	mov al, byte[esi+10]
	mov byte[edi+11], al
	mov al, byte[esi+11]
	mov byte[edi+10], al
	mov al, byte[esi+13]
	mov byte[edi+12], al

	ret

use16

.error:
	call go32

use32

	mov ebx, 0x333333
	mov cx, 0
	mov dx, 218
	mov esi, 800
	mov edi, 160
	call alpha_fill_rect

	mov esi, .error_msg
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

.error_msg			db "Boot error: BIOS INT 0x13 function 8 failed, couldn't get disk geometry.",0

; ata_identify:
; Identifies an ATA disk drive
; In\	AL = Drive number (0xA0 for primary, 0xB0 for secondary)
; Out\	Nothing

ata_identify:
	mov dx, 0x1F6
	out dx, al

	mov eax, 0
	mov dx, 0x1F2
	out dx, al

	mov eax, 0
	mov dx, 0x1F3
	out dx, al

	mov eax, 0
	mov dx, 0x1F4
	out dx, al

	mov eax, 0
	mov dx, 0x1F5
	out dx, al

	mov al, 0xEC		; ATA identify command
	mov dx, 0x1F7
	out dx, al

	mov dx, 0x1F7
	in al, dx
	cmp al, 0
	je .no_disk

.wait_disk:
	mov dx, 0x1F7
	in al, dx

	test al, 0x80
	jz .cleared
	jmp .wait_disk

.cleared:
	mov dx, 0x1F0
	mov edi, ata_identify_structure
	mov ecx, 256				; get 256 words from the disk
	rep insw

	clc
	ret

.no_disk:
	stc
	ret

; ata_lba_to_chs:
; Converts an LBA address to a CHS address
; In\	EAX = LBA address
; Out\	EBX = CHS values

ata_lba_to_chs:
	mov [.lba], eax

	mov eax, [.lba]
	movzx ebx, byte[ata_spt]
	mov edx, 0
	div ebx
	mov [.tmp], eax

	mov eax, [.lba]
	movzx ebx, byte[ata_spt]
	mov edx, 0
	div ebx
	add edx, 1
	mov [.sector], dl

	mov eax, [.tmp]
	movzx ebx, byte[ata_heads]
	mov edx, 0
	div ebx
	mov [.head], dl

	mov eax, [.tmp]
	movzx ebx, byte[ata_heads]
	mov edx, 0
	div ebx
	mov [.cylinder], ax

	mov ebx, 0
	mov bx, [.cylinder]
	shl ebx, 16
	mov bh, [.head]
	mov bl, [.sector]

	ret

.cylinder			dw 0
.head				db 0
.sector				db 0
.lba				dd 0
.tmp				dd 0

; ata_read_sector:
; Reads a series of sectors from the ATA hard disk
; In\	EAX = LBA sector
; In\	EBX = Number of sectors to read
; In\	EDI = Buffer to read sectors
; Out\	Nothing

ata_read_sector:
	pusha
	mov [.lba], eax
	mov [.sectors], ebx
	mov [.buffer], edi

	mov eax, [.lba]
	call ata_lba_to_chs
	mov [.chs], ebx

	mov edx, 0x1F6
	mov al, bh
	and al, 0xF
	mov bl, [ata_disk]
	or al, bl
	out dx, al

	mov edx, 0x1F2
	mov eax, [.sectors]
	out dx, al

	mov edx, 0x1F3
	mov eax, [.chs]
	out dx, al

	mov edx, 0x1F4
	mov eax, [.chs]
	shr eax, 16
	out dx, al

	mov edx, 0x1F5
	mov eax, [.chs]
	shr eax, 24
	out dx, al

	mov edx, 0x1F7
	mov eax, 0x20
	out dx, al

	mov ebx, [ticks]
	add ebx, 100			; give the disk 1 second to get ready

.wait_for_disk:
	cmp ebx, [ticks]
	jle .disk_error
	mov edx, 0x1F7
	in al, dx
	test al, 8
	jz .wait_for_disk

	mov edi, [.buffer]
	mov eax, 256
	mov ebx, [.sectors]
	mul ebx
	mov ecx, eax
	mov edx, 0x1F0
	rep insw

	popa
	mov eax, 0
	ret

.disk_error:
	popa
	mov eax, 1
	ret

.lba				dd 0
.sectors			dd 0
.buffer				dd 0
.chs				dd 0


