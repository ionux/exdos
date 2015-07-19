
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/pcie.asm							;;
;; PCI Express Enumerator						;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; TO-DO: Implement PCI-E

use32

is_there_pcie			db 0

; init_pcie:
; Initializes PCI-E bus

init_pcie:
	mov esi, .mcfg
	call acpi_find_table			; find the MCFG ACPI table

	cmp eax, 0
	jne .no_pcie

	mov byte[is_there_pcie], 1
	ret

.no_pcie:
	mov byte[is_there_pcie], 0
	mov byte[x_cur], 2
	mov byte[y_cur], 9

	mov esi, .no_pcie_msg
	mov ecx, 0xC0C0C0
	mov edx, 0
	call print_string_graphics_cursor

	call init_pci				; use legacy PCI as a fallback method

	ret

.no_pcie_msg				db "PCI-E BUS NOT FOUND.",0
.mcfg					db "MCFG"



