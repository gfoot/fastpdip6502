; Serial input test using 65C22
;
; Connect RX to CB2
;
; We watch for CB2 interrupt, then enable shift register under T2 control to read a byte, then
; disable the shift register again so we can watch for another CB2 interrupt.
;
; We need the first sample to be taken about 1.5 baud periods after the interrupt.  Generally
; during the operation T2L must be set to two less than half of the number of PHI2 clocks 
; between samples.  For the first sample then we need to add an extra such period - to do this 
; we should set T2 initially to double the intended value, before initiating the operation, 
; and then reduce it to the intended amount.
;
; e.g. for 115200 baud, each bit lasts 8.68us.  If the I/O clock is 16MHz then we need 139 PHI2
; periods between samples, giving 8.69us of delay between bits, an error of only 0.1%.  We need 
; to wait an extra half period (139/2 = 69 clocks) before reading the first sample, so that we 
; sample in the middle of the bit period - so the initial wait before sampling should be 208 
; PHI2 periods.  To achieve that we set T2L to 208-69-2 = 137, and then read a dummy value from 
; SR to trigger the operation.  Then we set T2L to 69-2 = 67 for the rest of the byte.
; 
; The VIA waits 139 PHI2 cycles and then toggles CB1 low, and reloads T2 from its latch (67). 
; It waits a further 67+2 = 69 cycles, then toggles CB1 high, and reads the first bit from CB2.  
; This is now 139+69 = 208 PHI2 periods after the SR read, or 13us - which is roughly one and a 
; half bit periods as desired.  For the rest of the operation the VIA waits for two T2 periods 
; between bits, i.e. 69*2=138 PHI2 cycles, or 8.63us - slightly less than we'd like, but close 
; enough.
;
; We may want to reduce the preloaded T2 value to compensate for the delay since the edge of 
; CB2 that triggered the operation.


VIA_BASE = $ff20

VIA_PORTB = VIA_BASE+0
VIA_PORTA = VIA_BASE+1
VIA_DDRB = VIA_BASE+2
VIA_DDRA = VIA_BASE+3
VIA_T1CL = VIA_BASE+4
VIA_T1CH = VIA_BASE+5
VIA_T1LL = VIA_BASE+6
VIA_T1LH = VIA_BASE+7
VIA_T2CL = VIA_BASE+8
VIA_T2CH = VIA_BASE+9
VIA_SR = VIA_BASE+10
VIA_ACR = VIA_BASE+11
VIA_PCR = VIA_BASE+12
VIA_IFR = VIA_BASE+13
VIA_IER = VIA_BASE+14
VIA_PORTANH = VIA_BASE+15

; Number of I/O clocks per baud bit
BAUD_TICKS = 16000000 / 115200

; Latency before T2 is loaded after start bit begins.  This depends on the amount of work 
; the IRQ handler does and the ratio between the CPU clock and the I/O clock, and also whether 
; IRQs were disabled or an IRQ was already being handled, etc
IRQLATENCY_TICKS = BAUD_TICKS/2 ;66 * 16000 / 25175

entry:
	ldx #$ff : txs

	ldy #payloadsize
copyloop:
	lda payload-1,y : sta ramcodebase-1,y
	dey : bne copyloop

	lda #$f9 : sta DEBUGPORT

	jmp ramentry

payload:

serial_in_buffer = $200
zp_serial_in_head = $80
zp_serial_in_tail = $81
zp_serial_error = $82

* = $300

ramcodebase:

ramentry:

	lda #1 : sta DEBUGPORT

	stz zp_serial_in_head
	stz zp_serial_in_tail

	; Disable VIA interrupts and clear all flags
	lda #$7f : sta VIA_IER : sta VIA_IFR

	; Disable shift register, other features don't matter
	lda #0 : sta VIA_ACR

	; Define CB2 interrupt to occur on falling edge, other Cxx interrupts don't matter
	lda #0 : sta VIA_PCR

	; Enable CB2 interrupt and SR interrupt
	lda #$8c : sta VIA_IER
	cli

	; Wait for data
loop:
	bit zp_serial_error : bmi stop

	ldy zp_serial_in_tail : cpy zp_serial_in_head : beq loop

	iny : lda serial_in_buffer,Y
	sty zp_serial_in_tail

	ldy #4
swaploop:
	asl : ror 0
	asl : ror 0
	dey : bne swaploop

	lda 0 : sta DEBUGPORT

	bra loop

stop:
	bra stop


irq:
	; It should be either a CB2 interrupt or a shift register interrupt
	pha
	lda VIA_IFR
	lsr : lsr : lsr : bcs serial_interrupt_sr    ; check for SR interrupt (bit 2)
	lsr : bcs serial_interrupt_cb2               ; check for CB2 interrupt (bit 3)

	; otherwise it's a stray interrupt for some reason - signal an error and return
	lda #$f1 : sta DEBUGPORT
	pla : rti


serial_interrupt_cb2:
	lda #BAUD_TICKS-IRQLATENCY_TICKS-2 : sta VIA_T2CL	; set T2 larger, to wait an extra half-bit before the first sample
	stz VIA_T2CH										; start T2 right away as enabling the SR doesn't seem to do this consistently
	lda #$04 : sta VIA_ACR : bit VIA_SR					; enable the shift register and issue a dummy read to start it
	asl : sta VIA_IER									; disable the CB2 interrupt while we read the data
	lda #(BAUD_TICKS/2)-2 : sta VIA_T2CL				; set T2 to half the bit gap, minus two, for the rest of the byte

	pla : rti


serial_interrupt_sr:
	stz VIA_ACR					; disable shift register
	lda #$08 : sta VIA_IFR		; clear CB2 flag
	lda #$88 : sta VIA_IER		; enable CB2 interrupt

	lda VIA_SR                  ; read the byte

	phy
	ldy zp_serial_in_head
	iny : cpy zp_serial_in_tail : beq serial_in_full

	sta serial_in_buffer,Y
	sty zp_serial_in_head
	
	ply : pla : rti


serial_in_full:
	lda #$f6 : sta DEBUGPORT
	lda #$ff : sta zp_serial_error
	ply : pla : rti


ramcodeend:

payloadsize = ramcodeend-ramcodebase
#print payloadsize

* = payload + payloadsize

