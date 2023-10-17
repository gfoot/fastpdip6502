; Prime sieve
;
; The sieve stores one byte per odd integer greater than or equal to 3
; So sieve index N represents number 3+2*N
;
; 0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16
; 3   5   7   9  11  13  15  17  19  21  23  25  27  29  31  33  35
;
; 0 represents 3, and 0+3*N represent multiples of 3
; 1 represents 5, and 1+5*N represent multiples of 5
; etc

sieve = 0     ; base of sieve

stride = 0    ; overlaps first entry of sieve


irq:
	lda #$fe : sta DEBUGPORT
	rti

entry:

	lda #0
	ldy #$7f
initloop:
	sta sieve,y : dey : bpl initloop

	iny ; to 0

candidateloop:
	ldx sieve,y : bmi nextcandidate

	; delay a bit
	ldx #0 : lda #0 : clc
delay:
	inx : bne delay
	adc #1 : bne delay

	; Output this value
	iny : tya : dey         ; A = Y+1
	sec : rol               ; A = (Y+1)*2+1
	sta DEBUGPORT

	; If it's more than 127 then we don't need to update the sieve
	bmi nextcandidate

	; Store the value - it's also how quickly we need to walk through the sieve
	sta stride

	; Start from the existing sieve element plus the stride
	tya : bra updatesieveloopentry

updatesieveloop:
	tax : sec : ror sieve,x
updatesieveloopentry:
	clc : adc stride
	bpl updatesieveloop         ; if it's not wrapped then it's still within the sieve's range

nextcandidate:
	iny
	cpy #$7f
	bne candidateloop

stop:
	bra stop

