; Klaus Dormann's 6502 test

SERIAL_TDR = $ff60
SERIAL_STAT = $ff50
SERIAL_RDR = $ff40

; Note that the test suite uses some lower addresses
printptr = $80

srcptr = 0
destptr = 2

phase = 4

ramdest = $400
ramentry = $400

pchar:
	jmp printchar

gchar:
	bra upload

entry:
	ldx #$ff : txs
	cli

	stx phase

	; Send one character to kick things off
	lda #12
	sta SERIAL_TDR

upload:
	ldx #$ff : txs

.(
	inc phase : lda phase : cmp #2 : bne nowrap
	stz phase
nowrap:
.)

	jsr printimm
	.byte 13, 10, 10, "==> Phase ", 0
	lda phase : clc : adc #48 : jsr printchar

	jsr printimm
	.byte 13, 10, 10, "Copying program to RAM", 0

	ldx phase
	lda payloadaddrlo,x : sta srcptr
	lda payloadaddrhi,x : sta srcptr+1
	lda #<ramdest : sta destptr
	lda #>ramdest : sta destptr+1
	lda payloadsizehi,x : tax
	ldy #0
copyloop:
	lda (srcptr),y : sta (destptr),y
	iny : bne copyloop
	inc srcptr+1 : inc destptr+1
	lda #'.' : jsr printchar
	dex : bne copyloop

	lda #$f9 : sta DEBUGPORT

	lda #10 : jsr printchar

	jsr printimm
	.byte 13, 10, 10, "Executing program", 13, 10, "---", 13, 10, 0

	jmp ramentry 

irq:
	pha
	lda #$fd : sta DEBUGPORT
	pla

	jsr printimm
	.byte "IRQ ", 0

	rti

printchar:
#if 0
	; wait for TDR empty
	bit SERIAL_STAT : bpl printchar
#else
	; Wait for one byte = 10 bits * 1/121212 seconds per bit.  At 4MHz I/O clock that's 330 CPU cycles at best,
	; in fact significantly fewer because the CPU slows down below the I/O clock in order to get in sync with it.
	;
	; Each Y-loop costs 5 cycles, minus one at the end, so we need to loop 66 times, and the one doesn't matter
	; because we are overestimating by a large margin here anyway - probably at least 2x
	phy
	ldy #66
.(
printcharwait:
	dey : bne printcharwait
	ply
.)
#endif

	ora #$80
	sta DEBUGPORT
	and #$7f

	; Write the character
	sta SERIAL_TDR

	sta DEBUGPORT

	rts

getchar:
	; wait for RDR full
	bit SERIAL_STAT : bvc getchar

	; Read the character
	lda SERIAL_RDR
	rts

printimm:
	pha : phx : phy

	tsx
	clc
	lda $104,x : adc #1 : sta printptr
	lda $105,x : adc #0 : sta printptr+1

	jsr printmsgloop

	lda printptr : sta $104,x
	lda printptr+1 : sta $105,x

	ply : plx : pla
	rts

printmsg:
	stx printptr
	sty printptr+1

printmsgloop:
	ldy #0
	lda (printptr),y
	beq endprintmsgloop
	jsr printchar
	inc printptr
	bne printmsgloop
	inc printptr+1
	bra printmsgloop

endprintmsgloop:
	rts

payloadaddrlo:
	.byte <payload0, <payload1
payloadaddrhi:
	.byte >payload0, >payload1
payloadsizehi:
	.byte >(payload0size+255), >(payload1size+255)


payload0:
	.bin 0,0,"../../6502_65C02_functional_tests/out/6502_functional_test.bin"
payload0size = *-payload0
#print payload0size

payload1:
	.bin 0,0,"../../6502_65C02_functional_tests/out/65C02_extended_opcodes_test.bin"
payload1size = *-payload1
#print payload1size

	.byt 0,255

