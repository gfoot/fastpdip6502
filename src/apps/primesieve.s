; Prime Sieve
;
; Using mod-30 repetition.  For any prime p greater than 5, the remainder on division by 30 will be
; within the set {1,7,11,13,17,19,23,29} because the other numbers are all multiples of divisors of
; 30.  So we only need to store bits for these remainders.  One
; byte is enough to cover 30 prime candidates, eight of which have appropriate remainders, each 
; getting one bit within the byte.


#include "boot64.inc"

#include "utils/via.s"

;#define VERBOSE

zp_n = $20                  ; x3  current candidate
zp_addr = $23               ; x2  current address within sieve
zp_setbits_addr = $25       ; x2  where we've got to when scanning before setting bits in the sieve
zp_setbits_addr2 = $27      ; x2  where we've got to when setting bits in the sieve
zp_setbits_count = $29      ; x2  how far ahead to scan
zp_setbits_basenum = $2b    ; x1  base value when scanning for prime multiples
zp_setbits_addamount = $2d  ; x2  amount to add to address when scanning for prime multiples
zp_setbits_subamount = $2f  ; x1  amount to subtract from basenum when scanning for prime multiples
zp_nprimes = $30            ; x3  how many were found
zp_time = $33               ; x2  elapsed time


* = $200

irqentry:
	jmp irq

entry:
	ldx #$ff : txs

	stz zp_time : stz zp_time+1
#ifndef VERBOSE
	ldx #$40 : stx VIA_ACR
	ldx #<8000 : stx VIA_T1CL
	ldx #>8000 : stx VIA_T1CH
	ldx #$7f : stx VIA_IER
	ldx #$c0 : stx VIA_IER

	cli
#endif

	; Clear the sieve
	lda #>data_sieve : sta zp_addr+1
	stz zp_addr
	ldy #<data_sieve
	lda #0
clearsieveloop:
	sta (zp_addr),y
	iny
	bne clearsieveloop
	inc zp_addr+1
	bpl clearsieveloop


#ifdef VERBOSE
	; Print the early primes explicitly
	jsr printimm
	.byte '2 3 5 ',0
#endif

	ldx #3 : stx zp_nprimes
	stz zp_nprimes+1
	stz zp_nprimes+2

	; We start from 7
	lda #7 : sta zp_n : stz zp_n+1 : stz zp_n+2

	; Start at the beginning of the sieve
	lda #<data_sieve : sta zp_addr
	lda #>data_sieve : sta zp_addr+1
	
	; Start with bit 6 of the first byte, and work down
	; (Bit 7 of the first byte corresponds to 1 which is not prime.)
	ldx #6

	clc

loop:
	lda (zp_addr)
	bit data_bits,x
	beq prime

continue:
	; Advance to next candidate - carry already clear
	lda zp_n : adc data_deltas,x : sta zp_n
	bcc next
	clc
	inc zp_n+1
	bne next
	inc zp_n+2

next:
	; Next bit in byte
	dex
	bpl loop

	; Handle carry
	ldx #7

	; Increment address
	inc zp_addr
	bne loop
	inc zp_addr+1
	bpl loop

	jmp end

prime:
#ifdef VERBOSE
	; Print current candidate
	phx
	ldx #<zp_n : jsr printdecu24
	jsr printspace

	clc
	plx
#endif

.(
	; carry already clear
	lda zp_nprimes : adc #1 : sta zp_nprimes
	bcc nocarry
	inc zp_nprimes+1
	bne nocarry
	inc zp_nprimes+2
nocarry:
.)

	; If n is really large, we don't need to update the sieve
	; Compare against 1024 as that's more than the square root of the sieve size
	lda zp_n+2 : bne continue
	lda #>975 : cmp zp_n+1 : bcc continue   ; inverted test so that carry is clear if we branch
	bne doupdate
	lda #<975 : cmp zp_n : bcc continue

doupdate:
	; Update the sieve - this is trickier than usual.  We do one bit at a time.  For each bit,
	; we need to set it on every nth byte where n is the current candidate - this works because
	; n is prime greater than 7, hence coprime with 30.  But different bits need different 
	; starting points.
	;
	; If "nb" is the bit corresponding to n, then bit "b" represents the number
	;     n + data_remainders[nb] - data_remainders[b]
	; This is just n when b=nb, of course.  We need to find the next addr where this is a multiple of n.
	; Adjacent addrs differ by 30, so we can advance addresses adding 30 each time, and subtracting n if the 
	; accumulated total is greater, until we get to zero or the end of the sieve.  As n and 30 are coprime,
	; this will happen within n steps, so not too long.
	; 
	; We can save some time by considering all of the bits while counting through these n steps, rather than 
	; doing the count separately for each bit.  When we find a point where a bit's remainder is zero, we then
	; go ahead and set that bit in every nth byte from that point onwards.
	;
	; The approach is to track, for each of the next n bytes, what that byte's base value (30*byte index) is
	; modulo n, and subtract each bit's remainder from that, in turn, and if we find a zero then that bit 
	; within this byte represents a value that's a multiple of n, so we should go ahead and set the bit in
	; this byte, and every nth byte after that.
	;
	; In practice I did this in the negative direction, i.e. basenum is always negative and I add each bit's
	; remainder to it rather than subtracting.

	; So we execute n steps of:
	;   * For each bit, add its delta to basenum, and if the result is zero, execute a setbits operation
	;   * Increment address, add 30 to basenum, subtract n if it goes positive
	;
	; We can speed this up because after subtracting n it will then be necessary to add 30 at least nearly 
	; n-div-30 times, to get back near zero (and increment addr accordingly) - for large n this is a big saving.
	;
	; subamount is the amount we end up subtracting; addamount is the amount we increment addr by.
	; So subamount = n - 30*addamount, and we choose addamount>=0 so that, if possible, subamount is 
	; more than 30.


	; Record how many addresses to initially scan - this is n-1 I believe
	; carry already set
	lda zp_n : sbc #1 : sta zp_setbits_count
	lda zp_n+1 : sbc #0 : sta zp_setbits_count+1

	; The offset for the current bit is zero, so the base offset for our current address is
	; the remainder value for the current bit, and it's applied in the negative direction
	; carry already set
	lda #0 : sbc data_remainders,x : sta zp_setbits_basenum

	; Start from the current prime's address
	lda zp_addr : sta zp_setbits_addr
	lda zp_addr+1 : sta zp_setbits_addr+1

	; For large n we want subamount to be n mod 30 plus 30, and addamount to be n div 30 minus 1
	; For small n, addamount will end up negative which is no good, so we set addamount to 0 and subamount to n
	;
	; Note that n div 30 = zp_addr - data_sieve
	; carry already clear - subtract an extra 1
	lda zp_addr : sbc #<data_sieve : sta zp_setbits_addamount
	lda zp_addr+1 : sbc #>data_sieve

	; If it's negative at this point, we need to undo the subtract-1
.(
	bpl sub_ok
	inc zp_setbits_addamount
	stz zp_setbits_addamount+1
	lda zp_n : sta zp_setbits_subamount
	bra setbits_scanloop
sub_ok:
.)

	; Otherwise the subtract-1 was fine
	sta zp_setbits_addamount+1

	; add 30 to n mod 30 - i.e. data_remainders,x
	; carry already set, so adds an extra 1
	lda data_remainders,x : adc #29 : sta zp_setbits_subamount

setbits_scanloop:
	; Skip if basenum is even, because all the bit remainders are odd so none of them will match
	lda zp_setbits_basenum : and #1 : beq setbits_checkzeroloop_end
	
	; Loop over all bits
	ldy #7
	clc
	lda zp_setbits_basenum
setbits_checkzeroloop:
	; Add the bit remainder deltas to the basenum one by one, watching for when the total goes positive
	; carry stays clear throughout this loop
	adc data_deltas+1,y : bpl positive

	; Next bit
	dey
	bpl setbits_checkzeroloop

	; skip to end of loop
	bra setbits_checkzeroloop_end

positive:
	; The addition result was positive - if it's not zero then it's negative, and we can skip the remaining bits
	; as their remainders are even smaller
	bne setbits_checkzeroloop_end

	; It's zero - execute a full pass setting this bit in every nth byte starting at the current address

	lda zp_setbits_addr : sta zp_setbits_addr2
	lda zp_setbits_addr+1 : sta zp_setbits_addr2+1

	lda data_bits,y
	tay
	clc

	lda zp_n+1
	bne setbits_innerloop_large_n

setbits_innerloop_small_n:
	; Set bit Y in every nth byte after zp_setbits_addr2
	tya : ora (zp_setbits_addr2) : sta (zp_setbits_addr2)
	lda zp_setbits_addr2 : adc zp_n : sta zp_setbits_addr2
	bcc setbits_innerloop_small_n
	clc
	inc zp_setbits_addr2+1
	bpl setbits_innerloop_small_n
	bra setbits_checkzeroloop_end

setbits_innerloop_large_n:
	; Set bit Y in every nth byte after zp_setbits_addr2
	tya : ora (zp_setbits_addr2) : sta (zp_setbits_addr2)
	lda zp_setbits_addr2 : adc zp_n : sta zp_setbits_addr2
	lda zp_setbits_addr2+1 : adc zp_n+1 : sta zp_setbits_addr2+1
	bpl setbits_innerloop_large_n

setbits_checkzeroloop_end:

	; Typically we want to subtract n from basenum now, and then increment it by 30 at a time, incrementing the address as well,
	; until it's in the range [-30,-1].
	;
	; But for large n, it's quicker to increment addr by a lot at a time, and add a corresponding multiple of 30 all at once as well.
    ; We precalculated these values.

	; Subtract subamount from basenum
	sec
	lda zp_setbits_basenum : sbc zp_setbits_subamount : sta zp_setbits_basenum

	; Adjust address
	clc
	lda zp_setbits_addr : adc zp_setbits_addamount : sta zp_setbits_addr
	lda zp_setbits_addr+1 : adc zp_setbits_addamount+1 : sta zp_setbits_addr+1

	; Adjust count
	sec
	lda zp_setbits_count : sbc zp_setbits_addamount : sta zp_setbits_count
	lda zp_setbits_count+1 : sbc zp_setbits_addamount+1 : sta zp_setbits_count+1
	bcc setbits_done

setbits_checkminusthirty:
	; Check whether basenum is less than -30 - if so, we can move to the next address
	clc
	lda zp_setbits_basenum : adc #30 : bcs setbits_scanloop ; if carry, it's >=-30 so check again for bits to set

	; Next address - store the new basenum
	sta zp_setbits_basenum

.(
	; Update address
	inc zp_setbits_addr
	bne nocarry
	inc zp_setbits_addr+1
nocarry:
.)

	; Decrement iteration count
	sec
	lda zp_setbits_count : sbc #1 : sta zp_setbits_count
	lda zp_setbits_count+1 : sbc #0 : sta zp_setbits_count+1
	bcs setbits_checkminusthirty


setbits_done:
	; All done - continue searching for more primes
	jmp continue


end:
	sei

	jsr printnewline
	jsr printnewline

	ldx #<zp_nprimes
	jsr printdecu24

	jsr printimm
	.byte " primes up to ", 0

	ldx #<zp_n
	jsr printdecu24
	
	jsr printimm
	.byte " found in ", 0

	ldx #<zp_time
	jsr printdecu16

	jsr printimm
	.byte " ms", 10, 13, 0

stop:
	bra stop


irq:
	stz SER_STAT
	bit VIA_IFR
	bpl irqdone
	bit VIA_T1CL
	inc zp_time
	bne irqdone
	inc zp_time+1
irqdone:
	rti
	

#include "utils/print.s"


; Amount to add to 30*n to get a prime candidate, in order of bit index (0,1,2,..,7)
;
; So the zp_n = 30*(zp_addr-base_addr) + data_remainders[bit index]
;
data_remainders:
	.byte 29,23,19,17,13,11,7,1

; Gap to next remainder
data_deltas:
	.byte 2,6,4,2,4,2,4,6   ;,1 - shared with data_bits by accident!

; Bit lookup table
data_bits:
	.byte 1,2,4,8,$10,$20,$40,$80


; Base of sieve
data_sieve:

#print *-$200
