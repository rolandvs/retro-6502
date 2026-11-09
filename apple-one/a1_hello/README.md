# Hello World 6502

A working solution for MacOSX...

# GCC for 6502

After some searching and comparison of a number of assemblers it seems to me that `cc65 tool chain` has some gcc like structure of tools. Other assemblers are to limited or focussed on the target machine (e.g., Atari, Commodore, Apple, etc). In the past I used EDASM and Microsoft's Macro Assembler with the CP/M SoftCard on my `Apple//e` and ORCA on my `Apple//gs`.

At this point I want to use a more generic 6502 assembler and limit its use to (my) homebrew 6502 systems (e.g., KIM, Junior, Apple-one). Rather no IDE, but command line tools and my editor of choice: `Sublime Text` and  `VSCode`.

## cc65 Tool Chain

I picked `cc65` and installed it on my Mac along with the other prerequisites. Looking in the `bin/` showed a set of programs "similar" to gcc.

```
ar65     cc65     cl65     da65     ld65     sim65
ca65     chrcvt65 co65     grc65    od65     sp65
```

Libraries (for cc65) for a lot of target machines can be found in:

```bash
$ /opt/homebrew/Cellar/cc65/2.19/share/cc65/lib
```

## Prerequisites

### BREW

```bash
# python3 must be installed, probably using .venv on MacOSX
brew install python3
# add the cc65 tool chain
brew install cc65
# add the srecord stuff
brew install srecord
```

### MACPORTS 

```bash
```

## Sample Code

I was looking for some sample code and found a version of "Hello World" for the Apple-1. I use the `*.s` convention of the source file, rather than `a65`, `asm`, etc.

```
; ------------------------------------------------------
; Apple One - Hello World Example
;
; Originally written by Hein Pragt in 2023. It was used 
; as an example for his 6502 simulator.
; ------------------------------------------------------
; @file 	apple1_hello.s
; @brief 	use the cc65 tool chain to create 6502 binaries 
; @author 	(c)2026 by Roland van Straten (github.com/rolandvs)
; @license 	MIT License
;
; To see what changes were needed to be able to use the
; cc65 tool chain this sample was modified.
;
; cc65 looks a bit like the setup of gcc tool chain.
; A little more work, but better in the long run.
;
; select the right cpu
	.setcpu 	"6502"	; Apple-1 uses a standard 6502

ECHO 	= 	$FFEF 	; WozMon monitor ECHO

	.segment 	"CODE"
	.org 	LOAD	; set the origin inherited from Makefile

_start:	ldx	#0
printnext:	lda 	text,x	; get character from string
	beq 	done	; untilf we read a NULL	
	jsr 	ECHO	; character to output 
	inx		; next char
	bne 	printnext	; repeat (max 255 times) 
;
done:	jmp  	done	

; zero terminated string
text: 	.byte 	"Hello World!",$8D,$00
```

### Making it work

I got a bit too enthusiastic and created a `Makefile` that generates the program in **binary**, **Intel hex**, **Motorola S19** and **WOZMON** format. It also generates the `*.info` file for the disassembler.

The best thing is to download the project with all the files in it and do:

```bash
make clean && make NAME=apple1_hello ORIGIN=C800 MONLOAD=7800 && make dis
rm -rf build
ca65 --cpu 6502 -g --list-bytes 0 -D LOAD='$C800' -l build/apple1_hello.lst -o build/apple1_hello.o apple1_hello.s
ld65 -C apple1.cfg -D __LOAD__='$C800' -m build/apple1_hello.map -Ln build/apple1_hello.lbl -o build/apple1_hello.bin build/apple1_hello.o
  SREC  build/apple1_hello.hex
  SREC  build/apple1_hello.s19
  WOZ   build/apple1_hello.woz
  LIST  build/apple1_hello.abs.lst

  ---- apple1_hello ----
  run    $C800-$C81D   (ORIGIN)
  load   $7800-$781D   (MONLOAD, .woz)
  size   30 bytes = $001E
  segments:
    CODE       $C800-$C80F     16 bytes
    RODATA     $C810-$C81D     14 bytes
  start  C800R on the Woz Monitor

wrote build/apple1_hello.info
da65 -i build/apple1_hello.info -o build/apple1_hello.dis
```

You can also enter `make help` for info.

```bash
make help
targets:
  all        build everything + report
  report     show addresses, size and segments of the last build
  abslist    listing with absolute addresses
  info       generate da65 info file: labels, ROM symbols, data ranges
  dis        disassemble the linked binary using the info file
  dump       dump the object file
  clean      remove the build directory
  help       show this help

variables (override: make VAR=value), current values:
  NAME     apple1   source apple1.s, outputs build/apple1.*
  ORIGIN   0280     run address, plain hex (no $ or 0x)
  MONLOAD  0280     load address of the .woz file, plain hex
  CPU      6502
  CFG      apple1.cfg
  B        build       build directory

example:  make clean && make ORIGIN=C800 MONLOAD=7800 && make dis
```

# Disclaimer

To appreciate all the work than is done by others, I dedicate part of my time to give something back. 