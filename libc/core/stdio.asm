
;; ExDOS C library
;; (C) 2015 by Omar Mohammad
;; All rights reserved.

use32

public printf
public _printf
public put_char
public _put_char

put_char:
_put_char:
	push ebp
	mov al, byte[esp+8]
	mov edi, .string
	stosb

	mov esi, .string
	mov ecx, 0
	mov edx, 0xFFFFFF
	mov eax, 5
	mov ebp, 0x520
	call ebp

	pop ebp
	mov eax, 0
	ret

.string:		times 2 db 0

printf:
_printf:
	push ebp
	mov esi, dword[esp+8]
	mov ecx, 0
	mov edx, 0xFFFFFF
	mov eax, 5
	mov ebp, 0x520
	call ebp

	pop ebp
	mov eax, 0
	ret




