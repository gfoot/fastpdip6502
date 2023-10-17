; int16 maths routine test

#include "boot64.inc"

#include "utils/via.s"


* = $200

irqentry: jmp irq
nmientry: jmp nmi
entry: jmp start

/*
  140F=50

  150FOR Y = -12 TO 12

  160FOR X = -49 TO 29

  170C=X*229/100
  180D=Y*416/100

  190A=C:B=D:I=0
y:200Q=B/F:S=B-(Q*F)
  210T=((A*A)-(B*B))/F+C
  220B=2*((A*Q)+(A*S/F))+D
  230A=T: P=A/F:Q=B/F
  240IF ((P*P)+(Q*Q))>=5 GOTO x

  250I=I+1:IF I<16 GOTO y
  260PRINT" ";
  270GOTO z

x:280VDU ?(Z+I)
z:290NEXT X

  300PRINT ""
  310NEXT Y


chars:
	.byte ".,'~=+:;*%&$OXB#@ "
numchars = *-chars

*/

zp_num = $20



start:
	jsr test_print
	jsr test_u16_mul
	jsr test_s16_mul

stop:
	bra stop


test_print:
.(
	ldy #0
loop:
	ldx #<zp_num

	lda testdata,y : sta zp_num
	lda testdata+1,y : sta zp_num+1

	jsr printdecu16
	jsr printspace
	jsr printdecs16
	jsr printnewline

	iny
	iny
	cpy #testdatalen
	bne loop

	rts

testdata:
	.word 0,1,2,3,5,8,13,21,34,55,89,144,233,377,610,987,1597,2584,4181,6765,10946,17711,28657,46368
	.word 0,-3,-4,-7,-11,-18,-29,-47,-76,-123,-199,-322,-521,-843,-1364,-2207,-3571,-5778,-9349,-15127,-24476
testdatalen = *-testdata
.)


test_u16_mul:
.(
	ldy #0
loop:
	lda testdata,y : sta zp_num
	lda testdata+1,y : sta zp_num+1
	lda testdata+2,y : sta zp_num+2
	lda testdata+3,y : sta zp_num+3
	lda testdata+4,y : sta zp_num+4
	lda testdata+5,y : sta zp_num+5

	jsr dotest

	lda testdata,y : sta zp_num+2
	lda testdata+1,y : sta zp_num+3
	lda testdata+2,y : sta zp_num
	lda testdata+3,y : sta zp_num+1
	lda testdata+4,y : sta zp_num+4
	lda testdata+5,y : sta zp_num+5

	jsr dotest

	iny : iny : iny : iny : iny : iny
	cpy #testdatalen
	bne loop

	rts


dotest:
	ldx #<zp_num
	jsr printdecu16

	jsr printimm
	.byte " * ", 0

	ldx #<zp_num+2
	jsr printdecu16

	jsr printimm
	.byte " = ",0

	ldx #<zp_num+4
	jsr printdecu16

	phy
	ldx #<zp_num
	ldy #<zp_num+2
	jsr u16_mul
	ply

	jsr printimm
	.byte "  result: ", 0
	ldx #<zp_num+2
	jsr printdecu16

	lda zp_num+2 : cmp zp_num+4 : bne different
	lda zp_num+3 : cmp zp_num+5 : beq notdifferent
	
different:
	jsr printimm
	.byte " (fail)", 0

notdifferent:
	jsr printnewline
	rts


testdata:
	.word 0,0,0
	.word 0,1,0
	.word 0,1000,0
	.word 1,1,1
	.word 2,2,4
	.word 10,10,100
	.word 16,16,256
	.word 8,32,256
	.word 2,128,256
	.word 128,128,128*128
	.word 255,256,255*256
testdatalen = *-testdata

.)

test_s16_mul:
.(
	ldy #0
loop:
	lda testdata,y : sta zp_num
	lda testdata+1,y : sta zp_num+1
	lda testdata+2,y : sta zp_num+2
	lda testdata+3,y : sta zp_num+3
	lda testdata+4,y : sta zp_num+4
	lda testdata+5,y : sta zp_num+5

	jsr dotest

	lda testdata,y : sta zp_num+2
	lda testdata+1,y : sta zp_num+3
	lda testdata+2,y : sta zp_num
	lda testdata+3,y : sta zp_num+1
	lda testdata+4,y : sta zp_num+4
	lda testdata+5,y : sta zp_num+5

	jsr dotest

	iny : iny : iny : iny : iny : iny
	cpy #testdatalen
	bne loop

	rts


dotest:
	ldx #<zp_num
	jsr printdecs16

	jsr printimm
	.byte " * ", 0

	ldx #<zp_num+2
	jsr printdecs16

	jsr printimm
	.byte " = ",0

	ldx #<zp_num+4
	jsr printdecs16

	phy
	ldx #<zp_num
	ldy #<zp_num+2
	jsr s16_mul
	ply

	jsr printimm
	.byte "  result: ", 0
	ldx #<zp_num+2
	jsr printdecs16

	lda zp_num+2 : cmp zp_num+4 : bne different
	lda zp_num+3 : cmp zp_num+5 : beq notdifferent
	
different:
	jsr printimm
	.byte " (fail)", 0

notdifferent:
	jsr printnewline
	rts


testdata:
	.word 0,0,0
	.word 0,1,0
	.word 0,-1,0
	.word 0,1000,0
	.word 0,-1000,0
	.word 1,1,1
	.word -1,1,-1
	.word 1,-1,-1
	.word -1,-1,1
	.word 2,2,4
	.word -2,2,-4
	.word 2,-2,-4
	.word -2,-2,4
	.word 10,10,100
	.word 16,16,256
	.word 8,32,256
	.word 2,128,256
	.word 128,128,128*128
	.word -128,128,128*-128
	.word 128,-128,128*-128
	.word -128,-128,128*128
	.word 7,4681,32767
	.word -7,4681,-32767
	.word 7,-4681,-32767
	.word -7,-4681,32767
testdatalen = *-testdata

.)



nmi:
	jsr printimm
	.byte "NMI", 0
	rti

irq:
	stz SER_STAT
	rti

#include "utils/cpuspeed.s"
#include "utils/print.s"
#include "utils/int16.s"

libtop:

