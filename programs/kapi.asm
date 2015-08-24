
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
hide_text_cursor		= 17
show_text_cursor		= 18

; Keyboard routines
get_char_wait			= 19
get_char_no_wait		= 20
get_string			= 21

; String-based routines
get_string_size			= 22
chomp_string			= 23
int_to_string			= 24
hex_byte_to_string		= 25
hex_word_to_string		= 26
hex_dword_to_string		= 27
compare_strings			= 28
replace_byte_in_string		= 29

; Power-based routines
reboot				= 30
shutdown			= 31

; Time-based routines
get_time_24			= 32
get_time_12			= 33
get_time_string_24		= 34
get_time_string_12		= 35
get_date			= 36
get_date_string_am		= 37
get_date_string_me		= 38
get_long_date_string		= 39

; Mouse routines
get_mouse_status		= 40
show_mouse_cursor		= 41
hide_mouse_cursor		= 42
set_mouse_cursor		= 43

; Disk I/O routines
hdd_get_info			= 44
get_filenames_string		= 45
get_file_size			= 46
load_file			= 47

macro os_api function_number {
	mov eax, function_number
	call 0x520
}


