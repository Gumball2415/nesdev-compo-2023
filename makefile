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
title = nesdev-compo-2023
version = 0.0.0

# Space-separated list of assembly language files that make up the
# PRG ROM.  If it gets too long for one line, you can add a backslash
# (the \ character) at the end of the line and continue on the next.
objlist = header main action53 pads graphics tokumaru/decompress


AS65 = ca65 $(CFLAGS65)
LD65 = ld65 $(LDFLAGS65)
CFLAGS65 = -g
LDFLAGS65 = -v
MAPPERCFG = config.cfg
objdir = obj
srcdir = src
imgdir = gfx
outdir = output
make_dirs = $(objdir) $(outdir) $(objdir)/tokumaru

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

.PHONY: build_dirs all dist zip clean

all: build_dirs $(outdir)/$(title)-$(version).nes

# Rule to create or update the distribution zipfile by adding all
# files listed in zip.in.  Actually the zipfile depends on every
# single file in zip.in, but currently we use changes to the compiled
# program, makefile, and README as a heuristic for when something was
# changed.  It won't see changes to docs or tools, but usually when
# docs changes, README also changes, and when tools changes, the
# makefile changes.
dist: zip
zip: $(title)-$(version).zip
$(title)-$(version).zip: zip.in $(outdir) README.md CHANGES.txt $(objdir)/index.txt
	zip -9 -u $@ -@ < $<

# Build zip.in from the list of files in the Git tree
zip.in:
	git ls-files | grep -e "^[^.]" > $@
	echo $(title)-$(version).nes >> $@
	echo zip.in >> $@

$(objdir)/index.txt: makefile
	echo Files produced by build tools go here > $@

# make sure that files actually exist before deleting them
clean:
	if [ "$(wildcard $(objdir)/*)" ]; then rm -v -d -r $(objdir)/*; fi
	if [ "$(wildcard $(outdir)/*)" ]; then rm -v -d -r $(outdir)/*; fi
	cd tools/tokumaru && $(MAKE) clean

build_dirs:
	@mkdir -p $(make_dirs) 2>/dev/null


# Rules for PRG ROM

objlistntsc = $(foreach o,$(objlist),$(objdir)/$(o).o)

$(outdir)/map.txt $(outdir)/$(title)-$(version).nes: $(srcdir)/$(MAPPERCFG) $(objlistntsc)
	$(LD65) --dbgfile $(outdir)/$(title)-$(version).dbg -o $(outdir)/$(title)-$(version).nes -m $(outdir)/map.txt -C $^

$(objdir)/%.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(AS65) $< -o $@

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $< -o $@

# Files that depend on .incbin'd files
$(objdir)/graphics.o: $(objdir)/bank0.toku $(objdir)/bank1.toku $(objdir)/bank2.toku \
	$(objdir)/universal.toku

# This is an example of how to call a lookup table generator at
# build time.  mktables.py itself is not included because the demo
# has no music engine, but it's available online at
# http://wiki.nesdev.com/w/index.php/APU_period_table
$(objdir)/ntscPeriods.s: tools/mktables.py
	$(PY) $< period $@

# Rules for CHR data

$(objdir)/%.toku: $(objdir)/%.chr tools/tokumaru/tokumaru
	tools/tokumaru/tokumaru -e -16 $< $@

# TODO: raw images go here
$(objdir)/%.chr: $(imgdir)/%.chr
	cp $< $@

tools/tokumaru/tokumaru:
	cd tools/tokumaru && $(MAKE) tokumaru

# $(objdir)/%16.chr: $(imgdir)/%.png
	# $(PY) tools/pilbmp2nes.py -H 16 $< $@
