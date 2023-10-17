; SD card interface test

#include "boot64.inc"

SD_DATA = $ff10
SD_SETCS = $ff11


* = $200

irqentry: jmp irq
nmientry: jmp nmi

entry:
	ldx #$ff : txs

	jsr printimm
	.byte "SD card test", 13, 10, 0

	; First we have to let the card initialise by sending it at
	; least 80 clock pulses with CS and MOSI high
	;
	; We do this by sending 10 bytes of $ff - 80 bits - with
	; CS unasserted

	lda #0 : sta SD_SETCS

	dec

	ldx #16 ; a few extras
initloop:
	jsr sd_writebyte
	dex
	bne initloop

	; Read from the card, we expect FF here
	jsr sd_readbyte
	jsr printimm
	.byte "Read from card: ", 0
	jsr printhex
	jsr printnewline


cmd0:
	; GO_IDLE_STATE - resets card to idle state
	; This also puts the card in SPI mode.
	; Unlike most commands, the CRC is checked.

	lda #'c'
	jsr printchar
	lda #$00
	jsr printhex

	lda #1 : sta SD_SETCS   ; assert CS

	; CMD0, data 00000000, crc 95
	lda #$40 : jsr sd_writebyte
	lda #$00 : jsr sd_writebyte
	lda #$00 : jsr sd_writebyte
	lda #$00 : jsr sd_writebyte
	lda #$00 : jsr sd_writebyte
	lda #$95 : jsr sd_writebyte

	; Read response and print it - should be $01 (not initialized)
	jsr sd_waitresult
	pha
	jsr printhex
	
	stz SD_SETCS   ; unassert CS again

	; Expect status response $01 (not initialized)
	pla
	cmp #$01
	bne initfailed

	lda #'Y'
	jsr printchar

	; loop forever
loop:
	jmp loop


initfailed:
	lda #'X'
	jsr printchar
	jmp loop


sd_waitbyte:
.(
	; wait long enough for a byte to be sent or received
	;
	; It takes 16 I/O cycles.  The body of outerloop takes 16
	; CPU cycles, and we execute that CPUFREQ/IOFREQ times,
	; rounding down as the call overhead here is at least
	; 16 cycles as well.
	phx : phy
	ldx #25/4
outerloop:
	ldy #2
innerloop:
	dey
	bne innerloop
	dex
	bne outerloop
	ply : plx : rts
.)

sd_readbyte:
	jsr sd_waitbyte
	lda SD_DATA
	rts

sd_writebyte:
	jsr sd_waitbyte
	sta SD_DATA
	rts

sd_waitresult:
	jsr sd_readbyte
	cmp #$ff
	beq sd_waitresult
	rts

printhex:
	pha
	ror : ror : ror : ror
	jsr print_nybble
	pla
print_nybble:
.(
	pha
	and #15
	cmp #10
	bmi skipletter
	adc #6
skipletter:
	adc #48
	jsr printchar
	pla
	rts
.)

printnewline:
	lda #10 : jsr printchar
	lda #13 : jmp printchar


nmi:
	jsr printimm
	.byte "NMI", 0
	rti

irq:
	bit $ff50
	rti


codetop:

