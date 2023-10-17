; Klaus Dormann's 6502 test

SERIALPORT = $ff60

VIA_BASE = $ff20

VIA_PORTB = VIA_BASE+0
VIA_PORTA = VIA_BASE+1
VIA_DDRB = VIA_BASE+2
VIA_DDRA = VIA_BASE+3
VIA_T1CL = VIA_BASE+4
VIA_T1CH = VIA_BASE+5
VIA_T1LL = VIA_BASE+6
VIA_T1LH = VIA_BASE+7
VIA_T2CL = VIA_BASE+8
VIA_T2CH = VIA_BASE+9
VIA_SR = VIA_BASE+10
VIA_ACR = VIA_BASE+11
VIA_PCR = VIA_BASE+12
VIA_IFR = VIA_BASE+13
VIA_IER = VIA_BASE+14
VIA_PORTANH = VIA_BASE+15


; Note that the test suite uses some lower addresses
printptr = $80

srcptr = 0
destptr = 2

ramdest = $400
ramentry = $400

pchar:
	jmp printchar

entry:
	ldx #$ff : txs
	cli

	; Configure VIA T1 to tell us how often we can send characters
	
	; Set T1 to continuous mode, no PB7 output
	lda #$40 : sta VIA_ACR

	; The bit rate is 139 VIA cycles, so the total time for a byte is 1390 cycles; we round that up a bit here
	lda #<1400 : sta VIA_T1CL
	lda #>1400 : sta VIA_T1CH

	; Print a message
	jsr printimm
	.byte 12, "Waiting for PB6 high...", 0

	lda #$00 : sta VIA_PORTB
	lda #$80 : sta VIA_DDRB

waitinputloop:
	bit VIA_PORTB : bvc waitinputloop

	; Print a message
	jsr printimm
	.byte 13, 10, 10, "Copying program to RAM", 0

	lda #<payload : sta srcptr
	lda #>payload : sta srcptr+1
	lda #<ramdest : sta destptr
	lda #>ramdest : sta destptr+1
	ldx #>(payloadsize+255)
	ldy #0
copyloop:
	lda (srcptr),y : sta (destptr),y
	iny : bne copyloop
	inc 1 : inc 3
	lda #'.' : jsr printchar
	dex : bne copyloop

	lda #$f9 : sta DEBUGPORT

	lda #10 : jsr printchar

	jsr printimm
	.byte 13, 10, 10, "Executing program", 13, 10, "---", 13, 10, 0

	;lda #0 : ;sta VIA_PORTB
	;tax : ;tay
wait:
	;dex : ;bne wait
	;dey : ;bne wait

	;lda #$ff : ;sta VIA_PORTB

	jmp ramentry 

irq:
	pha
	lda #$fd : sta DEBUGPORT
	pla

	jsr printimm
	.byte "IRQ ", 0

	rti

printchar:
	; Wait for T1
	bit VIA_IFR : bvc printchar

	; Write the character
	sta SERIALPORT
	sta DEBUGPORT

	pha
	; Start the timer for the next character
	lda #>1400 : sta VIA_T1CH
	pla
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

payload:
;	.bin 0,0,"../../6502_65C02_functional_tests/out/6502_functional_test.bin"
	.bin 0,0,"../../6502_65C02_functional_tests/out/65C02_extended_opcodes_test.bin"

payloadsize = *-payload
#print payloadsize

