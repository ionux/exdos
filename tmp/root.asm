entries				dd 511			; number of entries in directory
							; 511 and not 512 because the first entry is always reserved for hierarchy support
				times 32 - ($-$$) db 0

filename			db "kernel  sys"
reserved1			db 0
lba_sector			dd 200
size_sectors			dd 100
size_bytes			dd 100*512
time				db 8
				db 53
date				db 7
				db 8
				dw 2015
reserved2			dw 0

				db "init    exe"
				db 0
				dd 500
				dd 12
				dd 12*512
				db 8
				db 53
				db 7
				db 8
				dw 2015
				dw 0

				db "hello   exe"
				db 0
				dd 600
				dd 1
				dd 1*512
				db 8
				db 53
				db 7
				db 8
				dw 2015
				dw 0

				db "hello2  exe"
				db 0
				dd 602
				dd 1
				dd 1*512
				db 8
				db 53
				db 7
				db 8
				dw 2015
				dw 0


				db "draw    exe"
				db 0
				dd 650
				dd 6
				dd 6*512
				db 8
				db 53
				db 7
				db 8
				dw 2015
				dw 0

				db "echo    exe"
				db 0
				dd 670
				dd 1
				dd 1*512
				db 8
				db 53
				db 7
				db 8
				dw 2015
				dw 0

				db "heaptestexe"
				db 0
				dd 671
				dd 1
				dd 1*512
				db 8
				db 53
				db 7
				db 8
				dw 2015
				dw 0


				db "cat     exe"
				db 0
				dd 672
				dd 1
				dd 1*512
				db 8
				db 53
				db 7
				db 8
				dw 2015
				dw 0

				db "imgview exe"
				db 0
				dd 673
				dd 1
				dd 1*512
				db 8
				db 53
				db 7
				db 8
				dw 2015
				dw 0

				db "image   bmp"
				db 0
				dd 674
				dd 2813
				dd 2813*512
				db 8
				db 53
				db 7
				db 8
				dw 2015
				dw 0
