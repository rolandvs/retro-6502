# The Makefile generates a `report` that informs about the geneerated code. It is
# not always correct in reporting, although the code is correct and the assembly
# listing and disassembler output is correct.
# It has to do with mixing `.segment "CODE"` and `.segment "RODATA"`. For correct output
# any `.segment "CODE"` should be moved before `.segment "RODATA"`.
#
# Other projects need to provide a `<name>.cfg` and the `<name>.s` file along with 
# the `Makefile` to build a new project.

# use 65C02 or 6502
CPU     = 6502

NAME    = a1_lightsnd
CFG     = apple1.cfg

# ---- addresses: plain hex, no prefix (C800, 0280) ----
# ORIGIN   run address: where the code is assembled/linked to run
# MONLOAD  address the .woz file is typed into (default: ORIGIN)
# The $0280 is the lowest "safe" location to use in case of Apple-1

ORIGIN  = 0280
MONLOAD =

# normalise: $(value ...) reads the raw text, so make never expands "$C800"
# into "$(C)800"; a $ or 0x prefix is stripped, then 1-4 hex digits required
hexaddr = $(strip $(patsubst 0x%,%,$(patsubst 0X%,%,$(subst $$,,$(strip $(value $(1)))))))
ORG    := $(call hexaddr,ORIGIN)
MON    := $(or $(call hexaddr,MONLOAD),$(ORG))
$(foreach v,ORG MON,$(if $(shell echo '$($(v))' | grep -Eqx '[0-9A-Fa-f]{1,4}' || echo bad),\
  $(error $(if $(filter ORG,$(v)),ORIGIN,MONLOAD)='$($(v))' must be 1-4 hex digits without prefix, e.g. C800)))

# derived forms -- the only places a prefix appears
# (comments on their own line: a trailing "# ..." would leave spaces in the value)
# LOAD    0xC800    for srec_cat
# ASADDR  '$C800'   for ca65 / ld65 -D
LOAD    = 0x$(ORG)
ASADDR  = '$$$(ORG)'

# all generated files go here -- add "build/" to .gitignore
B       = build
OUT     = $(B)/$(NAME)

AS      = ca65
LD      = ld65
DA      = da65
SREC    = srec_cat

# all helper work (woz, info, report, abslist, help) is done by one tool
A1TOOL  = python3 tools/a1tool.py
TOOLSRC = tools/a1tool.py

# --list-bytes 0             removes truncating after 12 bytes in listing
# -D LOAD=$(ASADDR)          ORIGIN as an assembler symbol, for sources that want it;
#                            not needed for placement (the linker does that, see
#                            LDFLAGS) -- for absolute addresses see $(OUT).abs.lst
ASFLAGS = --cpu $(CPU) -g --list-bytes 0 -D LOAD=$(ASADDR) -l $(OUT).lst
# -D __LOAD__=$(ASADDR)      propagates the origin into the linker
LDFLAGS = -C $(CFG) -D __LOAD__=$(ASADDR) -m $(OUT).map -Ln $(OUT).lbl

.SUFFIXES:

all: $(OUT).bin $(OUT).hex $(OUT).s19 $(OUT).woz $(OUT).abs.lst   ## build everything + report
	@$(A1TOOL) report --name $(NAME) --bin $(OUT).bin --map $(OUT).map \
	    --origin $(ORG) --monload $(MON)

report: $(OUT).bin   ## show addresses, size and segments of the last build
	@$(A1TOOL) report --name $(NAME) --bin $(OUT).bin --map $(OUT).map \
	    --origin $(ORG) --monload $(MON)

# the build directory; "| $(B)" below = order-only: create it, but don't
# rebuild everything just because the directory's timestamp changed
$(B):
	@mkdir -p $@

$(OUT).o: $(NAME).s | $(B)
	$(AS) $(ASFLAGS) -o $@ $<

$(OUT).bin: $(OUT).o $(CFG)
	$(LD) $(LDFLAGS) -o $@ $<

$(OUT).hex: $(OUT).bin
	@echo "  SREC  $@"
	@$(SREC) $< -binary -offset $(LOAD) -o $@ -intel

$(OUT).s19: $(OUT).bin
	@echo "  SREC  $@"
	@$(SREC) $< -binary -offset $(LOAD) -header "$(NAME)" \
		-o $@ -motorola -address-length=2 \
		--disable=data-count --execution-start-address=$(LOAD)

$(OUT).woz: $(OUT).bin $(TOOLSRC)
	@echo "  WOZ   $@"
	@$(A1TOOL) woz --bin $< --load $(MON) -o $@

# ca65 listing with the real addresses from the map (works without .org)
abslist: $(OUT).abs.lst   ## listing with absolute addresses

$(OUT).abs.lst: $(OUT).bin $(TOOLSRC)
	@echo "  LIST  $@"
	@$(A1TOOL) abslist --lst $(OUT).lst --map $(OUT).map \
	    --bin $(OUT).bin --origin $(ORG) -o $@


# ---- da65 info file ----
# labels  : program labels from ld65 (-Ln), then equates ("NAME = $hhhh")
#           from $(NAME).s and from the ROM symbol files in SYMS
# ranges  : the segments in DATASEGS become RANGE blocks (from the map), so
#           strings/tables in .segment "RODATA" are not disassembled as code;
#           a hand-written $(NAME).ranges file, if present, replaces them
SYMS      ?= wozmon.inc
DATASEGS  ?= RODATA DATA
RANGETYPE ?= TextTable

info: $(OUT).info    ## generate da65 info file: labels, ROM symbols, data ranges

$(OUT).info: $(OUT).bin $(NAME).s $(SYMS) $(wildcard $(NAME).ranges) $(TOOLSRC)
	@$(A1TOOL) info --bin $(OUT).bin --start $(ORG) --cpu $(CPU) \
	    --lbl $(OUT).lbl --map $(OUT).map --sym $(NAME).s $(SYMS) \
	    --datasegs "$(DATASEGS)" --rangetype $(RANGETYPE) \
	    $(if $(wildcard $(NAME).ranges),--ranges $(NAME).ranges) -o $@
	@echo "wrote $@"


dis: $(OUT).dis      ## disassemble the linked binary using the info file

$(OUT).dis: $(OUT).bin $(OUT).info
	$(DA) -i $(OUT).info -o $@

dump: $(OUT).o       ## dump the object file
	od65 --dump-all $<

clean:               ## remove the build directory
	rm -rf $(B)

help:                ## show this help
	@echo "targets:"
	@$(A1TOOL) help $(MAKEFILE_LIST)
	@echo ""
	@echo "variables (override: make VAR=value), current values:"
	@echo "  NAME     $(NAME)     source $(NAME).s, outputs $(OUT).*"
	@echo "  ORIGIN   $(ORG)     run address, plain hex (no \$$ or 0x)"
	@echo "  MONLOAD  $(MON)     load address of the .woz file, plain hex"
	@echo "  CPU      $(CPU)"
	@echo "  CFG      $(CFG)"
	@echo "  B        $(B)       build directory"
	@echo ""
	@echo "example:  make clean && make ORIGIN=C800 MONLOAD=7800 && make dis"


.PHONY: all report abslist info dis dump clean help
