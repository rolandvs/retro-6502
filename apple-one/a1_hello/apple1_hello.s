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
;	.export 	_start	; set in the *.cfg linker file

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

