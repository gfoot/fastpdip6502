; Test program for "Fast" PDIP 6502 prototype
;
; This version is for the full 16-bit address bus.
;
;   $0000-$7fff  - RAM
;   $8000-$ff00  - ROM
;   $ff00-$ffe0  - I/O; $ff70 in particular is connected to a debug output port
;   $ffe0-$ffff  - ROM - including the vectors
;
; It is possible to run code from ROM but RAM has faster access times and so ultimately the ROM will 
; start by copying itself into RAM.  However it will be useful for some test cases to run directly
; from ROM.
;
; We don't have a good way to select which program to run, so it's hard-coded.


DEBUGPORT = $ff70

* = $8000


;#include "tests/test-loop.s"
;#include "tests/test-ram-byte-00.s"
;#include "tests/test-ram-all.s"
;#include "tests/test-ram-all-16.s"
;#include "tests/test-ram-subroutines.s"
;#include "tests/test-ram-code.s"
;#include "tests/test-ram-code-16.s"
;#include "tests/test-primesieve.s"
;#include "tests/test-via-16.s"

;#include "tests/test-serial-out-viatimer.s"
;#include "tests/test-serial-out-polling.s"
;#include "tests/test-serial-out-irq.s"

;#include "tests/test-serial-in-viasr.s"
#include "tests/test-serial-inout-irq.s"

;#include "tests/test-dormann-6502.s"
;#include "tests/test-dormann-directserial.s"
;#include "tests/test-tsb.s"
;#include "tests/test-ram-tsb.s"


top:
	.dsb $ff00-*, $00
#print *-top

ioports:
	.dsb $c0, $00

morerom:
	.dsb $3a, $00

#print $fffa-*

vectors:
	.word irq
	.word entry
	.word irq

