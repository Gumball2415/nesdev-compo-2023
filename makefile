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
version = 0.0.1

# Space-separated list of assembly language files that make up the
# PRG ROM.  If it gets too long for one line, you can add a backslash
# (the \ character) at the end of the line and continue on the next.
objlist = header action53 main pads graphics donut music bhop

# image files
imglist = img_0 img_1


AS65 = ca65 $(CFLAGS65)
LD65 = ld65 $(LDFLAGS65)
CFLAGS65 = -g
LDFLAGS65 = -v
MAPPERCFG = config.cfg
objdir = obj
srcdir = src
imgdir = gfx
outdir = output
musdir = music
make_dirs = $(objdir) $(outdir) $(imgoutdirlistmac) $(objdir)/img_title

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
imgmiscrawlistmac = $(foreach o,$(imglist),$(o)/pal $(o)/oam)
imgmiscsrclistmac = $(foreach o,$(imgmiscrawlistmac),$(objdir)/$(o).s)

imgattrlistmac = $(foreach o, $(imglist),$(objdir)/$(o)/attr.bin)
imgpartialnamlistmac = $(foreach o, $(imglist),$(objdir)/$(o)/attr.nam)

imgbanksrawlistmac = $(foreach o,$(imglist),$(o)/bank_0 $(o)/bank_1 $(o)/bank_2 $(o)/bank_s)
imgbankscmplistmac = $(foreach o,$(imgbanksrawlistmac),$(objdir)/$(o).donut)
imgbankschrlistmac = $(foreach o,$(imgbanksrawlistmac),$(objdir)/$(o).chr)
imgbanksbmplistmac = $(foreach o,$(imgbanksrawlistmac),$(objdir)/$(o).bmp)


$(outdir)/map.txt $(outdir)/$(filetitle).nes: $(make_dirs) $(objlistmac)
	$(LD65) --dbgfile $(outdir)/$(filetitle).dbg -o $(outdir)/$(filetitle).nes -m $(outdir)/map.txt -C $(srcdir)/$(MAPPERCFG) $(objlistmac)

$(objdir)/%.o: $(srcdir)/%.s
	$(AS65) $< -o $@

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $< -o $@


# Files that depend on .incbin'd files

# this area is unused, better fill it with something anyway
$(objdir)/header.o: $(objdir)/2A03_MEMORY_DUMP_TRACKED_DATA
$(objdir)/2A03_MEMORY_DUMP_TRACKED_DATA: $(srcdir)/2A03_MEMORY_DUMP_TRACKED_DATA
	cp $< $@

$(objdir)/music.o: $(objdir)/music.asm

$(objdir)/graphics.o: \
	$(objdir)/img_title/bank_0.donut \
	$(objdir)/img_title/oam.s \
	$(objdir)/img_title/img_title_nam.donut \
	$(objdir)/universal.donut \
	$(objdir)/universal_pal.s \
	$(objdir)/img_index.s


# Rules for Dn-FT exports

$(objdir)/music.asm: $(musdir)/music.asm
	cp $< $@


# Rules for CHR data

# some preprocessed CHR can be directly copied
$(objdir)/%.chr: $(imgdir)/%.chr
	cp $< $@

# convert seperate indexed bitmap into 4k CHR
$(objdir)/%.chr: $(objdir)/%.bmp
	$(PY) tools/pilbmp2nes.py $< $@

$(objdir)/%.bmp: $(imgdir)/%.bmp
	cp $< $@

# prepare input bitmaps
# ensure the bmp 2 donut pipeline is preserved
$(objdir)/img_index.s: \
	$(imgbankscmplistmac) \
	$(imgmiscsrclistmac) \
	$(imgattrlistmac)
	$(PY) tools/img_index.py --input_images $(imglist) --obj_dir $(objdir)

$(imgbankscmplistmac): $(imgbankschrlistmac)
$(imgbankschrlistmac): $(imgbanksbmplistmac)
$(imgbanksbmplistmac): $(imgbmprawlistmac)
$(imgbmprawlistmac):
	cp $(imgdir)/$@ $(objdir)/$@
	$(PY) tools/preprocess_bmp.py $(imgdir)/$@ $(dir $(objdir)/$@)

# prepare attribute tables
$(imgattrlistmac): $(imgpartialnamlistmac)
$(imgpartialnamlistmac): $(imgbmprawlistmac) $(imgmiscsrclistmac)

$(imgattrlistmac): $(objdir)/%/attr.bin: $(objdir)/%/attr.nam
	tail -c +961 $< > $@

# prepare auxilliary data
$(imgmiscsrclistmac): $(imgmiscrawlistmac)
$(imgmiscrawlistmac):
	cp $(imgdir)/$@.s $(objdir)/$@.s

# donut is under GPL v3, so we just import it via git submodule
$(objdir)/%.donut: $(objdir)/%.chr tools/external/action53/tools/donut$(DOTEXE)
	tools/external/action53/tools/donut$(DOTEXE) -fq $< $@

tools/external/action53/tools/donut$(DOTEXE):
	cd tools/external/action53 && $(MAKE) tools/donut$(DOTEXE)

# Rules for directories

$(make_dirs):
	@mkdir -p -v $@ 2>/dev/null


# Rules for external tools



# Rules that require secondary expansion:
.SECONDEXPANSION:

# use savtool to generate attribute tables
$(imgpartialnamlistmac): $(objdir)/%/attr.nam: $(objdir)/$$*/$$*.bmp $$(dir $$@)/pal.s
	$(PY) tools/savtool.py \
	--palette=`grep '\.byte' $(dir $@)pal.s | \
	sed -Ez 's/\s*\.byte (\S*)\s*/\1/g;s/[\$$,]//g;s/\n/ /g' | head -c 32` \
	--attr-only $< $@

# special handling for title card

$(objdir)/img_title/bank_0.donut: $(objdir)/img_title/bank_0.chr
	tools/external/action53/tools/donut$(DOTEXE) -fq $< $@

$(objdir)/img_title/img_title_nam.donut: $(objdir)/img_title/img_title.nam
	tools/external/action53/tools/donut$(DOTEXE) -fq $< $@

$(objdir)/img_title/bank_0.chr: $(objdir)/img_title/img_title.sav
	head -c +4096 $< > $@

$(objdir)/img_title/img_title.nam: $(objdir)/img_title/img_title.bmp $(objdir)/universal_pal.s
	$(PY) tools/savtool.py  \
	--palette=`grep '\.byte' $(objdir)/universal_pal.s | \
	sed -Ez 's/\s*\.byte (\S*)\s*/\1/g;s/[\$$,]//g;s/\n/ /g' | head -c 32` $< $@

$(objdir)/img_title/img_title.sav: $(objdir)/img_title/img_title.bmp $(objdir)/universal_pal.s
	$(PY) tools/savtool.py \
	--palette=`grep '\.byte' $(objdir)/universal_pal.s | \
	sed -Ez 's/\s*\.byte (\S*)\s*/\1/g;s/[\$$,]//g;s/\n/ /g' | head -c 32` $< $@

$(objdir)/universal_pal.s: universal_pal.s
universal_pal.s:
	cp $(imgdir)/$@ $(objdir)/$@

$(objdir)/img_title/oam.s: img_title/oam.s
img_title/oam.s:
	cp $(imgdir)/$@ $(objdir)/$@

$(imgattrlistmac): $(objdir)/%/attr.bin: $(objdir)/%/attr.nam
