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

```bash
# python3 must be installed, probably using .venv on MacOSX
brew install python3
# add the cc65 tool chain
brew install cc65
# add the srecord stuff
brew install srecord
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
;
; To see what changes were needed to be able to use the
; cc65 tool chain this sample was modified.
;
; cc65 looks a bit like the setup of gcc tool chain.
; A little more work, but better in the long run.
;
;
; select the right cpu
	.setcpu 	"6502"	; Apple-1 uses a standard 6502

CharOut 	= 	$FFEF 	; WozMon monitor ECHO

	.segment 	"CODE"
	.org 	LOAD	; set the origin inherited from Makefile

_start:	ldx	#0
printnext:	lda 	text,x	; get character from string
	beq 	done	; untilf we read a NULL	
	jsr 	CharOut	; character to output 
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
$ make clean && make && make info && make dis
$ cat apple1_hello.dis
```

You can also enter `make help` for info.

```
 make help
targets:
  info       generate da65 info file from linker labels
  dis        disassemble the linked binary using the info file
  help       show this help

variables (override: make VAR=value):

example:  make clean && make ORIGIN=0300 && make info && make dis
```


#### S19, Intel, BIN and WOZ

- Motorola S19

```
S00F00006170706C65315F68656C6C6F3A
S1210280A200BD9002F00620EFFFE8D0F54C8D0248656C6C6F20576F726C64218D0015
S90302807A
```

- Intel Hex

```
:020000040000FA
:1E028000A200BD9002F00620EFFFE8D0F54C8D0248656C6C6F20576F726C64218D0019
:00000001FF
```

- WOZMON

```
$ cat apple1_hello.mon
0280: A2 00 BD 90 02 F0 06 20
0288: EF FF E8 D0 F5 4C 8D 02
0290: 48 65 6C 6C 6F 20 57 6F
0298: 72 6C 64 21 8D 00
```

- BIN

```
$ xxd apple1_hello.bin
00000000: a200 bd90 02f0 0620 efff e8d0 f54c 8d02  ....... .....L..
00000010: 4865 6c6c 6f20 576f 726c 6421 8d00       Hello World!..
```

#### Disassembly Output

No comments needed, but the circle is round. However, there is a file called `apple1_hello.ranges`. This is a file typed by hand. It is to improve the readability and function of the disassembler. See more info in the file or the documentation of **cc65**.


```
; da65 V2.18 - N/A
; Created:    2026-08-29 23:21:03
; Input file: apple1_hello.bin
; Page:       1


        .setcpu "6502"

; ----------------------------------------------------------------------------
CharOut         := $FFEF
; ----------------------------------------------------------------------------
_start: ldx     #$00                            ; 0280 A2 00                    ..
printnext:
        lda     text,x                          ; 0282 BD 90 02                 ...
        beq     done                            ; 0285 F0 06                    ..
        jsr     CharOut                         ; 0287 20 EF FF                  ..
        inx                                     ; 028A E8                       .
        bne     printnext                       ; 028B D0 F5                    ..
done:   jmp     done                            ; 028D 4C 8D 02                 L..

; ----------------------------------------------------------------------------
text:   .byte   $48,$65,$6C,$6C,$6F,$20,$57,$6F ; 0290 48 65 6C 6C 6F 20 57 6F  Hello Wo
        .byte   $72,$6C,$64,$21,$8D,$00         ; 0298 72 6C 64 21 8D 00        rld!..
```


# Disclaimer

To appreciate all the work than is done by others, I dedicate part of my time to give something back. 