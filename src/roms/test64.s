; Test program for "Fast" PDIP 6502 prototype
;
; This version is for the 64K RAM version, which has very little ROM:
;
;   $0000-$7fff  - RAM lo
;   $8000-$fdff  - RAM hi
;   $fe00-$feff  - ROM
;   $ff00-$ffbf  - I/O; $ff70 in particular is connected to a debug output port
;   $ffc0-$ffff  - ROM - including the vectors
;
; It is possible to run code from ROM but RAM has faster access times and so ultimately the ROM will 
; start by copying itself into RAM.  However it will be useful for some test cases to run directly
; from ROM.
;
; We don't have a good way to select which program to run, so it's hard-coded.


DEBUGPORT = $ff70

SER_TDR = $ff60
SER_STAT = $ff50 
SER_RDR = $ff40

zp_printptr = $80


* = $ROMBASE

	.dsb $fe00-*, $00

#include "tests/test64-ramtest.s"

#print $ff00-*
	.dsb $ff00-*, $00

ioports:
	.dsb $c0, $00

.(

&printchar:
	sta DEBUGPORT

	; wait for TDR empty
	bit SER_STAT : bpl printchar

	; Write the character
	sta SER_TDR

	rts

&getchar:
	; Wait for RDR full
	bit SER_STAT : bvc getchar

	; Read the character
	lda SER_RDR

	rts

&printimm:
	pha : phx

	tsx
	clc
	lda $103,x : sta zp_printptr
	lda #$fe : sta zp_printptr+1

printmsgloop:
	inc zp_printptr
	lda (zp_printptr)
	beq endprintmsgloop
	jsr printchar
	bra printmsgloop

endprintmsgloop:

	lda zp_printptr : sta $103,x

	plx : pla

	rts
.)

#print $fffa-*
	.dsb $fffa-*, $00

vectors:
	.word irq
	.word entry
	.word irq

