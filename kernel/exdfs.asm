
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
; write_file
; delete_file
; copy_file

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

	mov esi, .msg
	mov ecx, 0
	mov edx, 0xFFFFFF
	call print_string_graphics_cursor

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
.msg				db "Found EXDFS partition.",13,10,0

; internal_filename:
; Converts external file name to internal file name
; In\	ESI = External file name
; Out\	EDI = Internal file name as ASCIIZ string

internal_filename:
	mov [.filename], esi
	call get_string_size
	mov [.size], eax
	mov ecx, eax
	mov esi, [.filename]
	mov dl, 0xAF
	call find_byte_in_string
	jnc .bad_filename

	mov ecx, [.size]
	mov esi, [.filename]
	mov dl, '/'
	call find_byte_in_string
	jnc .bad_filename

	mov ecx, [.size]
	mov esi, [.filename]
	mov dl, '\'
	call find_byte_in_string
	jnc .bad_filename

	mov esi, [.filename]
	mov edi, new_filename
	mov ecx, 0

.loop:
	lodsb
	cmp al, '.'
	je .found_dot

	stosb
	inc ecx
	cmp ecx, 8
	jg .bad_filename

	jmp .loop

.found_dot:
	cmp edi, new_filename+8
	je .do_extension

.fill_spaces:
	mov al, ' '
	stosb
	cmp edi, new_filename+8
	je .do_extension
	jmp .fill_spaces

.do_extension:
	push esi
	call get_string_size
	pop esi
	mov ecx, eax
	cmp ecx, 3
	jg .bad_filename

	mov edi, new_filename+8
	rep movsb

	mov eax, 0
	mov edi, new_filename
	ret

.bad_filename:
	mov edi, new_filename
	mov al, 0xFE
	mov ecx, 11
	rep stosb
	mov al, 0
	stosb

	mov eax, 1
	mov edi, new_filename
	ret

.filename			dd 0
.size				dd 0

; external_filename:
; Converts internal file name to external file name
; In\	ESI = Internal file name
; Out\	EDI = External file name as ASCIIZ string

external_filename:
	mov [.filename], esi
	call get_string_size
	cmp eax, 11
	jne .bad_filename

	mov esi, [.filename]
	mov dl, ' '
	mov ecx, 9
	call find_byte_in_string
	jc .no_spaces

	mov esi, [.filename]
	mov ecx, 0
	mov edi, .bad_filename

.loop:
	lodsb
	cmp al, ' '
	je .space
	inc ecx
	cmp ecx, 8
	jge .do_extension
	jmp .loop

.space:

.do_extension:
	mov esi, [.filename]
	add esi, 8
	mov al, '.'
	stosb

	mov ecx, 3
	rep movsb

	mov al, 0
	stosb

	mov edi, new_filename
	mov eax, 0
	ret

.no_spaces:
	mov esi, [.filename]
	mov edi, new_filename
	mov ecx, 8
	rep movsb
	mov al, '.'
	stosb
	mov ecx, 3
	rep movsb

	mov al, 0
	stosb

	mov edi, new_filename
	mov eax, 0
	ret

.bad_filename:
	mov edi, new_filename
	mov al, 0xFE
	mov ecx, 11
	rep stosb
	mov al, 0
	stosb

	mov eax, 1
	mov edi, new_filename
	ret

.filename			dd 0

new_filename:			times 12 db 0

; load_root_directory:
; Loads the root directory into RAM

load_root_directory:
	mov edi, disk_buffer
	mov ecx, 32*512
	mov eax, 0
	rep stosb

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
	popa
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

	mov [.tmp], 0x40000
	mov esi, disk_buffer+32
	mov ecx, 1

.loop:
	cmp ecx, 512
	je .done

	cmp byte[esi], 0
	je .done

	cmp byte[esi], 0xAF
	je .skip_entry

	push esi
	mov edi, [.tmp]
	mov ecx, 8
	rep movsb
	mov al, '.'
	stosb
	mov ecx, 3
	rep movsb

	mov al, ','
	stosb

	mov [.tmp], edi

	pop esi
	inc ecx
	add esi, 32
	jmp .loop

.skip_entry:
	inc ecx
	add esi, 32
	jmp .loop

.done:
	mov edi, [.tmp]
	dec edi
	mov al, 0
	stosb

	mov eax, 0
	mov esi, 0x40000
	ret

.error:
	mov eax, 1
	ret

.tmp				dd 0
.tmp_filename:			times 12 db 0

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

; write_file:
; Writes a file to the disk
; In\	ESI = Filename
; In\	EDI = Buffer to write to file
; In\	ECX = Bytes to write to file
; Out\	EAX = Status
;	0 - success, 1 - no more space, 2 - disk I/O error
; Note: Creates the file if it doesn't exist, overwrites without prompt if it exists.

write_file:
	mov [.filename], esi
	mov [.buffer], edi
	mov [.size], ecx
	call internal_filename
	cmp eax, 1
	je .disk_error

	mov eax, [boot_partition.lba]
	add eax, dword[boot_partition.size]
	mov [.last_lba], eax			; marks the end of the partition

	mov esi, [.filename]
	call does_file_exist

	cmp eax, 0				; if the file doesn't exist --
	je .create_file				; -- we need to create the file

	jmp .already_exists

.create_file:
	call load_root_directory
	jc .disk_error

	; we need to find an unused root entry
	; if the first byte is 0xAF, the entry has been used before but the file has been deleted, so we can use it.
	; if the first byte is 0x00, the entry has never been used and all entries after it are also unused.
	mov esi, disk_buffer+32			; the first entry is reserved
	mov ecx, 1

.find_empty_root_entry:
	cmp byte[esi], 0xAF			; deleted
	je .found_empty_entry

	cmp byte[esi], 0x00			; unused
	je .found_empty_entry

	add ecx, 1
	cmp ecx, 512
	je .no_space

	add esi, 32
	jmp .find_empty_root_entry

.found_empty_entry:
	push esi
	mov esi, [.filename]
	call internal_filename

	cmp eax, 0				; if it is a bad file name --
	jne .disk_error				; -- simulate a disk error

	; Build the root entry:
	; do the filename
	pop edi
	mov esi, new_filename
	mov ecx, 11
	rep movsb

	; the filename is always ASCIIZ, so put a zero after the file name
	mov al, 0
	stosb

	mov [.tmp_root], edi

	; now is the LBA sector, so we need to find an empty sector
	mov eax, [boot_partition.lba]
	add eax, 2048
	mov [.lba], eax

.find_empty_sector_stub:
	mov eax, [.lba]

.find_empty_sector:
	mov ebx, 1				; read one sector
	mov edi, 0x40000
	call hdd_read_sectors
	jc .disk_error

	mov esi, 0x40000
	mov edi, .zero
	mov ecx, 511

.check_is_empty:
	cmpsb
	jne .next_sector

	mov edi, .zero
	loop .check_is_empty

	; If we make it here, we've found an empty sector
	jmp .found_empty_sector

.next_sector:
	add dword[.lba], 1
	mov eax, [.lba]
	cmp eax, dword[.last_lba]
	jge .no_space

	jmp .find_empty_sector_stub

.found_empty_sector:
	; Now we can continue building the root directory entry structure
	mov edi, [.tmp_root]
	mov eax, [.lba]
	stosd
	mov [.tmp_root], edi

	; next is the size in sectors
	mov eax, [.size]
	mov ebx, 512
	call round_forward			; make the number a multiple of 512

	mov ebx, 512
	mov edx, 0
	div ebx					; size in sectors :)
	mov [.size_sectors], eax
	mov edi, [.tmp_root]
	stosd

	; next is the size in bytes
	mov eax, [.size]
	stosd
	mov [.tmp_root], edi

	; and then is the time in 24-hour format...
	call get_time_24
	push eax
	mov edi, [.tmp_root]
	mov al, ah				; hour first
	stosb
	pop eax
	stosb					; minute next

	mov [.tmp_root], edi

	; and then is the date...
	call get_date
	mov edi, [.tmp_root]
	stosb					; day
	mov al, ah
	stosb					; month
	mov ax, bx
	stosw					; year

	mov ax, 0				; last word is reserved...
	stosw

	; Now, we can write the root directory to the disk
	call write_root_directory
	jc .disk_error

	jmp .save

.already_exists:
	mov esi, [.filename]
	call internal_filename
	call load_root_directory
	jc .disk_error

	mov esi, disk_buffer+32			; the first entry is reserved...
	mov edi, new_filename
	mov ecx, 1

.find_file:
	pusha
	mov ecx, 11
	rep cmpsb
	je .found_file
	popa

	add esi, 32
	jmp .find_file

.found_file:
	add esi, 1
	mov eax, dword[esi]
	mov [.lba], eax

	mov [.tmp_root], esi
	popa

	mov eax, [.size]
	mov ebx, 512
	call round_forward

	mov ebx, 512
	mov edx, 0
	div ebx
	mov [.size_sectors], eax

	mov esi, [.tmp_root]
	mov [esi+4], eax			; size of file in sectors

	mov eax, [.size]
	mov [esi+8], eax			; size of file in bytes

	call write_root_directory		; write the changes to the disk
	jc .disk_error

.save:
	mov eax, [.buffer]
	add eax, dword[.size]
	mov ebx, 512
	call round_forward

	mov edi, [.buffer]
	add edi, dword[.size]

	; clear the rest of the file with zeroes so that users don't see garbage data that may have been in memory
	mov ecx, eax
	mov eax, 0

.clear_loop:
	cmp edi, ecx
	jge .write
	stosb
	jmp .clear_loop

.write:
	; Now let's write the file :)
	mov eax, [.lba]
	mov ebx, [.size_sectors]
	mov esi, [.buffer]
	call hdd_write_sectors
	jc .disk_error

	; And we're finished! :)

.done:
	mov eax, 0
	ret

.no_space:
	mov eax, 1
	ret

.disk_error:
	mov eax, 2
	ret

.filename			dd 0
.last_lba			dd 0
.size				dd 0
.buffer				dd 0
.tmp_root			dd 0
.zero				db 0
.lba				dd 0
.size_sectors			dd 0

; delete_file:
; Deletes a file from the disk
; In\	ESI = File name
; Out\	EAX = Status
;	0 - success, 1 - file not found, 2 - disk error

delete_file:
	call internal_filename
	call load_root_directory
	jc .disk_error

	mov esi, disk_buffer+32		; first entry is reserved...
	mov edi, new_filename
	mov ecx, 1

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
	popa
	mov edi, esi
	mov eax, [edi+12]		; LBA
	mov [.lba], eax
	mov eax, [edi+16]		; size in sectors
	mov [.size], eax

	mov al, 0xAF			; mark file as deleted
	stosb
	mov al, 0
	mov ecx, 31
	rep stosb			; clear the rest of the root directory entry

	call write_root_directory
	jc .disk_error

	mov eax, 0
	ret

.file_not_found:
	mov eax, 1
	ret

.disk_error:
	mov eax, 2
	ret

.lba				dd 0
.size				dd 0

; copy_file:
; Copies a file
; In\	ESI = Source filename
; In\	EDI = Destination filename
; Out\	EAX = Status (0 - success, 1 - disk error, 2 - source file not found, 3 - too little memory)
; Note:	Overwrites destination file if it exists, creates it if it doesn't.

copy_file:
	mov [.source], esi
	mov [.dest], edi

	mov esi, [.source]
	call get_file_size
	cmp eax, 0
	jne .file_not_found

	; ECX contains size of source file in bytes...
	; Allocate memory to load the source file into memory
	mov [.size], ecx
	mov edx, [.size]
	call malloc

	cmp eax, 0			; if malloc returns a null pointer --
	je .memory_error		; -- then there isn't enough memory

	mov [.memory], eax
	mov esi, [.source]
	mov edi, [.memory]
	call load_file

	cmp eax, 0
	jne .file_not_found

	; Now write that buffer into the new file :)
	mov esi, [.dest]
	mov edi, [.memory]
	mov ecx, [.size]
	call write_file

	cmp eax, 0
	jne .disk_error

	mov eax, 0
	ret

.disk_error:
	mov eax, 1
	ret

.file_not_found:
	mov eax, 2
	ret

.memory_error:
	mov eax, 3
	ret

.source				dd 0
.dest				dd 0
.memory				dd 0
.size				dd 0

