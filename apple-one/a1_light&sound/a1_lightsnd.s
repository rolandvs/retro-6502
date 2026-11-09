; ------------------------------------------------------
; A-ONE - Light & Sound
; ------------------------------------------------------
; @file 	a1_lightsnd.s
; @brief 	use the cc65 tool chain to create 6502 binaries 
; @author 	(c)2026 by Roland van Straten (github.com/rolandvs)
; @license 	MIT License
;
;
	.setcpu 	"6502"	; Apple-1 uses a standard 6502

	.include	"wozmon.inc"

WOZMON 	=	GETLINE

	.segment 	"CODE"

_start:	ldx	#0
printnext:	lda 	splash,x	; print welcome string
	beq 	done	
	jsr 	ECHO	; wozmon output character 
	inx
	bne 	printnext
done:	jmp	over
;
	.include	"songs.s"
	.include	"ws2812.s"
;
; -----------------------------------
;|                                   |
; -----------------------------------
;
over:	
	jsr	song2	; nokia
lez:	jsr 	led_rotate 
	jsr	ws_send	; leds
	jsr 	delay500
	jmp 	lez

; works but dead for now
	jsr	song1	; ode to joy
	jmp 	WOZMON


; ----------------------------------------------------------------------
; delay500 — exactly 500 000 cycles incl. JSR + RTS (500 ms @ 1 MHz)
; Preserves A, X, Y and all flags. Uses 4 bytes of stack.
; ----------------------------------------------------------------------
	.segment "CODE"
	.proc   delay500
        php                 ;  3
        pha                 ;  3
        txa                 ;  2
        pha                 ;  3
        tya                 ;  2
        pha                 ;  3
        ldx #250            ;  2
outer:  ldy #221            ;  2
inner:  nop                 ;  2
        nop                 ;  2
        dey                 ;  2
        bne inner           ;  3 / 2      9 cycles per pass
        dex                 ;  2
        bne outer           ;  3 / 2      1995 cycles per outer pass
        ldy #240            ;  2
fine:   dey                 ;  2
        bne fine            ;  3 / 2      fine trim: 1199 cycles
        pla                 ;  4
        tay                 ;  2
        pla                 ;  4
        tax                 ;  2
        pla                 ;  4
        plp                 ;  4
        rts                 ;  6
	.endproc

;
; -----------------------------------
;|                                   |
; -----------------------------------
;


; DATA
	.segment 	"RODATA"	; only for the disassmbler
splash: 	.byte 	"A-ONE LIGHT & SOUND DEMO",$8D,$00

