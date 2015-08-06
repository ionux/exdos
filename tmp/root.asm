use32

filename	db			"kernel  sys"
lba		dd			200
size_sectors	dd			80
size_bytes	dd			12288
time		db			11		; hour
		db			36		; minute
date		db 			20		; day
		db			6		; month
		dw 			2015		; year

		db			"init    exe"
		dd			700
		dd			8
		dd			16384
		db			11		; hour
		db			36		; minute
		db 			20		; day
		db			6		; month
		dw 			2015		; year

		db			"hello   exe"
		dd			800
		dd			1
		dd			16384
		db			11		; hour
		db			36		; minute
		db 			20		; day
		db			6		; month
		dw 			2015		; year

		db			"wp      bmp"
		dd			1024
		dd			2813
		dd			1440122
		db			11		; hour
		db			36		; minute
		db 			20		; day
		db			6		; month
		dw 			2015		; year



