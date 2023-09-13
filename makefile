#!/usr/bin/make -f
#
# Makefile for NES game
# Copyright 2011-2014 Damian Yerrick
# Modification by Persune 2023
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#

# These are used in the title of the NES program and the zip file.
filetitle = $(title)-$(version)
title = nesdev-compo-2023
version = 0.0.0

# Space-separated list of assembly language files that make up the
# PRG ROM.  If it gets too long for one line, you can add a backslash
# (the \ character) at the end of the line and continue on the next.
objlist = header action53 main pads graphics tokumaru/decompress music bhop

# image files
imglist = img_0 img_1 img_title


AS65 = ca65 $(CFLAGS65)
LD65 = ld65 $(LDFLAGS65)
CFLAGS65 = -g
LDFLAGS65 = -v
MAPPERCFG = config.cfg
objdir = obj
srcdir = src
imgdir = gfx
outdir = output
musdir = music/no_guarantees
make_dirs = $(objdir) $(objdir)/tokumaru $(objdir)/bhop $(outdir) $(imgoutdirlistmac)

# Occasionally, you need to make "build tools", or programs that run
# on a PC that convert, compress, or otherwise translate PC data
# files into the format that the NES program expects.  Some people
# write their build tools in C or C++; others prefer to write them in
# Perl, PHP, or Python.  This program doesn't use any C build tools,
# but if yours does, it might include definitions of variables that
# Make uses to call a C compiler.
CC = gcc
CFLAGS = -std=gnu99 -Wall -DNDEBUG -O

# Windows needs .exe suffixed to the names of executables; UNIX does
# not.  COMSPEC will be set to the name of the shell on Windows and
# not defined on UNIX.  Also the Windows Python installer puts
# py.exe in the path, but not python3.exe, which confuses MSYS Make.
ifeq ($(OS), Windows_NT)
DOTEXE:=.exe
PY:=py
else
DOTEXE:=
PY:=
endif

.PHONY: build_dirs all dist zip clean rebuild

all: $(outdir)/$(filetitle).nes

rebuild: clean $(outdir)/$(filetitle).nes

# Rule to create or update the distribution zipfile by adding all
# files listed in zip.in.  Actually the zipfile depends on every
# single file in zip.in, but currently we use changes to the compiled
# program, makefile, and README as a heuristic for when something was
# changed.  It won't see changes to docs or tools, but usually when
# docs changes, README also changes, and when tools changes, the
# makefile changes.
dist: zip
zip: $(filetitle).zip
$(filetitle).zip: zip.in $(outdir) README.md CHANGES.txt $(objdir)/index.txt
	zip -9 -u $@ -@ < $<

# Build zip.in from the list of files in the Git tree
zip.in:
	git ls-files | grep -e "^[^.]" > $@
	echo $(filetitle).nes >> $@
	echo zip.in >> $@

$(objdir)/index.txt: makefile
	echo Files produced by build tools go here > $@

# make sure that files actually exist before deleting them
clean:
	if [ "$(wildcard $(objdir)/*)" ]; then rm -rf $(objdir)/*; fi
	if [ "$(wildcard $(outdir)/*)" ]; then rm -rf $(outdir)/*; fi

# Rules for PRG ROM

objlistmac = $(foreach o,$(objlist),$(objdir)/$(o).o)
imgoutdirlistmac = $(foreach o,$(imglist),$(objdir)/$(o))

imgbmprawlistmac = $(foreach o,$(imglist),$(o)/$(o).bmp)
imgmiscrawlistmac = $(foreach o,$(imglist),$(o)/pal $(o)/attr $(o)/oam)
imgmiscsrclistmac = $(foreach o,$(imgmiscrawlistmac),$(objdir)/$(o).s)
imgmiscobjlistmac = $(foreach o,$(imgmiscrawlistmac),$(objdir)/$(o).o)

imgbanksrawlistmac = $(foreach o,$(imglist),$(o)/bank_0 $(o)/bank_1 $(o)/bank_2 $(o)/bank_s)
imgbankscmplistmac = $(foreach o,$(imgbanksrawlistmac),$(objdir)/$(o).toku)
imgbankschrlistmac = $(foreach o,$(imgbanksrawlistmac),$(objdir)/$(o).chr)
imgbanksbmplistmac = $(foreach o,$(imgbanksrawlistmac),$(objdir)/$(o).bmp)
imgoutbmplistmac = $(foreach o,$(imgbmprawlistmac),$(objdir)/$(o))
imginbmplistmac = $(foreach o,$(imgbmprawlistmac),$(imgdir)/$(o))


$(outdir)/map.txt $(outdir)/$(filetitle).nes: $(make_dirs) $(objlistmac)
	$(LD65) --dbgfile $(outdir)/$(filetitle).dbg -o $(outdir)/$(filetitle).nes -m $(outdir)/map.txt -C $(srcdir)/$(MAPPERCFG) $(objlistmac)

$(objdir)/%.o: $(srcdir)/%.s
	$(AS65) $< -o $@

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $< -o $@


# Files that depend on .incbin'd files

$(objdir)/music.o: $(objdir)/music.asm

$(objdir)/graphics.o: \
	$(imgbankscmplistmac) \
	$(imgmiscsrclistmac) \
	$(objdir)/universal.toku \


# Rules for Dn-FT exports

$(objdir)/music.asm: $(musdir)/music.asm 
	cp $< $@


# Rules for CHR data

$(objdir)/%.toku: $(objdir)/%.chr tools/tokumaru/tokumaru
	tools/tokumaru/tokumaru -e3 -16 $< $@

# some preprocessed CHR can be directly copied
$(objdir)/%.chr: $(imgdir)/%.chr
	cp $< $@

# convert seperate indexed bitmap into 4k CHR
$(objdir)/%.chr: $(objdir)/%.bmp
	$(PY) tools/pilbmp2nes.py $< $@

$(objdir)/%.bmp: $(imgdir)/%.bmp
	cp $< $@

# prepare input bitmaps
# ensure the bmp2toku pipeline is preserved
$(imgbankscmplistmac): $(imgbankschrlistmac)
$(imgbankschrlistmac): $(imgbanksbmplistmac)
$(imgbanksbmplistmac): $(imgoutbmplistmac)
$(imgoutbmplistmac): $(imginbmplistmac)
$(imginbmplistmac): $(imgbmprawlistmac)
$(imgbmprawlistmac):
	cp $(imgdir)/$@ $(objdir)/$@
	$(PY) tools/preprocess_bmp.py $(imgdir)/$@ $(dir $(objdir)/$@)

# prepare auxilliary data
$(imgmiscobjlistmac): $(imgmiscsrclistmac)
$(imgmiscsrclistmac): $(imgmiscrawlistmac)
$(imgmiscrawlistmac):
	cp $(imgdir)/$@.s $(objdir)/$@.s

# Rules for directories

 $(make_dirs):
	@mkdir -p -v $@ 2>/dev/null


# Rules for external tools

tools/tokumaru/tokumaru:
	cd tools/tokumaru && $(MAKE) tokumaru
