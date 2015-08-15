
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
; internal_filename
; external_filename
; load_root_directory
; load_file

use32

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


