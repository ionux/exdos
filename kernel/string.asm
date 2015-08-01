
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/string.asm							;;
;; String-based Routines						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

; get_string_size:
; Returns the size of a string
; In\	ESI = String
; Out\	EAX = String size

get_string_size:
	pusha
	mov ecx, 0

.loop:
	lodsb
	cmp al, 0
	je .done

	add ecx, 1
	jmp .loop

.done:
	mov [.tmp], ecx
	popa
	mov eax, [.tmp]
	ret

.tmp				dd 0

; compare_strings:
; Compares two null-terminated strings
; In\	ESI = String 1
; In\	EDI = String 2
; Out\	EAX = 0 if equal, 1 if not

compare_strings:
	pusha

.loop:
	mov al, byte[esi]
	mov ah, byte[edi]

	cmp al, ah
	jne .not_equal

	cmp al, 0
	je .equal

	inc esi
	inc edi
	jmp .loop

.equal:
	popa
	mov eax, 0
	ret

.not_equal:
	popa
	mov eax, 1
	ret

; chomp_string:
; Gets rid of extra spaces in a string
; In\	EAX = String location
; OUt\	Nothing

chomp_string:
	pusha

	mov edx, eax

	mov edi, eax
	mov ecx, 0

.keep_counting:
	cmp byte [edi], ' '
	jne .counted
	inc ecx
	inc edi
	jmp .keep_counting

.counted:
	cmp ecx, 0
	je .finished_copy

	mov esi, edi
	mov edi, edx

.keep_copying:
	mov al, [esi]
	mov [edi], al
	cmp al, 0
	je .finished_copy
	inc esi
	inc edi
	jmp .keep_copying

.finished_copy:
	mov eax, edx

	mov esi, eax
	call get_string_size
	cmp eax, 0
	je .done

	mov esi, edx
	add esi, eax

.more:
	dec esi
	cmp byte [esi], ' '
	jne .done
	mov byte [esi], 0
	jmp .more

.done:
	popa
	ret

; hex_nibble_to_string:
; Converts an 4-bit hex value to an ASCIIZ string
; In\	AL = Hex value
; Out\	ESI = ASCIIZ string

hex_nibble_to_string:
	and eax, 0xF
	mov esi, hex_values
	add eax, esi
	mov esi, eax
	mov al, byte[esi]
	mov edi, .string
	stosb
	mov al, 0
	stosb

	mov esi, .string
	ret

.string:		times 2 db 0

; hex_byte_to_string:
; Converts an 8-bit hex value to an ASCIIZ string
; In\	AL = Hex byte
; Out\	ESI = ASCIIZ string

hex_byte_to_string:
	mov [.byte], al
	and eax, 0xF0
	shr eax, 4
	call hex_nibble_to_string
	mov al, byte[esi]
	mov edi, .string
	mov byte[edi], al

	mov al, [.byte]
	and eax, 0xF
	call hex_nibble_to_string
	mov al, byte[esi]
	mov edi, .string
	mov byte[edi+1], al

	mov esi, .string
	ret

.byte			db 0
.string:		times 3 db 0

; hex_word_to_string:
; Converts a 16-bit hex value to an ASCIIZ string
; In\	AX = Hex word
; Out\	ESI = ASCIIZ string

hex_word_to_string:
	mov [.word], ax
	shr ax, 8
	call hex_byte_to_string
	mov edi, .string
	mov ecx, 2
	rep movsb

	mov ax, [.word]
	call hex_byte_to_string
	mov edi, .string
	add edi, 2
	mov ecx, 2
	rep movsb

	mov esi, .string
	ret

.word			dw 0
.string:		times 5 db 0

; hex_dword_to_string:
; Converts a 32-bit hex value to an ASCIIZ string
; In\	EAX = Hex dword
; Out\	ESI = ASCIIZ string

hex_dword_to_string:
	mov [.dword], eax
	shr eax, 16
	call hex_word_to_string
	mov edi, .string
	mov ecx, 4
	rep movsb

	mov eax, [.dword]
	call hex_word_to_string
	mov edi, .string
	add edi, 4
	mov ecx, 4
	rep movsb

	mov esi, .string
	ret

.dword			dd 0
.string:		times 9 db 0

align 32

hex_values			db "0123456789ABCDEF"

; int_to_string:
; Converts an unsigned integer to a string
; In\	EAX = Integer
; Out\	ESI = ASCIIZ string

int_to_string:
	push eax
	mov [.counter], 10

	mov edi, .string
	mov ecx, 10
	mov eax, 0
	rep stosb

	mov esi, .string
	add esi, 9
	pop eax

.loop:
	cmp eax, 0
	je .done2
	mov ebx, 10
	mov edx, 0
	div ebx

	add dl, 48
	mov byte[esi], dl
	dec esi

	sub byte[.counter], 1
	cmp byte[.counter], 0
	je .done
	jmp .loop

.done:
	mov esi, .string
	ret

.done2:
	cmp byte[.counter], 10
	je .zero
	mov esi, .string

.find_string_loop:
	lodsb
	cmp al, 0
	jne .found_string
	jmp .find_string_loop

.found_string:
	dec esi
	ret

.zero:
	mov edi, .string
	mov al, '0'
	stosb
	mov al, 0
	stosb
	mov esi, .string

	ret

.string:		times 11 db 0
.counter		db 0
