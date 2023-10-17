; 6502 assembly language Mandelbrot Set plotter
;
; Inspired by Gordon Henderson's BASIC Mandlebrot benchmark:
;   https://projects.drogon.net/retro-basic-benchmarking-with-mandelbrot/
;
; I wanted to make one in pure 6502 assembly language to see how fast it would run
; on my computer.  I used a different fixed-point format, with 24-bit multiplication
; to handle overflow.
;
; I used roughly the same characters as Gordon, but added some extras and repetitions 
; to allow for more iterations.  I'm also rendering a different region, tailored to
; suit my PC's console window font.


; boot64.inc defines OS entry points for some basic I/O routines, especially:
;
;    printchar  - output the character whose ASCII code is in A
;
;    printimm   - output the null-terminated string following the JSR instruction
#include "boot64.inc"


* = $200

irqentry: jmp irq
nmientry: jmp nmi
entry: jmp start

chars:
	.byte " WM@#BXFGODC$&%*=FCODC$&%*=+~-;:,."
MAXITER = *-chars


zp_a = $20
zp_b = $22
zp_aa = $24
zp_bb = $26
zp_ab = $28
zp_x = $2a
zp_y = $2c

zp_aasub = $2e
zp_bbsub = $2f
zp_absub = $31
zp_a24 = $32
zp_b24 = $35

zp_iter = $38
zp_xcount = $39
zp_ycount = $3a


; Dimensions.  The maximums aren't actually used.

YMIN = $fec0  ; -1.25        11111110 11000000
YMAX = $0140  ;  1.25        00000001 01000000
YSTEP = $0008 ;  0.03125     00000000 00001000
XMIN = $fe74  ; -1.546875    11111110 01110100
XMAX = $0090  ;  0.5625      00000000 10010000
XSTEP = $0004 ;  0.015625    00000000 00000100

; Width and height of region to display

XCOUNT = 134
YCOUNT = 80


start:

	jsr printimm
	.byte "Mandelbrot - ", 0

	stz zp_a+1 : lda #XCOUNT : sta zp_a : ldx #<zp_a : jsr printdecu16

	jsr printimm
	.byte " x ", 0

	stz zp_a+1 : lda #YCOUNT : sta zp_a : ldx #<zp_a : jsr printdecu16

	jsr printimm
	.byte ", ", 0

	stz zp_a+1 : lda #MAXITER : sta zp_a : ldx #<zp_a : jsr printdecu16

	jsr printimm
	.byte " iterations", 13, 10, 10, 0

	lda #<YMIN : sta zp_y
	lda #>YMIN : sta zp_y+1
	lda #YCOUNT : sta zp_ycount
yloop:

	lda #<XMIN : sta zp_x
	lda #>XMIN : sta zp_x+1
	lda #XCOUNT : sta zp_xcount
xloop:

	lda zp_x : sta zp_a
	lda zp_x+1 : sta zp_a+1

	lda zp_y : sta zp_b
	lda zp_y+1 : sta zp_b+1

	ldx #MAXITER
	stx zp_iter

iterloop:

	; Calculate aa = a*a, bb = b*b, ab = a*b
	;
	; We'll compute a*b into ab and copy it back to b afterwards
	;
	; We need 24-bit copies of a and b, and a byte of less significant bits for each result
	;
	; If any of these ever go >5 then we could abort as the overall calculation will then be out of range anyway
	;
	; If one but not both are negative then b should be negative at the end; but in general the calculation is 
	; done on absolute values
.(
#ifdef DEBUG
	jsr printnewline
	jsr printspace : ldx #<zp_a : jsr printhex16
	jsr printspace : ldx #<zp_b : jsr printhex16
#endif

	ldy #0 ; negative flag is bit 0

.(
	lda zp_a+1 : bpl positive

	iny ; flip sign
	sec
	lda #0 : sbc zp_a : sta zp_a : sta zp_a24
	lda #0 : sbc zp_a+1 : sta zp_a+1 : sta zp_a24+1
	bra continue

positive:
	sta zp_a24+1
	lda zp_a : sta zp_a24

continue:
	stz zp_a24+2
.)

.(
	lda zp_b+1 : bpl positive

	iny ; flip sign
	sec
	lda #0 : sbc zp_b : sta zp_b : sta zp_b24
	lda #0 : sbc zp_b+1 : sta zp_b+1 : sta zp_b24+1
	bra continue

positive:
	sta zp_b24+1
	lda zp_b : sta zp_b24

continue:
	stz zp_b24+2
.)

#ifdef DEBUG
	jsr printspace : tya : jsr printhex
	jsr printspace : ldx #<zp_a : jsr printhex16
	jsr printspace : ldx #<zp_a24 : jsr printhex24
	jsr printspace : ldx #<zp_b : jsr printhex16
	jsr printspace : ldx #<zp_b24 : jsr printhex24
#endif

	stz zp_aasub : stz zp_aa : stz zp_aa+1
	stz zp_bbsub : stz zp_bb : stz zp_bb+1
	stz zp_absub : stz zp_ab : stz zp_ab+1

bitloop_a:
	; First deal with zp_a - shift right, see if the bit was set
	lsr zp_a+1 : ror zp_a : bcc bitloop_b

	; Add a24 to aa
	clc
	lda zp_aasub : adc zp_a24 : sta zp_aasub
	lda zp_aa : adc zp_a24+1 : sta zp_aa
	lda zp_aa+1 : adc zp_a24+2 : sta zp_aa+1
	;bcs overflow

	; Add b24 to ab
	clc
	lda zp_absub : adc zp_b24 : sta zp_absub
	lda zp_ab : adc zp_b24+1 : sta zp_ab
	lda zp_ab+1 : adc zp_b24+2 : sta zp_ab+1
	;bcs overflow

bitloop_b:
	; Now deal with zp_b - shift right, see if the bit was set
	lsr zp_b+1 : ror zp_b : bcc b_bit_done

	; Add b24 to bb
	clc
	lda zp_bbsub : adc zp_b24 : sta zp_bbsub
	lda zp_bb : adc zp_b24+1 : sta zp_bb
	lda zp_bb+1 : adc zp_b24+2 : sta zp_bb+1
	;bcs overflow

b_bit_done:
	; Shift a24 and b24 left
	asl zp_a24 : rol zp_a24+1 : rol zp_a24+2
	asl zp_b24 : rol zp_b24+1 : rol zp_b24+2

	; If zp_a still has set bits, loop all the way back
	lda zp_a : ora zp_a+1 : bne bitloop_a

	; Otherwise if zp_b has set bits, loop just back to there
	lda zp_b : ora zp_b+1 : bne bitloop_b

	; Else we're done with the main multiplications

	; Double ab into b
	lda zp_absub : asl
	lda zp_ab : rol : sta zp_b
	lda zp_ab+1 : rol : sta zp_b+1
	;bcs overflow : bmi overflow

	; Correct the sign of b if it was meant to be negative
	tya : and #1 : beq done
	sec
	lda #0 : sbc zp_b : sta zp_b
	lda #0 : sbc zp_b+1 : sta zp_b+1
;	bra done
;
;overflow:
;	bra iterloopend

done:
.)

#ifdef DEBUG
	jsr printspace
	jsr printspace : ldx #<zp_aa : jsr printhex16
	jsr printspace : ldx #<zp_bb : jsr printhex16
	jsr printspace : ldx #<zp_b : jsr printhex16
#endif

	; Now aa = a*a, bb = b*b, b = 2*a*b
	;
	; We could check aa and bb against 5 here but probably not necessary.
	; No need to check b as aa+bb>b

	; Check aa+bb against 5
	clc
	lda zp_aa : adc zp_bb
	lda zp_aa+1 : adc zp_bb+1
	cmp #5 : bcs iterloopend

	; a=e-f+c
	sec
	lda zp_aa : sbc zp_bb : sta zp_a
	lda zp_aa+1 : sbc zp_bb+1 : sta zp_a+1

	clc
	lda zp_a : adc zp_x : sta zp_a
	lda zp_a+1 : adc zp_x+1 : sta zp_a+1

	; b=b+d
	clc
	lda zp_b : adc zp_y : sta zp_b
	lda zp_b+1 : adc zp_y+1 : sta zp_b+1

	; iterate
	dec zp_iter : beq iterloopend
	jmp iterloop

iterloopend:
	ldx zp_iter : lda chars,x : jsr printchar

xloopnext:
	clc
	lda zp_x : adc #<XSTEP : sta zp_x
	lda zp_x+1 : adc #>XSTEP : sta zp_x+1

	dec zp_xcount : beq xloopend
	jmp xloop
xloopend:

	jsr printnewline

yloopnext:
	clc
	lda zp_y : adc #<YSTEP : sta zp_y
	lda zp_y+1 : adc #>YSTEP : sta zp_y+1

	dec zp_ycount : beq stop
	jmp yloop


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

libtop:
#print *-$200
