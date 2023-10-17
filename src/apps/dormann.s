; Klaus Dormann's 6502 test

#include "boot64.inc"

#include "utils/via.s"


* = $200

phase = $04


irqentry: jmp irq
nmientry: jmp nmi
pchar: jmp printchar
gchar: jmp upload

entry:
	ldx #$ff
	inx
	stx phase

upload:
	ldx #$ff : txs

.(
	inc phase : lda phase : cmp #2 : bne nowrap
	stz phase
nowrap:
.)

	jsr printimm
	.byte 13, 10, "==> Phase ", 0
	lda phase : beq printphase0
	
	jsr printimm
	.byte "1 - 65C02_extended_opcodes_test - ", 0
	bra doneprintphase

printphase0:
	jsr printimm
	.byte "0 - 6502_functional_test - ", 0

doneprintphase:
	jsr measurecpuspeed
	jsr printcpuspeed
	jsr printnewline

	lda phase
	beq runphase0
	jmp phase1
runphase0:
	jmp phase0

nmi:
	jsr printimm
	.byte "NMI", 0
	rti

irq:
	stz SER_STAT
	rti

	.dsb $300-*, 0

phase0:
	.bin 0,0,"../../6502_65C02_functional_tests/out/6502_functional_test.bin"
phase0top:
#print phase0top-phase0

	.dsb $4600-*, 0

phase1:
#print phase1-phase0top
	.bin 0,0,"../../6502_65C02_functional_tests/out/65C02_extended_opcodes_test.bin"
phase1top:
#print phase1top-phase1

#print $7e00-phase1top

#include "utils/cpuspeed.s"
#include "utils/print.s"

libtop:
#print $7e00-libtop

