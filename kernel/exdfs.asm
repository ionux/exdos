
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/exdfs.asm							;;
;; ExDFS Driver								;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Functions:
; detect_exdfs
; internal_filename
; external_filename
; load_root_directory
; write_root_directory
; load_file
; does_file_exist
; get_filenames_string
; get_file_size

use32

; detect_exdfs:
; Detects ExDFS partition

detect_exdfs:
	mov eax, [boot_partition.lba]		; read the boot sector
	mov ebx, 1
	mov edi, disk_buffer
	call hdd_read_sectors

	mov esi, disk_buffer+0xC
	cmp dword[esi], 0x7A658502		; verify the ExDFS magic number
	jne .bad

	mov esi, disk_buffer+0x22		; verify the ExDFS ID
	mov edi, .exdfs_id
	mov ecx, 8
	rep cmpsb
	jne .bad

	; If we make it here, we have a valid ExDFS partition
	mov esi, disk_buffer+0x1A		; volume label
	mov edi, .volume_label
	mov ecx, 8
	rep movsb

	mov esi, disk_buffer+0x16		; volume serial number
	mov edi, .serial
	movsd

	mov esi, .debug_msg1
	call kdebug_print

	mov eax, [boot_partition.lba]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg2
	call kdebug_print_noprefix

	mov eax, [boot_partition.size]
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg3
	call kdebug_print_noprefix

	mov esi, .debug_msg4
	call kdebug_print

	mov eax, [.serial]
	call hex_dword_to_string
	call kdebug_print_noprefix

	mov esi, _crlf
	call kdebug_print_noprefix

	ret

.bad:
	mov esi, .fail_msg
	jmp draw_boot_error

.fail_msg			db "Failed to access the boot drive: corrupt ExDFS filesystem.",0
.debug_msg1			db "fs: ExDFS partition at LBA ",0
.debug_msg2			db ", size ",0
.debug_msg3			db " sectors.",10,0
.debug_msg4			db "fs: volume serial number is ",0
.exdfs_id			db "EXDFS   "
.volume_label:			times 9 db 0
.serial				dd 0

; internal_filename:
; Converts external file name to internal file name
; In\	ESI = External file name
; Out\	EDI = Internal file name as ASCIIZ string

internal_filename:
	mov eax, 0
	mov edi, new_filename
	mov ecx, 13
	rep stosb

	mov edi, new_filename
	mov ecx, 0

.loop:
	lodsb

	cmp al, '.'
	je .found_dot

	cmp al, 0
	je .error

	stosb
	inc ecx

	cmp ecx, 11
	jge .error

	jmp .loop

.found_dot:
	cmp ecx, 1
	je .error

	cmp ecx, 8
	je .do_extension

.add_spaces:
	mov al, ' '
	stosb

	inc ecx
	cmp ecx, 8
	je .do_extension

	jmp .add_spaces

.do_extension:
	lodsb
	cmp al, 0
	je .error
	stosb

	lodsb
	cmp al, 0
	je .error
	stosb

	lodsb
	cmp al, 0
	je .error
	stosb

.done:
	mov byte[edi], 0

	mov edi, new_filename
	mov eax, 0
	ret

.error:
	mov eax, 1
	mov edi, 0
	ret

; external_filename:
; Converts internal file name to external file name
; In\	ESI = Internal file name
; Out\	EDI = External file name as ASCIIZ string

external_filename:
	mov eax, 0
	mov ecx, 13
	mov edi, new_filename
	rep stosb

	mov edi, new_filename
	mov ecx, 1

.loop:
	lodsb
	cmp al, ' '
	je .space

	stosb
	add ecx, 1
	cmp ecx, 12
	je .done

	cmp ecx, 9
	je .do_dot

	jmp .loop

.space:
	cmp ecx, 8
	je .do_dot

	add ecx, 1
	jmp .loop

.do_dot:
	mov al, '.'
	stosb

	add ecx, 1
	jmp .loop

.done:
	mov byte[edi], 0
	mov edi, new_filename

	ret

new_filename:			times 16 db 0

; load_root_directory:
; Loads the root directory into RAM

load_root_directory:
	mov eax, 1
	add eax, dword[boot_partition.lba]
	mov ebx, 32
	mov edi, disk_buffer
	call hdd_read_sectors

	ret

; write_root_directory:
; Writes the root directory to the disk

write_root_directory:
	mov eax, 1
	add eax, dword[boot_partition.lba]
	mov ebx, 32
	mov esi, disk_buffer
	call hdd_write_sectors

	ret

; load_file:
; Loads file into RAM
; In\	ESI = File name
; In\	EDI = Location to load file
; Out\	EAX = 0 on success, 1 if file not found, 2 if disk error
; Out\	ECX = File size in bytes

load_file:
	mov [.location], edi

	call internal_filename
	call load_root_directory
	jc .disk_error

	mov esi, disk_buffer+32			; each root entry is 32 bytes in size
						; but the first entry is always unused for files, so skip it
	mov edi, new_filename
	mov ecx, 1				; start counting from 1 and not 0 because we skipped the first entry

.find_file:
	pusha
	mov ecx, 11
	rep cmpsb
	je .found_file
	popa

	add ecx, 1
	cmp ecx, 512
	je .file_not_found

	add esi, 32
	jmp .find_file

.found_file:
	add esi, 1
	mov eax, [esi]
	mov ebx, [esi+4]
	mov ecx, [esi+8]
	mov [.size], ecx

	mov edi, [.location]
	call hdd_read_sectors			; read the file into memory
	jc .disk_error_stub

	popa
	mov eax, 0
	mov ecx, [.size]
	ret

.file_not_found:
	mov eax, 1
	mov ecx, 0
	ret

.disk_error_stub:
	popa

.disk_error:
	mov eax, 2
	mov ecx, 0
	ret

.location			dd 0
.size				dd 0

; does_file_exist:
; Checks if a file exists
; In\	ESI = Filename
; Out\	EAX = 1 if file exists

does_file_exist:
	call internal_filename
	call load_root_directory

	mov esi, disk_buffer+32			; the first root entry is reserved
	mov edi, new_filename
	mov ecx, 1

.loop:
	pusha
	mov ecx, 11
	rep cmpsb
	je .yes
	popa
	
	add ecx, 1
	cmp ecx, 512
	je .no

	add esi, 32
	jmp .loop

.yes:
	mov eax, 1
	ret

.no:
	mov eax, 0
	ret

; get_filenames_string:
; Returns a comma-separated list of files on the disk
; In\	Nothing
; Out\	EAX = 0 on success, 1 on error
; Out\	ESI = Pointer to ASCIIZ string

get_filenames_string:
	call load_root_directory
	jc .error

	mov edi, disk_buffer
	mov [.tmp], edi

	mov esi, disk_buffer+32
	mov ecx, 1

.loop:
	cmp ecx, 512
	je .done

	cmp byte[esi], 0			; unused entry and no entries after are used...
	je .done

	cmp byte[esi], 0xAF			; deleted file
	je .skip

	push esi
	call external_filename

	mov esi, new_filename
	call get_string_size

	mov esi, new_filename
	mov ecx, eax
	mov edi, [.tmp]
	rep movsb

	mov al, ','
	stosb

	mov [.tmp], edi
	pop esi
	add esi, 32			; go to next entry
	add ecx, 1
	jmp .loop

.skip:
	add esi, 32
	add ecx, 1
	jmp .loop

.done:
	mov edi, [.tmp]
	dec edi				; get rid of the last comma
	mov byte[edi], 0		; null-terminated the string

	mov eax, 0
	mov esi, disk_buffer
	ret

.error:
	mov eax, 1
	ret

.tmp				dd 0

; get_file_size:
; Gets the size of a file in bytes
; In\	ESI = Filename
; Out\	EAX = 0 on success, 1 on error
; Out\	ECX = Size of file

get_file_size:
	call internal_filename
	call load_root_directory
	jc .error

	mov esi, disk_buffer+32
	mov edi, new_filename
	mov ecx, 1

.loop:
	pusha
	mov ecx, 11
	rep cmpsb
	je .found_file
	popa

	add ecx, 1
	cmp ecx, 512
	je .error

	add esi, 32
	jmp .loop

.found_file:
	add esi, 1
	mov ecx, [esi+8]
	mov [.size], ecx

	popa
	mov eax, 0
	mov ecx, [.size]
	ret

.error:
	mov eax, 1
	mov ecx, 0
	ret

.size				dd 0



