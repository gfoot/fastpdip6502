; Mandelbrot plotter

#include "boot64.inc"

#include "utils/via.s"


* = $200

irqentry: jmp irq
nmientry: jmp nmi
entry: jmp start

chars:
	.byte ".,'~=+:;*%&$CDOGFXB#@MW "
numchars = *-chars


zp_s16_a = $20
zp_s16_b = $22
zp_s16_c = $24
zp_s16_d = $26
zp_s16_p = $28
zp_s16_q = $2a
zp_s16_r = $2c
zp_s16_s = $2e
zp_s16_x = $30
zp_s16_y = $32

zp_iter = $40



start:

	; F = 64           ; 00000000 01000000 = $0040
	; G = 5*F          ; 00000001 01000000 = $0140
	; H = G*F          ; 01010000 00000000 = $5000

	ldy #256-40
yloop:
	phy

	stz zp_s16_y+1
	tya
	sta zp_s16_y
.(
	bpl notneg
	lda #$ff : sta zp_s16_y+1
notneg:
.)


	lda zp_s16_y : asl : sta zp_s16_d
	lda zp_s16_y+1 : rol : sta zp_s16_d+1

/*
	; D = Y * 681      ; 680 = 00000010 10101000
	; D = D / 128      ; D=Y*5*17/16
                       ;  => D=Y ; D=D<<2 ; D=D+Y ; Y=D ; D=D<<4 ; D=D+Y ; D=D>>4

	; D=Y
	lda zp_s16_y : sta zp_s16_d
	lda zp_s16_y+1 ; keep in A for now

	; D=D<<2
	asl zp_s16_d : rol
	asl zp_s16_d : rol
	sta zp_s16_d+1

	; Y=D=D+Y
	clc
	lda zp_s16_d : adc zp_s16_y : sta zp_s16_y : sta zp_s16_d
	lda zp_s16_d+1 : adc zp_s16_y+1 : sta zp_s16_y+1  ; keep in A

	; D=D<<4
	asl zp_s16_d : rol
	asl zp_s16_d : rol
	asl zp_s16_d : rol
	asl zp_s16_d : rol
	sta zp_s16_d+1

	; D=D+Y
	clc
	lda zp_s16_d : adc zp_s16_y : sta zp_s16_d
	lda zp_s16_d+1 : adc zp_s16_y+1 ; keep in A

	; D=D>>4
	lsr : ror zp_s16_d
	lsr : ror zp_s16_d
	lsr : ror zp_s16_d
	lsr : ror zp_s16_d
	
.(
	; If it was negative we're missing some high bits that should be set
	bit zp_s16_y+1 : bpl notnegative
	ora #$f0
notnegative:
.)
	sta zp_s16_d+1
*/

	ldx #256-99
xloop:
	phx

	stz zp_s16_x+1
	txa
	sta zp_s16_x
.(
	bpl notneg
	lda #$ff : sta zp_s16_x+1
notneg:
.)

	lda zp_s16_x : sta zp_s16_c
	lda zp_s16_x+1 : sta zp_s16_c+1

/*
	; C = X * 375      ; 374 = 00000001 01110110
	; C = C / 128      ; C=X*11*17/64
	                   ;  => C=X ; C=C<<2 ; C=C+X ; C=C<<1 ; C=C+X ; X=C ; C=C<<4 ; C=C+X ; C=C>>6

	; C=X
	lda zp_s16_x : sta zp_s16_c
	lda zp_s16_x+1 ; keep in A

	; C=C<<2
	asl zp_s16_c : rol
	asl zp_s16_c : rol
	sta zp_s16_c+1

	; C=C+X
	clc
	lda zp_s16_c : adc zp_s16_x : sta zp_s16_c
	lda zp_s16_c+1 : adc zp_s16_x+1 ; keep in A

	; C=C<<1
	asl zp_s16_c : rol
	sta zp_s16_c+1
	
	; X=C=C+X
	clc
	lda zp_s16_c : adc zp_s16_x : sta zp_s16_x : sta zp_s16_c
	lda zp_s16_c+1 : adc zp_s16_x+1 : sta zp_s16_x+1  ; keep in A

	; C=C<<4
	asl zp_s16_c : rol
	asl zp_s16_c : rol
	asl zp_s16_c : rol
	asl zp_s16_c : rol
	sta zp_s16_c+1

	; C=C+X
	clc
	lda zp_s16_c : adc zp_s16_x : sta zp_s16_c
	lda zp_s16_c+1 : adc zp_s16_x+1 ; sta zp_s16_c+1

	; C=C>>6
	ldx #<zp_s16_c : jsr s16_div64
*/

	; A=c
	sta zp_s16_a+1
	lda zp_s16_c : sta zp_s16_a

	; B=D
	lda zp_s16_d : sta zp_s16_b
	lda zp_s16_d+1 : sta zp_s16_b+1

	; I=0
	stz zp_iter

	; P=A*A  => P=X=A, P=X*P
	lda zp_s16_a : sta zp_s16_p : sta zp_s16_x
	lda zp_s16_a+1 : sta zp_s16_p+1 : sta zp_s16_x+1
	ldx #<zp_s16_x
	ldy #<zp_s16_p
	jsr s16_mul

	; R=B*B  => R=X=B, R=X*B
	lda zp_s16_b : sta zp_s16_r : sta zp_s16_x
	lda zp_s16_b+1 : sta zp_s16_r+1 : sta zp_s16_x+1
	ldx #<zp_s16_x
	ldy #<zp_s16_r
	jsr s16_mul

iterloop:

	; Q=B/F
	lda zp_s16_b : sta zp_s16_q
	lda zp_s16_b+1 : sta zp_s16_q+1
	ldx #<zp_s16_q : jsr s16_div64

	; S=B-Q*F
	stz zp_s16_s+1
	lda zp_s16_b
	and #$3f
	sta zp_s16_s

	; B=2*(A*Q+A*S/F)+D
	;   => B=A ; Q=A*Q ; B=S*B ; B=B/F ; B=B+Q ; B=B<<1 ; B=B+D

	lda zp_s16_a : sta zp_s16_b
	lda zp_s16_a+1 : sta zp_s16_b+1

	; Q=A*Q
	ldx #<zp_s16_a
	ldy #<zp_s16_q
	jsr s16_mul

	; B=S*B
	ldx #<zp_s16_s
	ldy #<zp_s16_b
	jsr s16_mul

	; B=B/F
	ldx #<zp_s16_b
	jsr s16_div64

	; B=B+Q
	clc
	lda zp_s16_b : adc zp_s16_q : sta zp_s16_b
	lda zp_s16_b+1 : adc zp_s16_q+1 ; keep in A

	; B=B<<1
	asl zp_s16_b : rol : sta zp_s16_b+1

	; B=B+D
	clc
	lda zp_s16_b : adc zp_s16_d : sta zp_s16_b
	lda zp_s16_b+1 : adc zp_s16_d+1 : sta zp_s16_b+1

	; A=(P-R)/F+C   => A=P-R ; A=A>>6 ; A=A+C
	sec
	lda zp_s16_p : sbc zp_s16_r : sta zp_s16_a
	lda zp_s16_p+1 : sbc zp_s16_r+1 : sta zp_s16_a+1

	ldx #<zp_s16_a : jsr s16_div64

	clc
	lda zp_s16_a : adc zp_s16_c : sta zp_s16_a
	lda zp_s16_a+1 : adc zp_s16_c+1 : sta zp_s16_a+1


	; -2A>G, 2A>G, -2B>G, 2B>G => afteriterloop
	;  => branch if squaring would overflow
.(
	lda zp_s16_a+1
	beq ok
	cmp #$ff
	bne afteriterloop
ok:
.)
.(
	lda zp_s16_b+1
	beq ok
	cmp #$ff
	bne afteriterloop
ok:
.)

	; P=A*A  => P=X=A, P=X*P
	lda zp_s16_a : sta zp_s16_p : sta zp_s16_x
	lda zp_s16_a+1 : sta zp_s16_p+1 : sta zp_s16_x+1
	ldx #<zp_s16_x
	ldy #<zp_s16_p
	jsr u16_mul

	; R=B*B  => R=X=B, R=X*B
	lda zp_s16_b : sta zp_s16_r : sta zp_s16_x
	lda zp_s16_b+1 : sta zp_s16_r+1 : sta zp_s16_x+1
	ldx #<zp_s16_x
	ldy #<zp_s16_r
	jsr u16_mul

	
	; P>H, R>H => afteriterloop
	; P/F+R/F>G => afteriterloop
	;
	; => X=P+R ; overflow => afteriterloop ; X=X-H ; pos => afteriterloop

	clc
	lda zp_s16_p : adc zp_s16_r : sta zp_s16_x
	lda zp_s16_p+1 : adc zp_s16_r+1 : sta zp_s16_x+1
	bcs afteriterloop

	; H = 5*64*64 = $5000
	lda zp_s16_x+1 : cmp #$50
	bcs afteriterloop

	
	; I=I+1, etc

	inc zp_iter
	ldy zp_iter
	cpy #numchars-1
	bcs afteriterloop

	jmp iterloop

afteriterloop:
	ldy zp_iter
	lda chars,y
	jsr printchar

/*
	plx : ply : phy : phx

	stz zp_s16_y+1
	tya
	sta zp_s16_y
.(
	bpl notneg
	lda #$ff : sta zp_s16_y+1
notneg:
.)

	stz zp_s16_x+1
	txa
	sta zp_s16_x
.(
	bpl notneg
	lda #$ff : sta zp_s16_x+1
notneg:
.)

	ldx #<zp_s16_y : jsr printdecs16 : jsr printspace
	ldx #<zp_s16_d : jsr printdecs16 : jsr printspace
	ldx #<zp_s16_x : jsr printdecs16 : jsr printspace
	ldx #<zp_s16_c : jsr printdecs16 : jsr printspace

	jsr printnewline
*/

	plx
	inx
	cpx #36
	beq xloopend
	jmp xloop
xloopend:

	jsr printnewline

	ply
	iny
	cpy #40
	beq yloopend
	jmp yloop
yloopend:


stop:
	bra stop



nmi:
	jsr printimm
	.byte "NMI", 0
	rti

irq:
	stz SER_STAT
	rti

#include "utils/print.s"
#include "utils/int16.s"

libtop:
#print *-$200
