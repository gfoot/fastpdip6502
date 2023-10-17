; Wrapper OS module - provides reset entry point, relocates the main code to RAM, and chains to initialise things

* = $400

#include "os/oscode.s"

.(
rombase = $ROMBASE

ostop:

* = rombase + ostop - osbase

top:
	.dsb $ff00-*, $00
#print *-top

ioports:
	.dsb $c0, $00

entry:
	srcptr = 0
	destptr = 2
	
	ldx #$ff : txs

	lda #12 : sta SER_TDR ; clear screen

	lda #<rombase : sta srcptr
	lda #>rombase : sta srcptr+1
	lda #<osbase : sta destptr
	lda #>osbase : sta destptr+1
	ldx #>(ioports-rombase)
	ldy #0
copyloop:
	lda (srcptr),y : sta (destptr),y
	iny : bne copyloop
	inc srcptr+1 : inc destptr+1
	lda #'.' : sta SER_TDR
	dex : bne copyloop

;waittdre:
;	bit SER_STAT
;	bvc waittdre

	lda #'*' : sta SER_TDR

	jmp osentry

entrytop:
	.dsb $fffa-*, $00
#print *-entrytop

vectors:
	.word irq
	.word entry
	.word irq
.)

