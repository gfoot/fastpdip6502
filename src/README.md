# 6502 assmebler source code

## Building

This is designed to be built with the "xa" assembler.  There's a Makefile here
to build it.

You can edit the Makefile to change the base address for ROM images.  If you're
writing a 32K ROM you want this to be $8000, and if it's an 8K ROM you want
$e000, and if for some reason you have an even smaller ROM then you can set a
higher start address - just set it so that the ROM will end at $ffff.  The
source code itself will then pad the ROM image with zeros at the beginning, to
align the code where it wants it to be (usually $fe00).

The Makefile also allows you to pick one ROM image to be burned via minipro
when you run "make burn".  You also need to define the minipro device type.

## Types of code

The code is split into various subdirectories:

* roms - ROM images that can be burned into EEPROM or similar
* apps - Application code that can be loaded through the serial bootstrapper
* tests - Some test programs that can be run through roms/test16.s or roms/test64.s - some are very old and may not work
* utils - Utility routines mostly for the apps
* os - Work-in-progress operating system code, which can either live in a ROM or be loaded as an app

Broadly, if the serial bootstrapper is working (roms/boot64.s is best) then use
that to load and run apps.  If not, use other ROMs such as test64.s to run test
programs to figure out what's not working - or make your own ROMs that do
things directly to diagnose what's wrong.

Or if you didn't build the serial interface board, then you'll need to find
some other way to get code onto the system - e.g. copying it from ROM, SD card,
etc.

Note that code running from ROM runs very slowly (equivalent to maybe 2MHz) so
whatever you do, you should plan for code to be loaded into RAM wherever
possible.

## Serial Server

The serial server is in the "server" directory.  It contains a list of apps and
their load addresses and execution addresses.  If you create new apps then
you'll need to list them there, it should be fairly obvious how that works.

You may also need to change the serial baud rate and possibly device name in
the Python code depending on your system.  With my published serial module, the
baud rate will be 1/32 of the I/O clock speed, e.g. for an 8MHz I/O clock, the
baud rate is 250000.

