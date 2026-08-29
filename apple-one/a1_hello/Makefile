NAME    = apple1_hello
CPU     = 6502
CFG     = apple1.cfg

# the address is set w/o $ or 0x
ORIGIN  = 0280
LOAD    = 0x$(ORIGIN)

AS      = ca65
LD      = ld65
DA      = da65
SREC    = srec_cat

# --list-bytes 0             removes truncating after 12 bytes in listing 
# -D LOAD='$$$(ORIGIN)'      sets the ORIGIN address in the ASSEMBLER
#                            the 'normal' mechanism generates listings with non-resolved addresses
ASFLAGS = --cpu $(CPU) -g --list-bytes 0 -D LOAD='$$$(ORIGIN)' -l $(NAME).lst
# -D __LOAD__='$$$(ORIGIN)'  propagates the origin into the linker
#                            the linker info must have the same address, wondering how to cope with multiple segments?
LDFLAGS = -C $(CFG) -D __LOAD__='$$$(ORIGIN)' -m $(NAME).map -Ln $(NAME).lbl

.SUFFIXES:

all: $(NAME).bin $(NAME).hex $(NAME).s19 $(NAME).mon

$(NAME).o: $(NAME).s
	$(AS) $(ASFLAGS) -o $(NAME).o $(NAME).s

$(NAME).bin: $(NAME).o $(CFG)
	$(LD) $(LDFLAGS) -o $(NAME).bin $(NAME).o

$(NAME).hex: $(NAME).bin
	$(SREC) $(NAME).bin -binary -offset $(LOAD) -o $(NAME).hex -intel

$(NAME).s19: $(NAME).bin
	$(SREC) $(NAME).bin -binary -offset $(LOAD) -header "$(NAME)" \
		-o $(NAME).s19 -motorola -address-length=2 \
		--disable=data-count --execution-start-address=$(LOAD)

$(NAME).mon: $(NAME).bin
	python3 -c "d=open('$(NAME).bin','rb').read(); a=$(LOAD); \
	print('\n'.join('%04X: %s'%(a+i,' '.join('%02X'%b for b in d[i:i+8])) \
	for i in range(0,len(d),8)))" > $(NAME).mon


# ---- da65 info file, generated from the linker's label output ----
info: $(NAME).info    ## generate da65 info file from linker labels

$(NAME).info: $(NAME).lbl $(NAME).bin
	@printf 'GLOBAL {\n' > $@
	@printf '\tinputname\t"%s";\n'   $(NAME).bin >> $@
	@printf '\tstartaddr\t$$%s;\n'   $(ORIGIN)     >> $@
	@printf '\tcpu\t\t"%s";\n'       $(CPU)      >> $@
	@printf '\tcomments\t4;\n};\n\n' >> $@
	@awk '$$1=="al" && substr($$3,2,2)!="__" { \
		printf "LABEL { name \"%s\"; addr $$%s; };\n", \
		       substr($$3,2), substr($$2,3) }' $(NAME).lbl >> $@
	@printf '\n' >> $@
	@if [ -f $(NAME).ranges ]; then \
		cat $(NAME).ranges >> $@; \
	else \
		last=$$(printf '%04X' $$(( $(LOAD) + $$(wc -c < $(NAME).bin) - 1 ))); \
		printf '# no %s.ranges file -- create one with RANGE blocks for data.\n' $(NAME) >> $@; \
		printf '# binary spans $$%s..$$%s\n' $(ORIGIN) "$$last" >> $@; \
		printf '# RANGE { start $$0290; end $$%s; type ByteTable; name "text"; };\n' "$$last" >> $@; \
	fi
	@echo "wrote $@ -- check the RANGE blocks before running 'make dis'"


dis: $(NAME).dis      ## disassemble the linked binary using the info file

$(NAME).dis: $(NAME).bin $(NAME).info
	$(DA) -i $(NAME).info -o $(NAME).dis

dump: $(NAME).o
	od65 --dump-all $(NAME).o

clean:
	rm -f *.o *.bin *.hex *.s19 *.mon *.lst *.map *.lbl *.dis $(NAME).info

help:                 ## show this help
	@echo "targets:"
	@grep -E '^[a-zA-Z_.-]+:.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*## "}{printf "  %-10s %s\n", $$1, $$2}'
	@echo ""
	@echo "variables (override: make VAR=value):"
	@grep -E '^[A-Z_]+ *=.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=" *=.*## "}{printf "  %-10s %s\n", $$1, $$2}'
	@echo ""
	@echo "example:  make clean && make ORIGIN=0300 && make info && make dis"


.PHONY: all info dis dump clean help

