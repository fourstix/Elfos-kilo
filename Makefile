# Elfos-kilo - the kilo full screen editor for Elf/OS.
#
# Needs Asm/02 and Link/02. "make" assembles everything in src/ and
# links the editor as src/kilo.elfos, the same file src/build.bat
# produces. Copy it over bin/kilo.elfos to update the binary kept in
# the repository.

ASM     ?= /opt/elfc/asm02
LINK    ?= /opt/elfc/link02

ASMFLAGS ?= -L -D1802MINIPLUS
LFLAGS   ?= -e

# kilo.prg must be first: it holds the program header and entry point.
# kilo_data.prg must be last: the text buffer starts where the program
# ends and grows upward from there.
MODULES = kilo kilo_util kilo_cfg kilo_line kilo_str kilo_buf kilo_keys \
	kilo_text kilo_move kilo_edit kilo_input kilo_prmpt kilo_file \
	kilo_spill kilo_data

PRGS = $(patsubst %,%.prg,$(MODULES))

HEADERS = src/include/kilo_def.inc src/include/ops.inc \
	src/include/bios.inc src/include/kernel.inc src/kilo_dbg.inc

.PHONY: all clean

all: src/kilo.elfos

src/kilo.elfos: $(patsubst %,src/%,$(PRGS))
	cd src && $(LINK) $(LFLAGS) $(PRGS)

src/%.prg: src/%.asm $(HEADERS)
	cd src && $(ASM) $(ASMFLAGS) $*.asm

clean:
	rm -f src/kilo.elfos src/kilo.lkb
	rm -f src/*.prg src/*.lst src/*.build
