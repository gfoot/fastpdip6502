; Basic serial output test program
;
; RAM - $0000-$fdff - nearly 64K
; ROM - $fe00-$feff - 256 bytes
; I/O - $ff00-$ffbf
; ROM - $ffc0-$ffff
;
; I/O 0 - $ff00-$ff0f
; I/O 1 - $ff10-$ff1f
; ...


SER_STAT = $ff50
SER_TX_DATA = $ff60
DEBUGPORT = $ff70

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

again:
	bit SER_STAT
	bpl again
	sta SER_TX_DATA
	sta DEBUGPORT
	bra again

stop:
	bra stop


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

