; Serial output test using buffer and polling serial status register, rather than VIA

SERIAL_TDR = $ff60
SERIAL_STAT = $ff50


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


zp_printptr = $80


entry:
	ldx #$ff : txs

	ldy #payloadsize
copyloop:
	lda payload-1,y : sta ramcodebase-1,y
	dey : bne copyloop

	lda #$f9 : sta DEBUGPORT

	jmp ramentry

irq:
	pha
	lda #$fd : sta DEBUGPORT
	pla
	rti

payload:

* = $200

ramcodebase:

ramentry:

	; In case TDRE got initialized unset, let's output one character directly,
	; without waiting for it, to ensure that it does get set now
	lda #12 : sta SERIAL_TDR

	; Print some characters
	lda #65 : jsr printchar
	lda #90 : jsr printchar
	lda #13 : jsr printchar
	lda #10 : jsr printchar

	; Print a whole message
	ldx #<message
	ldy #>message
	jsr printmsg

	; Print a message inlined in the code
	jsr printimm
	.byte "world!", 13, 10, 0

stop:
	bra stop

message:
	.byte "Hello ", 0

printchar:
	; Wait for TDRE
	bit SERIAL_STAT : bpl printchar

	; Write the character
	sta SERIAL_TDR
	sta DEBUGPORT
	rts

printimm:
	pha : phx

	tsx
	clc
	lda $103,x : adc #1 : sta zp_printptr
	lda $104,x : adc #0 : sta zp_printptr+1

	jsr printmsgloop

	lda zp_printptr : sta $103,x
	lda zp_printptr+1 : sta $104,x

	plx : pla
	rts

printmsg:
	stx zp_printptr
	sty zp_printptr+1

printmsgloop:
	lda (zp_printptr)
	beq endprintmsgloop
	jsr printchar
	inc zp_printptr
	bne printmsgloop
	inc zp_printptr+1
	bra printmsgloop

endprintmsgloop:
	rts


ramcodeend:

payloadsize = ramcodeend-ramcodebase
#print payloadsize

* = payload + payloadsize

