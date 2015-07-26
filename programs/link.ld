OUTPUT_FORMAT("binary")
OUTPUT_ARCH("i386")
ENTRY(main)
SECTIONS
{
	. = 0x8000000;
	.header : {
		*(.header)
		. = ALIGN(4096);
	}
	.text : {
		*(.text)
		. = ALIGN(4096);
	}
	.data : {
		*(.data)
		*(.rodata)
		. = ALIGN(4096);
	}
	__bss_start = .;
	.bss : {
		bss = .; _bss = .; __bss = .;
		*(.bss);
	}
	end = .; _end = .; __end = .;
}


