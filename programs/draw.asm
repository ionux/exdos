
;; 
;; Simple Drawing Program for ExDOS
;; 

use32
org 0x8000000				; 128 MB

include			"programs/kapi.asm"

file_header:
	.magic			db "ExDOS"
	.version		db 1
	.type			db 0
	.program_size		dd end_of_file - file_header
	.entry_point		dd main
	.manufacturer		dd 0
	.program_name		dd 0
	.driver_type		dw 0
	.driver_hardware	dd 0
	.reserved		dd 0

main:
	mov ebx, 0xFFFFFF				; clear the screen white
	os_api clear_screen

	os_api get_screen_info
	mov [width], eax
	mov [height], ebx

	mov ebx, 0x7F7F7F
	mov cx, 0
	mov dx, 0
	mov esi, [width]
	mov edi, 16
	os_api fill_rect

	mov esi, title					; print the title
	mov bx, 0
	mov cx, 0
	mov edx, 0xFFFFFF
	mov edi, 0x7F7F7F
	os_api print_string

	mov bx, 8
	mov cx, 8
	mov edx, 0x000000
	os_api set_mouse_cursor				; make the mouse cursor resolution 8x8 and color black
	os_api show_mouse_cursor			; make sure the cursor is shown

	mov ebx, 0x7F7F7F
	mov cx, 0
	mov edx, [height]
	sub edx, 64
	mov [bottom_screen], edx
	mov esi, [width]
	mov edi, 64
	os_api fill_rect

	mov eax, [height]
	sub eax, 36
	mov [button_y], eax

	mov esi, red_text
	mov bx, 16
	mov ecx, [button_y]
	mov edx, 0xFFFFFF
	mov edi, 0xFF0000
	os_api print_string

	mov esi, green_text
	mov bx, 72
	mov ecx, [button_y]
	mov edx, 0xFFFFFF
	mov edi, 0x00FF00
	os_api print_string

	mov esi, blue_text
	mov bx, 144
	mov ecx, [button_y]
	mov edx, 0xFFFFFF
	mov edi, 0x0000FF
	os_api print_string

	mov esi, clear_text
	mov bx, 224
	mov ecx, [button_y]
	mov edx, 0
	mov edi, 0xC0C0C0
	os_api print_string

	mov esi, exit_text
	mov bx, 296
	mov ecx, [button_y]
	mov edx, 0
	mov edi, 0xC0C0C0
	os_api print_string

wait_for_click:
	os_api get_mouse_status

	test ecx, 1				; left button
	jz wait_for_click

clicked:
	mov [mouse_x], eax
	mov [mouse_y], ebx

	mov eax, [mouse_y]
	cmp eax, 16
	jl wait_for_click

	cmp eax, [bottom_screen]
	jge button_click

	mov ebx, [current_color]
	mov ecx, [mouse_x]
	mov edx, [mouse_y]
	mov esi, 8
	mov edi, 8
	os_api fill_rect

	jmp wait_for_click

button_click:
	mov eax, [mouse_x]
	cmp eax, 296
	jge check_exit

	cmp eax, 224
	jge check_clear

	cmp eax, 144
	jge check_blue

	cmp eax, 72
	jge check_green

	cmp eax, 16
	jge check_red

	jmp wait_for_click

check_exit:
	mov eax, [mouse_x]

	cmp eax, 344
	jle .x_good

	jmp wait_for_click

.x_good:
	mov eax, [mouse_y]
	cmp eax, [button_y]
	jl wait_for_click

	mov ebx, [button_y]
	add ebx, 16
	mov eax, [mouse_y]
	cmp eax, ebx
	jg wait_for_click

	jmp exit

exit:
	os_api get_screen_info
	os_api move_cursor_graphics			; move cursor to the bottom of the screen

	mov esi, newline
	os_api print_string_cursor
	ret

check_clear:
	mov eax, [mouse_x]

	cmp eax, 280
	jle .x_good

	jmp wait_for_click

.x_good:
	mov eax, [mouse_y]
	cmp eax, [button_y]
	jl wait_for_click

	mov ebx, [button_y]
	add ebx, 16
	mov eax, [mouse_y]
	cmp eax, ebx
	jg wait_for_click

	jmp main

check_blue:
	mov eax, [mouse_x]

	cmp eax, 240
	jle .x_good

	jmp wait_for_click

.x_good:
	mov eax, [mouse_y]
	cmp eax, [button_y]
	jl wait_for_click

	mov ebx, [button_y]
	add ebx, 16
	mov eax, [mouse_y]
	cmp eax, ebx
	jg wait_for_click

	mov dword[current_color], 0x0000FF
	jmp wait_for_click

check_green:
	mov eax, [mouse_x]

	cmp eax, 128
	jle .x_good

	jmp wait_for_click

.x_good:
	mov eax, [mouse_y]
	cmp eax, [button_y]
	jl wait_for_click

	mov ebx, [button_y]
	add ebx, 16
	mov eax, [mouse_y]
	cmp eax, ebx
	jg wait_for_click

	mov dword[current_color], 0x00FF00
	jmp wait_for_click

check_red:
	mov eax, [mouse_x]

	cmp eax, 56
	jle .x_good

	jmp wait_for_click

.x_good:
	mov eax, [mouse_y]
	cmp eax, [button_y]
	jl wait_for_click

	mov ebx, [button_y]
	add ebx, 16
	mov eax, [mouse_y]
	cmp eax, ebx
	jg wait_for_click

	mov dword[current_color], 0xFF0000
	jmp wait_for_click

width				dd 0
height				dd 0
button_y			dd 0
bottom_screen			dd 0
mouse_x				dd 0
mouse_y				dd 0

newline				db 10,0
title				db " ExDOS Draw",0
clear_text			db " Clear ",0
exit_text			db " Exit ",0
red_text			db " RED ",0
green_text			db " GREEN ",0
blue_text			db " BLUE ",0
current_color			dd 0xFF0000			; red is default

align 4096
end_of_file:
