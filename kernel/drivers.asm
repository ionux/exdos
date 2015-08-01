
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;									;;
;; ExDOS -- Extensible Disk Operating System				;;
;; Version 0.1 pre alpha						;;
;; Copyright (C) 2015 by Omar Mohammad, all rights reserved.		;;
;;									;;
;; kernel/drivers.asm							;;
;; Drivers Interface							;;
;;									;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use32

is_driver_running			db 0

; load_driver:
; Loads a driver into memory
; In\	ESI = Driver file name
; Out\	EAX = 0 on success, 1 if file not found, 2 if program is corrupt/not a driver, 3 if driver hardware doesn't exist
; Out\	Other return codes to be defined by driver developers.

load_driver:

; driver_api:
; Driver API entry point
; In\	EAX = Function number
; In\	All other registers depend on function
; Out\	All registers = depends on function

driver_api:
