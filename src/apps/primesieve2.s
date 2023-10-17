; Prime Sieve - BigEd's idea
;
; To find primes up to 1,000,000 we only need to eliminate multiples of primes up to 1000.
; So find those first, then run a series of sieves over the full range up to 1,000,000,
; initialising each sieve only with the results of the primes less than 1000.
;
; The memory constraints are much more relaxed this way and the sieve can store one 
; candidate per byte, considering all odd numbers as candidates.
;
; The sieve size is configurable but must be greater than 500.  On the first pass only 
; the first 500 entries are used, with the sieve being dynamically updated, to generate
; the primes up to 1000.  These are stored in a separate list, two bytes per prime.
;
; There are less than 256 such primes, so storing the high and low bytes in separate 
; pages makes sense rather than interleaving them, and allows for a single-byte index
; to be used.
;
; Also stored is the offset to the first instance of a multiple of each such prime in 
; the next sieve - again two bytes per prime, with high and low bytes stored separately.




#include "boot64.inc"

#include "utils/via.s"

;#define VERBOSE

zp_n = $20              ; 3 bytes
zp_addr = $23           ; 2 bytes
zp_numlowprimes = $25   ; 1 byte
zp_elimptr = $26        ; 2 bytes
zp_sievebasepage = $28  ; 2 bytes
zp_nprimes = $2a        ; x3  how many were found
zp_time = $2d           ; x2  elapsed time


sieve_pages = 64     ; must be at least 2


data_sieve = $1000
data_sieve_end = data_sieve + 256*sieve_pages

data_lowprimes_lo = data_sieve_end
data_lowprimes_hi = data_sieve_end + $100
data_residues_lo = data_sieve_end + $200
data_residues_hi = data_sieve_end + $300



* = $200

irqentry:
	jmp irq

entry:
.(
	ldx #$ff : txs

	stz zp_nprimes : stz zp_nprimes+1 : stz zp_nprimes+2

	stz zp_time : stz zp_time+1
#ifndef VERBOSE
	ldx #$40 : stx VIA_ACR
	ldx #<8000 : stx VIA_T1CL
	ldx #>8000 : stx VIA_T1CH
	ldx #$7f : stx VIA_IER
	ldx #$c0 : stx VIA_IER

	cli
#endif

#ifdef VERBOSE
	; Print the first prime explicitly
	jsr printimm
	.byte '2 ',0
#endif

	lda #1 : sta zp_nprimes

	jsr clear_sieve
	jsr first_sieve

loop:
	jsr init_new_sieve
	jsr do_sieve
	bra loop
.)


clear_sieve:
.(
	; Clear the sieve
	lda #>data_sieve : sta zp_addr+1
	stz zp_addr
	ldx #sieve_pages
	ldy #0
	tya
loop:
	sta (zp_addr),y
	iny
	bne loop
	inc zp_addr+1
	dex
	bne loop
	rts
.)


first_sieve:
.(
	stz zp_numlowprimes
	stz zp_n+2

	; It's easier to write this loop twice - once for the first 256 bytes,
	; then again for the second 256 bytes

.(
	; First 256 bytes of sieve, skipping byte 0 as that corresponds to 1
	ldx #1
loop:
	bit data_sieve,x
	bmi notprime

	; Calculate prime's value and store it in list
	ldy zp_numlowprimes
	txa : sec : rol   ; C,A = 2*X + 1
	sta data_lowprimes_lo,y : sta zp_n
	rol : and #1      ; C => A
	sta data_lowprimes_hi,y : sta zp_n+1

#ifdef VERBOSE
	phx : ldx #<zp_n
	jsr printdecu24 : jsr printspace
	plx
#endif

.(
	inc zp_nprimes : bne nocarry
	inc zp_nprimes+1 : bne nocarry
	inc zp_nprimes+2
nocarry:
.)

	; Eliminate its multiples and store the residue
	stx zp_elimptr
	lda #>data_sieve : sta zp_elimptr+1

elimloop:
	lda #$80 : sta (zp_elimptr)
	clc
	lda zp_elimptr : adc zp_n : sta zp_elimptr
	lda zp_elimptr+1 : adc zp_n+1 : sta zp_elimptr+1

	; Stop when we reach the page 2 above data_sieve
	; Note carry is clear by this point so only add 1 to data_sieve rather than 2
	sbc #>data_sieve+$100 : bcc elimloop

	; Store the residue
	sta data_residues_hi,y
	lda zp_elimptr : sta data_residues_lo,y

	iny
	sty zp_numlowprimes

notprime:
	inx
	bne loop
.)

.(
	; Second 256 bytes of sieve
	ldx #0
loop:
	bit data_sieve+$100,x
	bmi notprime

	; Calculate prime's value and store it in list
	ldy zp_numlowprimes
	txa : sec : rol   ; C,A = 2*X + 1 = 512 less than prime's value
	sta data_lowprimes_lo,y : sta zp_n
	rol : and #1 : ora #2     ; C => A, and add 512
	sta data_lowprimes_hi,y : sta zp_n+1

#ifdef VERBOSE
	phx : ldx #<zp_n
	jsr printdecu24 : jsr printspace
	plx
#endif

.(
	inc zp_nprimes : bne nocarry
	inc zp_nprimes+1 : bne nocarry
	inc zp_nprimes+2
nocarry:
.)

	; No need to eliminate multiples - they'll all be out of range - 
	; but we do need to calculate the residue, which is just the prime 
	; added to its index in the sieve, minus the sieve size

	clc
	txa : adc zp_n : sta data_residues_lo,y

	; High byte is C + 1 + [zp_n+1] - 2
	;  = C + [zp_n+1] - 1
	lda #$ff : adc zp_n+1 : sta data_residues_hi,y
	iny
	sty zp_numlowprimes

notprime:
	inx
	bne loop
.)

.(
	; Reduce the size of the prime/residue lists to only include primes less than 1000,
	; as higher primes don't need to be eliminated from later sieves
	ldy zp_numlowprimes
loop:
	dey
	lda data_lowprimes_lo,y
	cmp #<1000
	bcs loop
	iny
	sty zp_numlowprimes
.)

	; We've completed two pages of sieve-space now
	lda #>512 : sta zp_sievebasepage
	stz zp_sievebasepage+1

	rts
.)



init_new_sieve:
.(
	jsr clear_sieve
	
	; Loop over low primes, eliminating their multiples from the new sieve
.(
	ldx zp_numlowprimes
	dex
loop:
	clc
	lda data_residues_lo,x : tay : stz zp_elimptr
	lda data_residues_hi,x : adc #>data_sieve : sta zp_elimptr+1

	lda data_lowprimes_lo,x : sta zp_n
	lda data_lowprimes_hi,x : sta zp_n+1

	bne elimloop_large_n
	inc ; make sure A is not zero

elimloop_small_n:
	;lda #$80   ; unnecessary - A is never zero at this point
	sta (zp_elimptr),y

	; carry is clear
	tya : adc zp_n : tay
	bcc elimloop_small_n
	lda zp_elimptr+1 : adc #0 : sta zp_elimptr+1

	; Stop after end of sieve
	; Note carry is clear by this point so add 1 less than otherwise to data_sieve
	sbc #>data_sieve_end - $100
	bcc elimloop_small_n

	bra store_residue

elimloop_large_n:
	;lda #$80   ; unnecessary - A is never zero at this point
	sta (zp_elimptr),y

	; carry is clear
	tya : adc zp_n : tay
	lda zp_elimptr+1 : adc zp_n+1 : sta zp_elimptr+1

	; Stop after end of sieve
	; Note carry is clear by this point so add 1 less than otherwise to data_sieve
	sbc #>data_sieve_end - $100
	bcc elimloop_large_n

store_residue:
	; Store the new residue
	sta data_residues_hi,x
	tya : sta data_residues_lo,x

	; Next prime
	dex
	cpx #$ff : bne loop
.)

	rts
.)


do_sieve:
.(
	ldy #0
	lda #>data_sieve : sta zp_addr+1
	stz zp_addr
loop:
	lda (zp_addr),y : bne notprime

	; Calculate value
	clc
	tya : sec : rol : sta zp_n
	lda zp_sievebasepage : rol : sta zp_n+1
	lda zp_sievebasepage+1 : rol : sta zp_n+2

	; 1 million = $0f4240
	; 948631 = $0e7997
	cmp #$0f : bcc notlast
	lda zp_n+1 : cmp #$42 : bcc notlast
	lda zp_n : cmp #$40 : bcc notlast
	jmp end

notlast:
#ifdef VERBOSE
	ldx #<zp_n : jsr printdecu24 : jsr printspace
#endif

.(
	inc zp_nprimes : bne nocarry
	inc zp_nprimes+1 : bne nocarry
	inc zp_nprimes+2
nocarry:
.)

notprime:
	iny : bne loop

.(
	inc zp_sievebasepage
	bne nocarry
	inc zp_sievebasepage+1
nocarry:
.)

	inc zp_addr+1
	lda zp_addr+1 : cmp #>data_sieve_end : bne loop

	rts
.)


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

#print *
