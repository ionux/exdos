
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/gdi.asm							;;
;; Graphical Device Interface						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Functions:
; get_pixel_offset
; redraw_screen
; redraw_text_cursor
; show_text_cursor
; hide_text_cursor
; get_screen_center
; put_pixel
; move_cursor_graphics
; put_char_transparent
; put_char
; put_char_cursor
; print_string_graphics
; print_string_graphics_cursor
; print_string_transparent
; scroll_screen_graphics
; clear_screen
; draw_horz_line
; fill_rect
; alpha_blend_colors
; alpha_draw_horz_line
; alpha_fill_rect
; draw_image
; display_bitmap_32bpp
; display_bitmap_24bpp

use32

text_background			dd 0
text_foreground			dd 0xC0C0C0		; gray
cursor_moved			db 0
text_cursor_visible		db 0
dirty_line			dd 0

; get_pixel_offset:
; Returns the offset of a pixel
; In\	AX = X position
; In\	BX = Y position
; Out\	EDI = Pixel offset

get_pixel_offset:
	and eax, 0xFFFF
	and ebx, 0xFFFF

	; offset = (Y * bytes per line) + (X * bytes per pixel)
	mov [.x], eax
	mov [.y], ebx

	mov eax, [.y]
	mov ebx, [screen.bytes_per_line]
	mul ebx

	mov [.tmp], eax
	mov eax, [.x]
	mov ebx, [screen.bytes_per_pixel]
	mul ebx
	mov ebx, [.tmp]
	add eax, ebx

	mov edi, eax
	add edi, [screen.framebuffer]
	ret

.x			dd 0
.y			dd 0
.tmp			dd 0

; redraw_screen:
; Redraws the screen

redraw_screen:
	;pusha

	mov eax, [screen.height]
	mov ebx, [dirty_line]
	sub eax, ebx
	mov ebx, [screen.bytes_per_line]
	mul ebx

	mov ecx, eax
	shr ecx, 7

	push ecx
	mov eax, 0
	mov ebx, [dirty_line]
	call get_pixel_offset
	pop ecx

	mov esi, edi
	mov edi, eax
	add edi, dword[screen.virtual_buffer]

.loop:
	movdqa xmm0, [esi]
	movdqa xmm1, [esi+16]
	movdqa xmm2, [esi+32]
	movdqa xmm3, [esi+48]
	movdqa xmm4, [esi+64]
	movdqa xmm5, [esi+80]
	movdqa xmm6, [esi+96]
	movdqa xmm7, [esi+112]
	movdqa [edi], xmm0
	movdqa [edi+16], xmm1
	movdqa [edi+32], xmm2
	movdqa [edi+48], xmm3
	movdqa [edi+64], xmm4
	movdqa [edi+80], xmm5
	movdqa [edi+96], xmm6
	movdqa [edi+112], xmm7

	add esi, 128
	add edi, 128
	loop .loop

	;mov byte[cursor_moved], 0
	call redraw_text_cursor

	;popa
	ret

; redraw_text_cursor:
; Redraws the text cursor

redraw_text_cursor:
	cmp byte[text_cursor_visible], 1
	jne .quit

	movzx eax, [x_cur]
	shl eax, 3
	movzx ebx, [y_cur]
	shl ebx, 4
	add ebx, 15
	call get_pixel_offset

	add eax, [screen.virtual_buffer]
	mov edi, eax

	cmp [screen.bpp], 32
	jne .24bpp

.32bpp:
	mov eax, [text_foreground]
	mov ecx, 8
	rep stosd

	;add edi, dword[screen.bytes_per_line]
	;sub edi, 4*8

	;mov eax, [text_foreground]
	;mov ecx, 8
	;rep stosd

	ret

.24bpp:
	mov ecx, 8

.24loop:
	mov eax, [text_foreground]
	stosb
	shr eax, 8
	stosb
	shr eax, 8
	stosb

	loop .24loop

	;add edi, dword[screen.bytes_per_line]			; skip to the next line
	;sub edi, 3*8
	;mov ecx, 8
	ret

.24loop2:
	mov eax, [text_foreground]
	stosb
	shr eax, 8
	stosb
	shr eax, 8
	stosb

	loop .24loop2

.quit:
	ret

; show_text_cursor:
; Shows the text cursor

show_text_cursor:
	mov byte[text_cursor_visible], 1
	mov dword[dirty_line], 0
	call redraw_screen
	ret

; hide_text_cursor:
; Hides the text cursor

hide_text_cursor:
	mov byte[text_cursor_visible], 0
	mov dword[dirty_line], 0
	call redraw_screen				; redraw the screen to hide the old cursor
	ret

; get_screen_center:
; Get X/Y coordinates of screen center
; In\	Nothing
; Out\	BX/CX = X/Y coordinates

get_screen_center:
	mov ebx, [screen.width]
	mov ecx, [screen.height]
	shr ebx, 1			; quick divide by 2
	shr ecx, 1

	ret

.x			dw 0
.y			dw 0

; put_pixel:
; Plots a pixel
; In\	BX = X pos
; In\	CX = Y pos
; In\	EDX = Color
; Out\	Nothing

put_pixel:
	pusha

	and ecx, 0xFFFF
	mov [dirty_line], ecx

	mov [.color], edx

	mov ax, bx
	mov bx, cx
	call get_pixel_offset

	cmp byte[screen.bpp], 32
	jne .24_bpp

.32_bpp:
	mov eax, [.color]
	stosd				; 32-bit value

	popa
	ret

.24_bpp:
	mov eax, [.color]
	stosb				; blue
	shr eax, 8
	stosb				; green
	shr eax, 8
	stosb				; red

	call redraw_screen
	popa
	ret

.color			dd 0

; move_cursor_graphics:
; Moves the cursor in graphical mode
; In\	DL/DH = X/Y position
; Out\	Nothing

move_cursor_graphics:
	mov [x_cur], dl
	mov [y_cur], dh
	mov byte[cursor_moved], 1
	mov dword[dirty_line], 0
	call redraw_screen			; redraw the screen to show the new cursor

	ret

; put_char_transparent:
; Puts a character in graphical mode with a transparent background
; In\	AL = Character
; In\	BX = X pos
; In\	CX = Y pos
; Out\	Nothing

put_char_transparent:
	pusha
	mov [.char], al

	movzx eax, bx
	movzx ebx, cx
	call get_pixel_offset

	mov [.offset], edi

	mov al, [.char]
	and eax, 0xFF
	mov ebx, 16
	mul ebx
	mov esi, font_data
	add esi, eax
	mov [.font_data], esi

	mov al, byte[esi]
	mov [.byte], al
	mov byte[.column], 0
	mov byte[.row], 0

.put_row:
	test al, 0x80
	jz .do_background

.do_foreground:
	mov eax, [text_foreground]
	jmp .put_pixel

.do_background:
	jmp .put_done

.put_pixel:
	mov edi, [.offset]
	cmp dword[screen.bpp], 24
	je .put_pixel_24bpp

.put_pixel_32bpp:
	stosd
	jmp .put_done

.put_pixel_24bpp:
	stosb
	shr eax, 8
	stosb
	shr eax, 8
	stosb

.put_done:
	add byte[.column], 1
	cmp byte[.column], 8
	je .next_row

	mov al, [.byte]
	shl al, 1
	mov [.byte], al

	mov edx, [screen.bytes_per_pixel]
	mov ecx, [.offset]
	add ecx, edx
	mov [.offset], ecx

	jmp .put_row

.next_row:
	mov byte[.column], 0
	add byte[.row], 1
	cmp byte[.row], 16
	je .done

	mov esi, [.font_data]
	add esi, 1
	mov [.font_data], esi
	mov al, byte[esi]
	mov [.byte], al

	mov eax, [screen.bytes_per_pixel]
	;mov ebx, 8
	;mul ebx
	shl eax, 3			; quick multiply by 8
	sub dword[.offset], eax
	mov eax, [screen.bytes_per_line]
	add dword[.offset], eax
	mov eax, [screen.bytes_per_pixel]
	add dword[.offset], eax

	mov al, [.byte]
	jmp .put_row

.done:
	popa
	ret

.column			db 0
.row			db 0
.byte			db 0
.font_data		dd 0
.offset			dd 0
.char			db 0

; put_char:
; Puts a character in graphical mode
; In\	AL = Character
; In\	BX = X pos
; In\	CX = Y pos
; Out\	Nothing

put_char:
	pusha
	mov [.char], al

	movzx eax, bx
	movzx ebx, cx
	call get_pixel_offset

	mov [.offset], edi

	mov al, [.char]
	and eax, 0xFF
	;mov ebx, 16
	;mul ebx
	shl eax, 4
	mov esi, font_data
	add esi, eax
	mov [.font_data], esi

	mov al, byte[esi]
	mov [.byte], al
	mov byte[.column], 0
	mov byte[.row], 0

.put_row:
	test al, 0x80
	jz .do_background

.do_foreground:
	mov eax, [text_foreground]
	jmp .put_pixel

.do_background:
	mov eax, [text_background]

.put_pixel:
	mov edi, [.offset]
	cmp dword[screen.bpp], 24
	je .put_pixel_24bpp

.put_pixel_32bpp:
	stosd
	jmp .put_done

.put_pixel_24bpp:
	stosb
	shr eax, 8
	stosb
	shr eax, 8
	stosb

.put_done:
	add byte[.column], 1
	cmp byte[.column], 8
	je .next_row

	mov al, [.byte]
	shl al, 1
	mov [.byte], al

	mov edx, [screen.bytes_per_pixel]
	mov ecx, [.offset]
	add ecx, edx
	mov [.offset], ecx

	jmp .put_row

.next_row:
	mov byte[.column], 0
	add byte[.row], 1
	cmp byte[.row], 16
	je .done

	mov esi, [.font_data]
	add esi, 1
	mov [.font_data], esi
	mov al, byte[esi]
	mov [.byte], al

	mov eax, [screen.bytes_per_pixel]
	;mov ebx, 8
	;mul ebx
	shl eax, 3			; quick multiply by 8
	sub dword[.offset], eax
	mov eax, [screen.bytes_per_line]
	add dword[.offset], eax
	mov eax, [screen.bytes_per_pixel]
	add dword[.offset], eax

	mov al, [.byte]
	jmp .put_row

.done:
	popa
	ret

.column			db 0
.row			db 0
.byte			db 0
.font_data		dd 0
.offset			dd 0
.char			db 0

; put_char_cursor:
; Puts a character at the cursor position in graphical mode
; In\	AL = Character
; Out\	Nothing

put_char_cursor:
	pusha
	mov [.char], al

	;mov byte[cursor_moved], 1

	mov al, [.char]

	cmp al, 13
	je .carriage

	cmp al, 10
	je .newline

	cmp al, 8
	je .backspace

	;mov al, [y_cur]
	;cmp al, byte[y_cur_max]
	;jg .y_overflow

	mov al, [x_cur]
	cmp al, byte[x_cur_max]
	jge .x_overflow

.print:
	;movzx eax, [x_cur]
	;mov edx, 0
	;mov ebx, 8
	;mul ebx
	;mov [.x], eax

	;movzx eax, [y_cur]
	;mov edx, 0
	;mov ebx, 16
	;mul ebx
	;mov [.y], eax

	movzx ebx, [x_cur]
	shl ebx, 3
	movzx ecx, [y_cur]
	shl ecx, 4

	;mov ebx, [.x]
	;mov ecx, [.y]
	mov al, [.char]
	call put_char

	;add byte[x_cur], 1
	inc byte[x_cur]

	popa
	ret

.x_overflow:
	mov byte[x_cur], 0
	;add byte[y_cur], 1
	inc byte[y_cur]

	mov al, [y_cur]
	cmp al, byte[y_cur_max]
	jg .y_overflow
	jmp .print

.y_overflow:
	call scroll_screen_graphics

	jmp .print

.carriage:
	mov byte[x_cur], 0
	popa
	ret

.newline:
	mov byte[x_cur], 0
	;add byte[y_cur], 1
	inc byte[y_cur]

	mov al, [y_cur]
	cmp al, byte[y_cur_max]
	jg .newline_y_overflow

	popa
	ret

.newline_y_overflow:
	call scroll_screen_graphics

	popa
	ret

.backspace:
	cmp byte[x_cur], 0
	je .no

	;sub byte[x_cur], 1
	dec byte[x_cur]
	popa
	ret

.no:
	popa
	ret

.x			dd 0
.y			dd 0
.char			db 0

; print_string_transparent:
; Prints a string with transparent background in graphical mode
; In\	ESI = String offset
; In\	BX = X pos
; In\	CX = Y pos
; In\	EDX = Foreground color
; Out\	Nothing

print_string_transparent:
	mov [text_foreground], edx

	mov [.x], bx
	mov [.x2], bx
	mov [.y], cx
	mov [.y2], cx
	and ecx, 0xFFFF
	mov [dirty_line], ecx

.loop:
	lodsb
	cmp al, 0
	je .done

	cmp al, 13
	je .carriage

	cmp al, 10
	je .newline

.character:
	mov bx, [.x2]
	mov cx, [.y2]
	call put_char_transparent

	add word[.x2], 8
	jmp .loop

.carriage:
	mov bx, [.x]
	mov [.x2], bx
	jmp .loop

.newline:
	add word[.y2], 16
	jmp .loop

.done:
	call redraw_screen
	ret

.x			dw 0
.y			dw 0
.x2			dw 0
.y2			dw 0

; print_string_graphics:
; Prints a string with opaque background in graphical mode
; In\	ESI = String offset
; In\	BX = X pos
; In\	CX = Y pos
; In\	EDI = Background color
; In\	EDX = Foreground color
; Out\	Nothing

print_string_graphics:
	mov [text_background], edi
	mov [text_foreground], edx

	mov [.x], bx
	mov [.x2], bx
	mov [.y], cx
	mov [.y2], cx
	and ecx, 0xFFFF
	mov [dirty_line], ecx

.loop:
	lodsb
	cmp al, 0
	je .done

	cmp al, 13
	je .carriage

	cmp al, 10
	je .newline

.character:
	mov bx, [.x2]
	mov cx, [.y2]
	call put_char

	add word[.x2], 8
	jmp .loop

.carriage:
	mov bx, [.x]
	mov [.x2], bx
	jmp .loop

.newline:
	add word[.y2], 16
	jmp .loop

.done:
	call redraw_screen
	ret

.x			dw 0
.y			dw 0
.x2			dw 0
.y2			dw 0

; print_string_graphics_cursor:
; Prints an ASCIIZ string in graphical mode at cursor position
; In\	ESI = Offset of ASCIIZ string
; In\	ECX = Background color
; In\	EDX = Foreground color
; Out\	Nothing

print_string_graphics_cursor:
	pusha
	mov [text_background], ecx
	mov [text_foreground], edx

	movzx eax, [y_cur]
	shl eax, 4
	mov [dirty_line], eax

.loop:
	lodsb
	cmp al, 0
	je .done
	call put_char_cursor
	jmp .loop

.done:
	call redraw_screen
	popa
	ret

; scroll_screen_graphics:
; Scrolls the screen in graphics mode

scroll_screen_graphics:
	pusha

	mov byte[x_cur], 0
	mov al, [y_cur_max]
	mov byte[y_cur], al

	mov eax, [screen.bytes_per_line]
	shl eax, 4			; multiply by 16
	mov [.size_of_line], eax

	mov eax, [screen.size]
	sub eax, dword[.size_of_line]
	mov [.size], eax

	mov eax, 0
	mov ebx, 16
	call get_pixel_offset

	mov esi, edi
	mov edi, [screen.framebuffer]
	mov ecx, [.size]
	shr ecx, 7			; divide by 128

.loop:
	movdqa xmm0, [esi]
	movdqa xmm1, [esi+16]
	movdqa xmm2, [esi+32]
	movdqa xmm3, [esi+48]
	movdqa xmm4, [esi+64]
	movdqa xmm5, [esi+80]
	movdqa xmm6, [esi+96]
	movdqa xmm7, [esi+112]
	movdqa [edi], xmm0
	movdqa [edi+16], xmm1
	movdqa [edi+32], xmm2
	movdqa [edi+48], xmm3
	movdqa [edi+64], xmm4
	movdqa [edi+80], xmm5
	movdqa [edi+96], xmm6
	movdqa [edi+112], xmm7

	add esi, 128
	add edi, 128
	loop .loop

	mov eax, 0
	mov ebx, [screen.height]
	sub ebx, 16
	call get_pixel_offset

	mov ecx, [.size_of_line]
	shr ecx, 4

.clear_last_line:
	movdqa xmm0, dqword[.color]
	movdqa [edi], xmm0

	add edi, 16
	loop .clear_last_line

.done:
	mov byte[cursor_moved], 1
	mov dword[dirty_line], 0
	;call redraw_screen		; not doing this saves A LOT of performance!
	popa
	ret

align 32			; If the memory is not properly aligned, MOVDQA fails

.color				dq 0
				dq 0
.end				dd 0
.size_of_line			dd 0
.size				dd 0

; clear_screen:
; Clears the screen in graphical mode
; In\	EBX = Color
; Out\	Nothing

clear_screen:
	pusha
	mov [.color], ebx

	mov eax, [screen.height]
	mov ebx, [screen.bytes_per_line]
	mul ebx
	add eax, dword[screen.bytes_per_line]

	cmp dword[screen.bpp], 32
	jne .24

.32:
	;mov ebx, 4
	;mov edx, 0
	;div ebx
	shr eax, 2		; quick divide by 4

	mov ecx, eax

	mov edi, [screen.framebuffer]
	mov eax, [.color]
	rep stosd
	jmp .done

.24:
	mov ebx, 3
	mov edx, 0
	div ebx

	mov ecx, eax
	mov edi, [screen.framebuffer]

.24_work:
	mov eax, [.color]
	stosb
	shr eax, 8
	stosb
	shr eax, 8
	stosb
	loop .24_work

.done:
	mov eax, [.color]
	mov edi, scroll_screen_graphics.color
	stosd
	stosd
	stosd
	stosd

	mov byte[x_cur], 0
	mov byte[y_cur], 0

	mov dword[dirty_line], 0
	call redraw_screen
	popa
	ret

.color				dd 0

; draw_horz_line:
; Draws a horizontal line
; In\	EBX = Color
; In\	CX/DX = X/Y pos
; In\	SI = Length
; Out\	Nothing

draw_horz_line:
	pusha

	and ecx, 0xFFFF
	and edx, 0xFFFF
	mov [dirty_line], edx
	and esi, 0xFFFF

	mov [.color], ebx
	mov [.x], ecx
	mov [.y], edx
	mov [.length], esi

	movzx eax, cx
	movzx ebx, dx
	call get_pixel_offset

	mov [.offset], edi

	mov eax, [.length]
	mov ebx, [screen.bytes_per_pixel]
	mul ebx
	mov ebx, [.offset]
	add eax, ebx
	mov [.end_offset], eax

	mov edi, [.offset]

	cmp byte[screen.bpp], 32
	jne .24

.32:
	mov eax, [.color]
	stosd
	cmp edi, [.end_offset]
	jge .done
	jmp .32

.24:
	mov eax, [.color]
	stosb
	shr eax, 8
	stosb
	shr eax, 8
	stosb
	cmp edi, [.end_offset]
	jge .done
	jmp .24

.done:
	call redraw_screen
	popa
	ret

.color				dd 0
.x				dd 0
.y				dd 0
.length				dd 0
.offset				dd 0
.end_offset			dd 0

; fill_rect:
; Fills a rectangle
; In\	EBX = Color
; In\	CX = X pos
; In\	DX = Y pos
; In\	SI = Width
; In\	DI = Height

fill_rect:
	pusha
	mov [.color], ebx
	mov [.x], cx
	mov [.y], dx
	mov [.width], si
	mov [.height], di

	movzx edx, [.y]
	mov [dirty_line], edx

	movzx eax, word[.width]
	mov ebx, [screen.bytes_per_pixel]
	mul ebx
	mov [.size], eax

	mov ax, [.x]
	mov bx, [.y]
	call get_pixel_offset
	mov [.offset], edi

	mov dword[.row], 0

	cmp dword[screen.bpp], 32
	jne .24

.32:
	mov eax, [.size]
	;mov ebx, 4
	;mov edx, 0
	;div ebx
	shr eax, 2				; quick divide by 4
	mov [.size], eax

.32_loop:
	mov edi, [.offset]
	mov eax, [.color]
	mov ecx, [.size]
	rep stosd

	add dword[.row], 1
	movzx eax, word[.height]
	cmp eax, dword[.row]
	jl .done

	mov eax, [screen.bytes_per_line]
	add dword[.offset], eax
	;mov eax, [screen.bytes_per_pixel]
	;add dword[.offset], eax
	jmp .32_loop

.24:
	mov ecx, [.size]
	mov edi, [.offset]

.24_loop:
	mov eax, [.color]
	stosb
	shr eax, 8
	stosb
	shr eax, 8
	stosb

	sub ecx, 3
	cmp ecx, 0
	je .24_newline

	jmp .24_loop

.24_newline:
	add dword[.row], 1
	movzx eax, word[.height]
	cmp eax, dword[.row]
	jl .done

	mov eax, [screen.bytes_per_line]
	add dword[.offset], eax
	jmp .24

.done:
	call redraw_screen
	popa
	ret

.color				dd 0
.x				dw 0
.y				dw 0
.width				dw 0
.height				dw 0
.size				dd 0
.row				dd 0
.offset				dd 0

; alpha_blend_colors:
; Blends two colors
; In\	EAX = Source color
; In\	EBX = Destination color
; Out\	EAX = Blended color

alpha_blend_colors:
	;and eax, 0xFEFEFE
	;and ebx, 0xFEFEFE
	shr eax, 1
	shr ebx, 1
	and eax, 0x7F7F7F
	and ebx, 0x7F7F7F
	add eax, ebx

	ret

; alpha_draw_horz_line:
; Draws a horizontal line with alpha blending
; In\	EBX = Color
; In\	CX/DX = X/Y pos
; In\	SI = Length
; Out\	Nothing

alpha_draw_horz_line:
	pusha

	and ecx, 0xFFFF
	and edx, 0xFFFF
	mov [dirty_line], edx
	and esi, 0xFFFF

	mov [.color], ebx
	mov [.x], ecx
	mov [.y], edx
	mov [.length], esi

	movzx eax, cx
	movzx ebx, dx
	call get_pixel_offset

	mov [.offset], edi

	mov eax, [.length]
	mov ebx, [screen.bytes_per_pixel]
	mul ebx
	mov ebx, [.offset]
	add eax, ebx
	mov [.end_offset], eax

	mov edi, [.offset]

	cmp byte[screen.bpp], 32
	jne .24

.32:
	mov eax, [.color]
	mov ebx, dword[edi]
	call alpha_blend_colors
	stosd
	cmp edi, [.end_offset]
	jge .done
	jmp .32

.24:
	mov eax, [.color]
	mov ebx, dword[edi]
	and ebx, 0xFFFFFF
	call alpha_blend_colors
	stosb
	shr eax, 8
	stosb
	shr eax, 8
	stosb
	cmp edi, [.end_offset]
	jge .done
	jmp .24

.done:
	call redraw_screen
	popa
	ret

.color				dd 0
.x				dd 0
.y				dd 0
.length				dd 0
.offset				dd 0
.end_offset			dd 0

; alpha_fill_rect:
; Fills a rectangle with alpha blending
; In\	EBX = Color
; In\	CX = X pos
; In\	DX = Y pos
; In\	SI = Width
; In\	DI = Height

alpha_fill_rect:
	pusha
	mov [.color], ebx
	mov [.x], cx
	mov [.y], dx
	mov [.width], si
	mov [.height], di

	movzx edx, [.y]
	mov [dirty_line], edx

	movzx eax, word[.width]
	mov ebx, [screen.bytes_per_pixel]
	mul ebx
	mov [.size], eax

	mov ax, [.x]
	mov bx, [.y]
	call get_pixel_offset
	mov [.offset], edi

	mov dword[.row], 0

	cmp dword[screen.bpp], 32
	jne .24

.32:
	mov eax, [.size]
	;mov ebx, 4
	;mov edx, 0
	;div ebx
	shr eax, 2		; quick divide by 4
	mov [.size], eax

.32_stub:
	mov edi, [.offset]
	mov ecx, [.size]

.32_loop:
	mov eax, dword[edi]
	mov ebx, [.color]
	call alpha_blend_colors
	stosd

	dec ecx
	cmp ecx, 0
	je .32_newline
	jmp .32_loop

.32_newline:
	add dword[.row], 1
	movzx eax, word[.height]
	cmp eax, dword[.row]
	jl .done

	mov eax, [screen.bytes_per_line]
	add dword[.offset], eax
	jmp .32_stub

.24:
	mov edi, [.offset]
	mov ecx, [.size]

.24_loop:
	mov eax, dword[edi]
	and eax, 0xFFFFFF
	mov ebx, [.color]
	call alpha_blend_colors
	stosb
	shr eax, 8
	stosb
	shr eax, 8
	stosb

	sub ecx, 3
	cmp ecx, 0
	je .24_newline
	jmp .24_loop

.24_newline:
	add dword[.row], 1
	movzx eax, word[.height]
	cmp eax, dword[.row]
	jl .done

	mov eax, [screen.bytes_per_line]
	add dword[.offset], eax
	jmp .24

.done:
	call redraw_screen
	popa
	ret

.color				dd 0
.x				dw 0
.y				dw 0
.width				dw 0
.height				dw 0
.size				dd 0
.row				dd 0
.offset				dd 0

bmp_location			dd 0
bmp_signature			= 0x00
bmp_width			= 0x12
bmp_height			= 0x16
bmp_pixels			= 0x0A

; draw_image:
; Draws a BMP image
; In\	ESI = Pointer to image data
; In\	BX/CX = X/Y coordinates to draw image
; Out\	EAX = 0 on success, 1 if file is corrupt, 2 if image is too big to fit on screen

draw_image:
	mov [bmp_location], esi
	mov [.x], bx
	mov [.y], cx

	mov esi, [bmp_location]
	;mov eax, bmp_signature
	;add esi, eax				; there's no point in doing (add esi, 0), how could I be so stupid? -_-
	mov edi, .bmp_signature
	mov ecx, 2
	rep cmpsb				; verify BMP file is valid
	jne .corrupt

	; make sure image can fit on screen
	mov esi, [bmp_location]
	add esi, bmp_width
	movzx eax, word[.x]
	add eax, dword[esi]

	cmp eax, [screen.width]
	jg .too_big

	mov esi, [bmp_location]
	add esi, bmp_height
	movzx eax, [.y]
	add eax, dword[esi]

	cmp eax, [screen.height]
	jg .too_big

	movzx ebx, word[.x]
	movzx ecx, word[.y]

	cmp dword[screen.bpp], 32
	je display_bitmap_32bpp

	jmp display_bitmap_24bpp

.corrupt:
	mov eax, 1
	ret

.too_big:
	mov eax, 2
	ret

.bmp_signature		db "BM"
.x			dw 0
.y			dw 0

; display_bitmap_32bpp:
; Displays a 24-bit bitmap in 32-bit VESA mode
; In\	Nothing
; Out\	Nothing

display_bitmap_32bpp:
	mov [.x], ebx
	mov [.y], ecx
	mov [dirty_line], ecx

	mov esi, [bmp_location]
	mov eax, bmp_width
	add esi, eax
	mov eax, dword[esi]
	mov [.width], eax

	mov esi, [bmp_location]
	mov eax, bmp_height
	add esi, eax
	mov eax, dword[esi]
	mov [.height], eax

	mov eax, [.width]
	mov ebx, [.height]
	mul ebx
	mov ebx, 3					; 24 bpp is 3 bytes per pixel
	mul ebx

	mov [.size], eax

	; Now, EAX contains the number of bytes in the pixel area itself

	mov eax, [.width]
	mov ebx, 3
	mul ebx						; bytes per line

	mov [.bytes_per_line], eax

	mov eax, [.x]
	mov ebx, [.y]
	call get_pixel_offset

	mov [.offset], edi

	mov esi, [bmp_location]
	mov eax, bmp_pixels
	add esi, eax
	mov eax, dword[esi]

	mov esi, eax					; ESI now contains entry point of BMP pixels
	add esi, [bmp_location]
	mov [.entry], esi
	add esi, dword[.size]				; BMP files have the first pixel stored at the end of the file, not the beginning
	sub esi, 3					; therefore we start from the end
	mov edi, [.offset]
	mov ecx, [.size]
	mov dword[.byte], 0

.loop:
	mov al, byte[esi]				; blue
	stosb
	mov al, byte[esi+1]				; green
	stosb
	mov al, byte[esi+2]				; red
	stosb
	mov al, 0					; empty alpha component
	stosb

	sub esi, 3
	sub ecx, 3
	add dword[.byte], 3

	mov eax, [.bytes_per_line]
	cmp eax, dword[.byte]
	je .newline

	cmp ecx, 0
	je .done

	cmp esi, dword[.entry]
	jle .done

	jmp .loop

.newline:
	pusha
	add dword[.y], 1
	mov eax, [.x]
	mov ebx, [.y]
	call get_pixel_offset

	mov [.offset], edi

	popa
	mov edi, [.offset]
	mov dword[.byte], 0
	jmp .loop

.done:
	call redraw_screen
	mov eax, 0
	ret

.width			dd 0
.height			dd 0
.x			dd 0
.y			dd 0
.offset			dd 0
.bytes_per_line		dd 0
.byte			dd 0
.size			dd 0
.entry			dd 0

; display_bitmap_24bpp:
; Displays a 24-bit bitmap in 24-bit VESA mode
; In\	Nothing
; Out\	Nothing

display_bitmap_24bpp:
	mov [.x], ebx
	mov [.y], ecx
	mov [dirty_line], ecx

	mov esi, [bmp_location]
	mov eax, bmp_width
	add esi, eax
	mov eax, dword[esi]
	mov [.width], eax

	mov esi, [bmp_location]
	mov eax, bmp_height
	add esi, eax
	mov eax, dword[esi]
	mov [.height], eax

	mov eax, [.width]
	mov ebx, [.height]
	mul ebx
	mov ebx, 3					; 24 bpp is 3 bytes per pixel
	mul ebx

	mov [.size], eax

	; Now, EAX contains the number of bytes in the pixel area itself

	mov eax, [.width]
	mov ebx, 3
	mul ebx						; bytes per line

	mov [.bytes_per_line], eax

	mov eax, [.x]
	mov ebx, [.y]
	call get_pixel_offset

	mov [.offset], edi

	mov esi, [bmp_location]
	mov eax, bmp_pixels
	add esi, eax
	mov eax, dword[esi]

	mov esi, eax					; ESI now contains entry point of BMP pixels
	add esi, [bmp_location]
	mov [.entry], esi
	add esi, dword[.size]				; BMP files have the first pixel stored at the end of the file, not the beginning
	sub esi, 3
							; therefore we start from the end
	mov edi, [.offset]
	mov ecx, [.size]
	mov dword[.byte], 0

.loop:
	mov al, byte[esi]				; blue
	stosb
	mov al, byte[esi+1]				; green
	stosb
	mov al, byte[esi+2]				; red
	stosb

	sub esi, 3
	sub ecx, 3
	add dword[.byte], 3

	mov eax, [.bytes_per_line]
	cmp eax, dword[.byte]
	je .newline

	cmp ecx, 0
	je .done

	cmp esi, dword[.entry]
	jle .done

	jmp .loop

.newline:
	pusha
	add dword[.y], 1
	mov eax, [.x]
	mov ebx, [.y]
	call get_pixel_offset

	mov [.offset], edi

	popa
	mov edi, [.offset]
	mov dword[.byte], 0
	jmp .loop

.done:
	call redraw_screen
	mov eax, 0
	ret

.width			dd 0
.height			dd 0
.x			dd 0
.y			dd 0
.offset			dd 0
.bytes_per_line		dd 0
.byte			dd 0
.size			dd 0
.entry			dd 0





