#BURN = ../bin/test64.rom
BURN = ../bin/boot64.rom
#BURN = ../bin/serial2.rom

ROMTYPE = AT28C64B
ROMBASE = E000

#ROMTYPE = AT28C256E
#ROMBASE = 8000


ROMNAMES = boot test16 test64 boot64 os boot debugport_ramtest serial1 serial2
ROMS = $(addprefix ../bin/,$(addsuffix .rom, $(ROMNAMES)))

APPS = $(patsubst apps/%.s, ../bin/apps/%.bin, $(wildcard apps/*.s))

all: $(ROMS) $(APPS)

burn: $(BURN)
	minipro -p $(ROMTYPE) -w $<


../bin/os.rom: roms/os.s $(wildcard os/*.s)

../bin/test16.rom: roms/test16.s $(wildcard tests/test-*.s)

../bin/test64.rom: roms/test64.s $(wildcard tests/test64-*.s)


../bin/%.rom ../labels/%.labels: roms/%.s
	xa -o ../bin/$*.rom $< -M -DROMBASE=$(ROMBASE) -l ../labels/$*.labels

../bin/apps/osapp.bin: apps/osapp.s $(wildcard os/*.s)

../bin/apps/%.bin: apps/%.s ../labels/boot64.inc $(wildcard utils/*.s)
	xa -o $@ $< -M -I ../labels

../labels/%.inc: ../labels/%.labels
	python3 ../utils/genimports.py $< $@


.PRECIOUS: ../labels/%.inc

