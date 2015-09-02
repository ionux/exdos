
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/pci.asm							;;
;; PCI Bus Enumerator							;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Functions:
; init_pci
; pci_read_dword
; pci_write_dword
; pci_set_irq
; pci_get_device

use32

is_there_pci			db 0

; init_pci:
; Initializes the legacy PCI Bus

init_pci:
	call go16

use16

	mov eax, 0xB101			; check for PCI BIOS
	mov edi, 0
	int 0x1A
	jc .no_pci			; if there is no PCI BIOS, there may or may not be a PCI bus installation
					; just to be safe, we'll throw an error if PCI BIOS is not supported

	cmp ah, 0
	jne .no_pci

	cmp edx, 0x20494350
	jne .no_pci

	test al, 1			; make sure PCI supports the 32-bit I/O mechanism (port 0xCF8)
	jz .no_pci

	mov [.major], bh
	mov [.minor], bl

	mov byte[is_there_pci], 1
	call go32

use32

	mov esi, .debug_msg1
	call kdebug_print

	mov al, [.major]
	call bcd_to_int
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg2
	call kdebug_print_noprefix

	mov al, [.minor]
	call bcd_to_int
	call int_to_string
	call kdebug_print_noprefix

	mov esi, .debug_msg3
	call kdebug_print_noprefix

	ret

use16

.no_pci:
	call go32

use32

	mov esi, .no_pci_msg
	call kdebug_print

	ret

.no_pci_msg			db "pci: PCI BIOS is not present, assuming PCI is not present either...",10,0
.debug_msg1			db "pci: PCI BIOS v",0
.debug_msg2			db ".",0
.debug_msg3			db " present.",10,0
.major				db 0
.minor				db 0

; pci_read_dword:
; Reads a DWORD from the PCI bus
; In\	AL = Bus number
; In\	AH = Device number
; In\	BL = Function
; In\	BH = Offset
; Out\	EAX = DWORD from PCI bus

pci_read_dword:
	mov [.bus], al
	mov [.slot], ah
	mov [.function], bl
	mov [.offset], bh

	mov eax, 0
	movzx ebx, [.bus]
	shl ebx, 16
	or eax, ebx
	movzx ebx, [.slot]
	shl ebx, 11
	or eax, ebx
	movzx ebx, [.function]
	shl ebx, 8
	or eax, ebx
	movzx ebx, [.offset]
	and ebx, 0xFC
	or eax, ebx
	or eax, 0x80000000

	call iowait
	mov edx, 0xCF8
	out dx, eax

	call iowait
	mov edx, 0xCFC
	in eax, dx

	call iowait
	mov edx, 0
	ret

.tmp				dd 0
.bus				db 0
.function			db 0
.slot				db 0
.offset				db 0

; pci_write_dword:
; Writes a DWORD to the PCI bus
; In\	AL = Bus number
; In\	AH = Device number
; In\	BL = Function
; In\	BH = Offset
; In\	ECX = DWORD to write
; Out\	Nothing

pci_write_dword:
	mov [.bus], al
	mov [.slot], ah
	mov [.func], bl
	mov [.offset], bh
	mov [.dword], ecx

	mov eax, 0
	mov ebx, 0
	mov al, [.bus]
	shl eax, 16
	mov bl, [.slot]
	shl ebx, 11
	or eax, ebx
	mov ebx, 0
	mov bl, [.func]
	shl ebx, 8
	or eax, ebx
	mov ebx, 0
	mov bl, [.offset]
	and ebx, 0xFC
	or eax, ebx
	mov ebx, 0x80000000
	or eax, ebx

	call iowait
	mov edx, 0xCF8
	out dx, eax

	call iowait
	mov eax, [.dword]
	mov edx, 0xCFC
	out dx, eax

	call iowait
	mov edx, 0
	ret

.dword				dd 0
.tmp				dd 0
.bus				db 0
.func				db 0
.slot				db 0
.offset				db 0

; pci_set_irq:
; Sets the IRQ to be used by a PCI device
; In\	AL = Bus number
; In\	AH = Device number
; In\	BL = Function number
; In\	BH = IRQ to use (0xFF to disable IRQ)
; Out\	Nothing

pci_set_irq:
	mov [.bus], al
	mov [.device], ah
	mov [.function], bl
	mov [.irq], bh
	mov bh, 0x3C
	call pci_read_dword		; read the PCI configuration

	and eax, 0xFFFFFF00		; clear interrupt 
	movzx ebx, [.irq]
	or eax, ebx			; and set the IRQ to be used

	mov ecx, eax
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]
	mov bh, 0x3C
	call pci_write_dword		; write the modified PCI configuration

	ret

.bus				db 0
.device				db 0
.function			db 0
.irq				db 0

; pci_get_device_class:
; Gets the bus and device number of a PCI device from the class codes
; In\	AH = Class code
; In\	AL = Subclass code
; In\	BL = Prog IF
; Out\	AL = Bus number (0xFF if invalid)
; Out\	AH = Device number (0xFF if invalid)
; Out\	BL = Function number (0xFF if invalid)

pci_get_device_class:
	mov [.class], ax
	mov [.prog_if], bl

	mov byte[.bus], 0
	mov byte[.device], 0
	mov byte[.function], 0

.find_device:
	; Now, we'll search every function of every device on every bus
	; This does have a slight performance penalty, but we usually search for PCI device on bootup and driver initialization only.
	; So it's no problem. :)

	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]
	mov bh, 8
	call pci_read_dword

	mov [.tmp], eax
	mov eax, [.tmp]
	shr eax, 8

	cmp al, byte[.prog_if]		; correct Prog IF?
	jne .next

	mov eax, [.tmp]

	shr eax, 16
	cmp ax, word[.class]		; correct class?
	jne .next

	; if we make it here, we've found the correct device
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]
	and eax, 0xFFFF
	and ebx, 0xFF

	ret

.next:
	add byte[.function], 1
	cmp byte[.function], 0xFF
	je .next_device
	jmp .find_device

.next_device:
	mov byte[.function], 0
	add byte[.device], 1
	cmp byte[.device], 0xFF
	je .next_bus
	jmp .find_device

.next_bus:
	mov byte[.device], 0
	add byte[.bus], 1
	cmp byte[.bus], 0xFF
	je .device_not_found
	jmp .find_device

.device_not_found:
	; if we make it here, then such device doesn't exist.
	mov eax, 0xFFFF
	mov ebx, 0xFF
	ret

.class				dw 0
.prog_if			db 0
.tmp				dd 0
.bus				db 0
.device				db 0
.function			db 0

; pci_get_device_vendor:
; Gets the bus and device and function of a PCI device from the vendor and device ID
; In\	AX = Vendor ID
; In\	BX = Device ID
; Out\	AL = Bus number (0xFF if invalid)
; Out\	AH = Device number (0xFF if invalid)
; Out\	BL = Function number (0xFF if invalid)

pci_get_device_vendor:
	mov [.vendor_id], ax
	mov [.device_id], bx

	mov byte[.bus], 0
	mov byte[.device], 0
	mov byte[.function], 0

.find_device:
	; We'll search every function of every device on every bus...
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]
	mov bh, 0
	call pci_read_dword

	mov [.data], eax

	mov eax, [.data]
	cmp ax, word[.vendor_id]
	jne .next_function

	shr eax, 16
	cmp ax, word[.device_id]
	jne .next_function

	jmp .done

.next_function:
	add byte[.function], 1
	cmp byte[.function], 0xFF
	je .next_device
	jmp .find_device

.next_device:
	mov byte[.function], 0
	add byte[.device], 1
	cmp byte[.device], 0xFF
	je .next_bus
	jmp .find_device

.next_bus:
	mov byte[.device], 0
	add byte[.bus], 1
	cmp byte[.bus], 0xFF
	je .error
	jmp .find_device

.done:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]
	ret

.error:
	mov ax, 0xFFFF
	mov bl, 0xFF
	ret

.vendor_id			dw 0
.device_id			dw 0
.data				dd 0
.bus				db 0
.device				db 0
.function			db 0



