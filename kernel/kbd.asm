
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/kbd.asm							;;
;; PS/2 Keyboard Driver							;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

kbd_leds			db 0

; wait_ps2_write:
; Waits to write to the PS/2 controller

wait_ps2_write:
	push eax

.wait:
	in al, 0x64
	test al, 2
	jnz .wait

	pop eax
	ret

; wait_ps2_read:
; Waits to read to the PS/2 controller

wait_ps2_read:
	push eax

.wait:
	in al, 0x64
	test al, 1
	jz .wait

	pop eax
	ret

; init_kbd:
; Initializes the keyboard

init_kbd:
	mov al, 33
	mov ebp, kbd_irq
	call install_isr

	mov al, 0
	call set_keyboard_leds

	call wait_ps2_write
	mov al, 0xF4
	out 0x60, al

	call wait_ps2_read
	in al, 0x60

	ret


; set_keyboard_leds:
; Sets the LED lights on the keyboard
; In\	AL = LED bitpattern
; Out\	Nothing

set_keyboard_leds:
	mov [.data], al

	call wait_ps2_write
	mov al, 0xED
	out 0x60, al

	call wait_ps2_read
	in al, 0x60

	mov al, [.data]
	out 0x60, al
	mov al, [.data]
	mov byte[kbd_leds], al

	call wait_ps2_read
	in al, 0x60

	ret

.data				db 0

; kbd_irq:
; Keyboard IRQ 1 handler

kbd_irq:
	pusha
	push ds
	push es
	push fs
	push gs

	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	in al, 0x60
	and eax, 0xFF

	cmp al, 0x36
	je .shift

	cmp al, 0x2A
	je .shift

	cmp al, 0xB6
	je .shift_release

	cmp al, 0xAA
	je .shift_release

	cmp al, 0x3A
	je .caps_lock

	test al, 0x80
	jnz .no

	mov [last_scancode], al

	cmp byte[.shift_status], 1
	je .use_shift

	cmp byte[.caps_lock_status], 1
	je .use_caps_lock

.no_shift:
	mov esi, ascii_codes
	add esi, eax
	mov al, byte[esi]
	mov [last_character], al

	jmp .done

.use_shift:
	cmp byte[.caps_lock_status], 1
	je .use_shift_caps_lock

	mov esi, ascii_codes_shift
	add esi, eax
	mov al, byte[esi]
	mov [last_character], al

	jmp .done

.use_shift_caps_lock:
	mov esi, ascii_codes_shift_caps_lock
	add esi, eax
	mov al, byte[esi]
	mov [last_character], al

	jmp .done

.use_caps_lock:
	mov esi, ascii_codes_caps_lock
	add esi, eax
	mov al, byte[esi]
	mov [last_character], al

	jmp .done

.shift:
	mov byte[.shift_status], 1
	jmp .done

.shift_release:
	mov byte[.shift_status], 0
	jmp .done

.caps_lock:
	cmp byte[.caps_lock_status], 0
	je .turn_on_caps_lock

.turn_off_caps_lock:
	mov byte[.caps_lock_status], 0

	mov al, [kbd_leds]
	and al, 0xFB
	mov [kbd_leds], al
	mov al, [kbd_leds]
	call set_keyboard_leds

	jmp .done

.turn_on_caps_lock:
	mov byte[.caps_lock_status], 1

	mov al, [kbd_leds]
	or al, 4
	mov [kbd_leds], al
	mov al, [kbd_leds]
	call set_keyboard_leds

	jmp .done

.control:
	mov byte[.control_status], 1
	jmp .done

.control_release:
	mov byte[.control_status], 0
	jmp .done

.alt:
	mov byte[.alt_status], 1
	jmp .done

.alt_release:
	mov byte[.alt_status], 0
	jmp .done

.delete:
	cmp byte[.control_status], 1
	jne .done
	cmp byte[.alt_status], 1
	jne .done

	;call reboot

.no:
	mov byte[last_character], 0

.done:
	mov al, 0x20
	out 0x20, al

	pop gs
	pop fs
	pop es
	pop ds
	popa
	iret

.shift_status			db 0
.caps_lock_status		db 0
.control_status			db 0
.alt_status			db 0

last_character			db 0
last_scancode			db 0

align 32

ascii_codes:
	db 0,27
	db "1234567890-=",8
	db "	"
	db "qwertyuiop[]",13,0
	db "asdfghjkl;'`",0
	db "\zxcvbnm,./",0
	db "*",0
	db " "
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db "-",0,0,0,"+"
	times 128 - ($-ascii_codes) db 0

align 32

ascii_codes_shift:
	db 0,27
	db "!@#$%^&*()_+",8
	db "	"
	db "QWERTYUIOP{}",13,0
	db "ASDFGHJKL:", '"', "~",0
	db "|ZXCVBNM<>?",0
	db "*",0
	db " "
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db "-",0,0,0,"+"
	times 128 - ($-ascii_codes_shift) db 0

align 32

ascii_codes_caps_lock:
	db 0,27
	db "1234567890-=",8
	db "	"
	db "QWERTYUIOP[]",13,0
	db "ASDFGHJKL;'`",0
	db "\ZXCVBNM,./",0
	db "*",0
	db " "
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db "-",0,0,0,"+"
	times 128 - ($-ascii_codes_caps_lock) db 0

align 32

ascii_codes_shift_caps_lock:
	db 0,27
	db "!@#$%^&*()_+",8
	db "	"
	db "qwertyuiop{}",13,0
	db "asdfghjkl:", '"', "~",0
	db "|zxcvbnm<>?",0
	db "*",0
	db " "
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db "-",0,0,0,"+"
	times 128 - ($-ascii_codes_shift_caps_lock) db 0

; get_char_no_wait:
; Gets a character without waiting
; In\	Nothing
; Out\	AL = Character
; Out\	AH = ASCII scancode

get_char_no_wait:
	sti
	hlt
	mov al, [last_character]
	mov ah, [last_scancode]

	ret

; get_char_wait:
; Gets a character with waiting
; In\	Nothing
; Out\	AL = Character
; Out\	AH = ASCII scancode

get_char_wait:
	sti
	cmp byte[last_character], 0
	hlt					; halting saves energy and cools down the CPU
						; it also speeds up some emulators like Bochs
	je get_char_wait

	mov al, byte[last_character]
	mov ah, byte[last_scancode]

	mov byte[last_character], 0
	mov byte[last_scancode], 0

	ret

; get_string_echo:
; Gets a string from the keyboard with echo
; In\	ESI = Location to store string
; In\	EBX = Foreground color
; In\	ECX = Background color
; Out\	ESI = String filled and null-terminated

get_string_echo:
	mov [.string], esi

	mov [text_foreground], ebx
	mov [text_background], ecx

	mov edi, [.string]
	mov ecx, 256
	mov eax, 0
	rep stosb

	mov al, [x_cur]
	mov [.x], al

	mov edi, [.string]
	add edi, 255
	mov [.end_string], edi

	mov edi, [.string]

.loop:
	call get_char_wait			; get a character from the keyboard

	cmp al, 8		; backspace?
	je .backspace

	cmp al, 13		; Enter?
	je .done

	; If neither, it's a normal character, save it and print it
	push eax
	stosb
	pop eax
	call put_char_cursor

	cmp edi, [.end_string]
	je .done

	jmp .loop

.backspace:
	mov bl, [x_cur]
	cmp bl, [.x]
	jle .loop

	dec edi
	mov al, 8
	call put_char_cursor
	mov al, ' '
	call put_char_cursor
	mov al, 8
	call put_char_cursor

	jmp .loop

.done:
	mov al, 0
	stosb

	mov esi, _crlf
	call print_string_graphics_cursor

	mov esi, [.string]
	ret

.string				dd 0
.end_string			dd 0
.x				db 0


