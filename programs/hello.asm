
;;
;; Hello World Program for ExDOS
;; Assembly-language style
;;

use32
org 0x8000000

include			"programs/kapi.asm"

main:
	mov esi, string
	mov ecx, 0
	mov edx, 0xFFFFFF
	os_api print_string_cursor

	mov ebx, 0		; for debugging
	div ebx

	ret

string			db "Hello, world!",13,10
			db "If you're reading this, then you're running an assembly program for ExDOS! :)",13,10,0


