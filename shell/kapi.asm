
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kapi.asm								;;
;; Kernel API for Programs						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

; Core routines
execute_program			= 0
get_memory_info			= 1
get_kernel_info			= 2
;run_v8086			= 3

; Display routines
clear_screen			= 4
print_string_cursor		= 5
print_string			= 6
print_string_transparent	= 7
move_cursor_graphics		= 8
put_pixel			= 9
draw_horz_line			= 10
fill_rect			= 11
alpha_draw_horz_line		= 12
alpha_fill_rect			= 13
alpha_blend_colors		= 14
draw_image			= 15

; Keyboard routines
get_char_wait			= 16
get_char_no_wait		= 17
get_string			= 18

; String-based routines
get_string_size			= 19
chomp_string			= 20
int_to_string			= 21
hex_byte_to_string		= 22
hex_word_to_string		= 23
hex_dword_to_string		= 24
compare_strings			= 25

macro os_api function_number {
	mov eax, function_number
	call 0x520
}

