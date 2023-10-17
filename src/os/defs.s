; Various constants and globals for the OS

#ifdef PLDSERIAL

SER_RDR = $ff00
SER_TDR = SER_RDR
SER_STAT = $ff01

#else

SER_RDR = $ff40
SER_TDR = $ff60
SER_STAT = $ff50

#endif

SD_DATA = $ff10
SD_SETCS = $ff11
SD_STAT = $ff11

VIA_BASE = $ff20

DEBUGPORT = $ff70


zp_serial_in_head = $80
zp_serial_in_tail = $81
zp_serial_error = $82
zp_stray_interrupts = $83
zp_printptr = $84         ; 2 bytes
zp_serial_out_head = $86
zp_serial_out_tail = $87
zp_sd_currentsector = $88
zp_sd_address = $8c       ; 2 bytes

zp_fat32_variables = $90  ; 24 bytes

zp_scratch = $f0

serial_in_buffer = $300
serial_out_buffer = $400
fat32_workspace = $500

