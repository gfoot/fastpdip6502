; Life in 6502 assembly language

;#define DEBUG

#include "boot64.inc"

* = $200
YSIZE = 64
XSIZE = 48

zp_ptr = $20
zp_temp = $22
zp_hsumptr = $23
zp_hsumptrup = $25
zp_hsumptrdown = $27
zp_xcount = $29


irqentry: jmp irq

entry:
.(
	ldx #$ff : tsx

	lda #<data_grid : sta zp_ptr
	lda #>data_grid : sta zp_ptr+1

	ldx #XSIZE-1
	stx zp_xcount
xloop:
	ldy #0 : sty 0
	ldy #YSIZE-1 : sty 1
yloop:
	ldy 0 : lda (zp_ptr),y : tax
	ldy 1 : lda (zp_ptr),y
	ldy 0 : sta (zp_ptr),y
	ldy 1 : txa : sta (zp_ptr),y
	inc 0
	dec 1
	ldy 1
	cpy #YSIZE/2
	bcs yloop

	clc
	lda zp_ptr : adc #YSIZE : sta zp_ptr
	lda zp_ptr+1 : adc #0 : sta zp_ptr+1

	dec zp_xcount
	bpl xloop

	jsr printimm
	.byte 27,'[2J',0

loop:
	jsr redisplay

	jsr iter

	bra loop
.)


redisplay:
#ifdef DEBUG
	jmp display
#endif

	jsr printimm
	.byte 27,'[0;0H',0

display:
.(
	lda #<data_grid : sta zp_ptr
	lda #>data_grid : sta zp_ptr+1

	ldx #XSIZE-2
xloop:
	ldy #YSIZE-2
yloop:
	clc
	lda (zp_ptr),y : beq empty
	lda #'(' : jsr printchar : lda #')' : jsr printchar
	bra next
empty:
	lda #' ' : jsr printchar : jsr printchar
next:

	dey
	bpl yloop

	jsr printnewline

	clc
	lda zp_ptr : adc #YSIZE : sta zp_ptr
	lda zp_ptr+1 : adc #0 : sta zp_ptr+1

	dex
	bpl xloop

	rts
.)


iter:
	jsr sumhoriz

#ifdef DEBUG
	jsr dumpgrids
#endif

	jsr updatecells

	rts


sumhoriz:
.(
	; Loop over cells 0..YSIZE-2 x 0..XSIZE-2, calculating sum of cell content with left and right neighbours
	;
	; When we reach each cell, we already know its sum with its left neighbour.  We need to add its right neighbour,
	; store the result, then subtract its left neigbour again.
	;
	; For each row, we precalculate the border sums (cell 0 and cell YSIZE-1 have the same value) and then
	; loop left from YSIZE-2 down to 1 filling in the others.
	;
	; We only loop over XSIZE-1 rows; the last would just be a copy of the opposite edge row.

	lda #<data_grid : sta zp_ptr
	lda #>data_grid : sta zp_ptr+1
	lda #<data_hsumgrid : sta zp_hsumptr
	lda #>data_hsumgrid : sta zp_hsumptr+1
	ldx #XSIZE-1
	clc
xloop:
	; Copy left cell to right cell
	ldy #YSIZE-1
	lda (zp_ptr) : sta (zp_ptr),y

	; Add cell YSIZE-2
	dey : adc (zp_ptr),y

	; Now we're ready for the row loop starting with cell YSIZE-2
yloop:
	; We need to add the cell to the left, write the result, subtract the cell to the right, and continue
	dey : adc (zp_ptr),y
	iny : sta (zp_hsumptr),y
	iny : sec : sbc (zp_ptr),y : clc
	dey : dey
	bne yloop

	; Calculate value for cell 0 (wrapping to YSIZE-2).  A already holds cell 0 plus cell 1.
	ldy #YSIZE-2 : adc (zp_ptr),y
	sta (zp_hsumptr)
	iny : sta (zp_hsumptr),y

	; Advance to next row
	dex : beq done

	; Add YSIZE to both pointers - this requires them to have the same alignment mod 256
	lda zp_ptr : adc #YSIZE : sta zp_ptr
	clc
	lda zp_hsumptr : adc #YSIZE : sta zp_hsumptr
	bcc xloop
	clc
	inc zp_ptr+1 : inc zp_hsumptr+1
	bra xloop

done:

	; For the last row, just copy the first row
	ldy #YSIZE-1
lastrowloop:
	lda data_hsumgrid,y : sta data_hsumgrid+YSIZE*(XSIZE-1),y
	dey
	bpl lastrowloop

	rts
.)


updatecells:
.(
	; The hsum grid contains, for each cell, the sum of it and its horizontal neighbours.
	; We can loop over all the cells, for each cell adding its hsum to the hsums above and below
	; and then calculate the next state of the cell and updating it in place.

	lda #<data_grid : sta zp_ptr
	lda #>data_grid : sta zp_ptr+1

	lda #<data_hsumgrid : sta zp_hsumptr
	lda #>data_hsumgrid : sta zp_hsumptr+1
	lda #<(data_hsumgrid+YSIZE) : sta zp_hsumptrdown
	lda #>(data_hsumgrid+YSIZE) : sta zp_hsumptrdown+1
	lda #<(data_hsumgrid+YSIZE*(XSIZE-2)) : sta zp_hsumptrup
	lda #>(data_hsumgrid+YSIZE*(XSIZE-2)) : sta zp_hsumptrup+1

	ldx #XSIZE-1
	stx zp_xcount
	clc
xloop:
	ldy #YSIZE-2
yloop:
	; Calculate the sum
	lda (zp_hsumptr),y : adc (zp_hsumptrdown),y : adc (zp_hsumptrup),y

	; Double it and add the current state
	asl : ora (zp_ptr),y

	; Use a lookup table to determine its next state
	tax : lda lookup,x : sta (zp_ptr),y

	; Advance to next cell
	dey
	bpl yloop

	; Advance to next row
	dec zp_xcount
	beq done

	lda zp_ptr : adc #YSIZE : sta zp_ptr
	lda zp_ptr+1 : adc #0 : sta zp_ptr+1

	lda zp_hsumptr : sta zp_hsumptrup
	lda zp_hsumptrdown : sta zp_hsumptr
	adc #YSIZE : sta zp_hsumptrdown

	lda zp_hsumptr+1 : sta zp_hsumptrup+1
	lda zp_hsumptrdown+1 : sta zp_hsumptr+1
	adc #0 : sta zp_hsumptrdown+1

	bra xloop

done:
	rts

lookup:
	; A cell lives if 2*neighboursum+self is:
	;    0011 1  - live with two other neighbours
	;    0011 0  - dead with three neighbours
    ;    0100 1  - live with three other neighbours
	; Otherwise it dies.
	.byte 0,0,0,0,0,0,1,1,0,1,0,0,0,0,0,0,0,0,0,0
.)


dumpgrids:
.(
	jsr printnewline

	lda #<data_grid : sta zp_ptr
	lda #>data_grid : sta zp_ptr+1
	lda #<data_hsumgrid : sta zp_hsumptr
	lda #>data_hsumgrid : sta zp_hsumptr+1

	ldx #XSIZE-1
xloop:
	ldy #YSIZE-1
yloop:
	lda (zp_hsumptr),y : jsr printhex
	lda (zp_ptr),y : jsr printhex
	jsr printspace
	dey
	bpl yloop

	jsr printnewline

	clc
	lda zp_ptr : adc #YSIZE : sta zp_ptr
	lda zp_ptr+1 : adc #0 : sta zp_ptr+1
	
	lda zp_hsumptr : adc #YSIZE : sta zp_hsumptr
	lda zp_hsumptr+1 : adc #0 : sta zp_hsumptr+1

	dex
	bpl xloop

	rts
.)



irq:
	rti

#include "utils/print.s"

	.dsb $1000-*,0

data_grid:
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,1,0,0,0,0,1,1,1,1,1,1,1,1,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,0,1,0,0,0,0,1,1,1,1,1,1,0,0,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,0,1,0,0,0,0,1,1,1,1,1,1,0,0,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,1,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,1,1,1,1,1,1,1,0,0
.byte 0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0
.byte 0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0
.byte 0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0
.byte 0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0
.byte 0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,1,1,1,1,1,1,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0


data_hsumgrid = $4000

