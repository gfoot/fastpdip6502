# Fast PDIP 6502 project sources

This is my attempt at making a fast 6502-based computer, overclocking the CPU to 32MHz and 
beyond, while retaining a 70s/80s-style parallel architecture, with ISA-style expansion slots,
using only PDIP and through-hole components.

See https://hackaday.io/project/192630-fast-pdip-6502-computer for more details including
photos, schematics, and a more complete description of the development and theory of the
project.

This repository contains:

* hardware/breadboard - schematics and "PCB" layout files for the breadboard prototype
* hardware/pcb - schematics, PCB layouts, gerbers, etc for the all the PCBs
* pld - various PLD module code required by different versions
* server - Python serial server code
* src - 6502 assembler code
* utils - other utility scripts

See also other READMEs:
* [src/README.md](src/README.md)
* [hardware/pcb/README.md](hardware/pcb/README.md)
* [hardware/breadboard/README.md](hardware/breadboard/README.md)

# Building

The hardware files need to be loaded into KiCad 7.0 for editing, exporting gerbers, etc.

The gerber zips can be sent straight to a PCB manufacturer if you just want the same PCBs that
I am using.

The PLD files are built using WinCupl.  I do this from the command line but you can also do it
in the GUI if you prefer.

The 6502 assembler source is built using xa, which is easy to install under Ubuntu at least.  One build
step requires use of Python to create a #include file - I use Python 3 for this.  There's a Makefile in
the "src" directory.

The serial server program is also written in Python, for Python 3.

All of this is run on Ubuntu Linux but you should be able to port it to other systems.

