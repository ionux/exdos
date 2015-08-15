
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
kdebug_get_location		= 3

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
get_screen_info			= 16

; Keyboard routines
get_char_wait			= 17
get_char_no_wait		= 18
get_string			= 19

; String-based routines
get_string_size			= 20
chomp_string			= 21
int_to_string			= 22
hex_byte_to_string		= 23
hex_word_to_string		= 24
hex_dword_to_string		= 25
compare_strings			= 26

; Power-based routines
reboot				= 27
shutdown			= 28

; Time-based routines
get_time_24			= 29
get_time_12			= 30
get_time_string_24		= 31
get_time_string_12		= 32
get_date			= 33
get_date_string_am		= 34
get_date_string_me		= 35
get_long_date_string		= 36

; Mouse routines
get_mouse_status		= 37
show_mouse_cursor		= 38
hide_mouse_cursor		= 39
set_mouse_cursor		= 40

macro os_api function_number {
	mov eax, function_number
	call 0x520
}

