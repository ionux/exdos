
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/ahci.asm							;;
;; Serial ATA (AHCI) Disk Driver					;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

is_there_ahci				db 0

ahci_bus				db 0
ahci_device				db 0
ahci_function				db 0

; ahci_init:
; Initalizes the AHCI controller

ahci_init:
	cli

	; First, let's scan the PCI bus for an AHCI controller
	mov ah, 1		; mass storage device
	mov al, 6		; SATA controller
	mov bl, 1		; AHCI interface
	call pci_get_device

	cmp ax, 0xFFFF
	je .no_ahci

	cmp bl, 0xFF
	je .no_ahci

	mov [ahci_bus], al
	mov [ahci_device], ah
	mov [ahci_function], bl

	ret

.no_ahci:
	ret

.no_ahci_msg			db "NO SATA AHCI CONTROLLERS FOUND",0
.found_sata			db "SATA AHCI DRIVE: ",0

