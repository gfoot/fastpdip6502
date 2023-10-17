; Basic serial input and output test program
;
; RAM - $0000-$fdff - nearly 64K
; ROM - $fe00-$feff - 256 bytes
; I/O - $ff00-$ffbf
; ROM - $ffc0-$ffff
;
; I/O 0 - $ff00-$ff0f
; I/O 1 - $ff10-$ff1f
; ...


SER_RX_DATA = $ff40
SER_STAT = $ff50
SER_TX_DATA = $ff60
DEBUGPORT = $ff70


buffer = $1000


* = $ROMBASE
	.dsb $fe00-*, 0

entry:
	ldx #$ff : txs
	sei : clv : cld : cpx #0
	inx : txa : tay

	lda #'A'
	sta DEBUGPORT
	sta SER_TX_DATA

	lda #'Z'
	jsr printchar

mainloop:
	ldx #0

innerloop:
	jsr readchar
	cmp #10 : beq linedone
	jsr printchar
	sta buffer,x
	inx
	bne innerloop

	dex

linedone:
	cpx #0 : beq nocharacters

	lda #13 : jsr printchar
	lda #10 : jsr printchar : jsr printchar
	lda #'"' : jsr printchar

	ldy #0
echoloop:
	lda buffer,y : jsr printchar
	iny
	dex
	bne echoloop

	lda #'"' : jsr printchar

nocharacters:
	lda #13 : jsr printchar
	lda #10 : jsr printchar : jsr printchar

	bra mainloop

stop:
	bra stop


printchar:
	bit SER_STAT
	bpl printchar
	sta DEBUGPORT
	sta SER_TX_DATA
	rts

readchar:
	bit SER_STAT
	bvc readchar
	lda SER_RX_DATA
	rts


top:
	.dsb $ff00-*, $00
#print top-entry
#print *-top

ioports:
	.dsb $c0, $00

ffc0:
irq:
	ldx #$ff : stx DEBUGPORT
	bra irq

nmi:
	ldx #$fe : stx DEBUGPORT
	bra nmi
	

toptop:
	.dsb $fffa-*, $00

#print *-toptop

vectors:
	.word nmi
	.word entry
	.word irq

