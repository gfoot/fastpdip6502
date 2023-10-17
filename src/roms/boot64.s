; Small boot code that performs commands requested by serial link

.(


;&SER_RDR = $ff40
;&SER_TDR = $ff60
;&SER_STAT = $ff50

&SER_RDR = $ff00
&SER_TDR = $ff00
&SER_STAT = $ff01

&DEBUGPORT = $ff70

nmientry = $203
irqentry = $200

&printptr = $80


* = $ROMBASE
	.dsb $fe00-*, 0

entry:
	ldx #$40 : stx nmientry : stx irqentry
	ldx #$ff : txs
	sei : clv : cld : cpx #0
	txa : tay
	
	; Reset TDRE
	lda #12 : sta SER_TDR 

bootloop:
	jsr printimm
	.byte "boot0001", 0

cmdloop:
	jsr getchar
	jsr printchar

	dec : beq readaddr
	dec : beq loaddata
	dec : beq execute
	bra bootloop

loaddata:
	ldy #0
	stz 2 : stz 3
	clc
loaddataloop:
	jsr getchar
	sta (0),y
	adc 2 : sta 2
	adc 3 : sta 3
	iny
	bne loaddataloop

	lda 2 : jsr printchar
	lda 3 : jsr printchar

	inc 1
	
	bra cmdloop

execute:
	jmp (0)


readaddr:
	; Read an address and store it at 0,1
	jsr getchar : sta 0
	jsr getchar : sta 1
	lda 0 : jsr printchar
	lda 1 : jsr printchar
	bra cmdloop


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

&printmsg:
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

top:
	.dsb $ff00-*, $00
#print top-entry
#print *-top

ioports:
	.dsb $c0, $00

ffc0:
	iny : bne ffc0
	inc : bne ffc0
	inx : stx DEBUGPORT : bra ffc0

toptop:
	.dsb $fffa-*, $00

#print *-toptop

vectors:
	.word nmientry
	.word entry
	.word irqentry
.)

