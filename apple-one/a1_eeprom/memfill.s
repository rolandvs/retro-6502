; memfill.s - fill a RAM range with an 8- or 16-bit pattern, then verify
;
; Apple 1 / Woz Monitor, plain 6502. Set the parameters in zero page from
; the monitor, then run the program at its load address:
;
;   0: 00 60 FF 7F AA 55 02      START=$6000 END=$7FFF PAT=$AA,$55 WIDTH=2
;   280R
;
;   $00-$01  START  first address  (lo, hi)
;   $02-$03  END    last address, inclusive (lo, hi)
;   $04      PAT0   pattern byte written at START, START+2, ...
;   $05      PAT1   pattern byte written at START+1, START+3, ... (16-bit only)
;   $06      WIDTH  1 = 8-bit (PAT0 everywhere), 2 = 16-bit (PAT0,PAT1,...)
;
; Results:
;   DONE         filled and verified
;   ERR RANGE    END < START, START < $0280, or range overlaps this program
;   ERR hhll=vv  verify failed at hhll, read back vv
;
; $0000-$027F is refused: zero page, 6502 stack, Woz Monitor input buffer.

        .setcpu "6502"

        .include "wozmon.inc"

WOZMON  = GETLINE       ; back to the "\" prompt 
PROTECT = $0280         ; lowest address that may be filled

; parameters (set by the user)
START   = $00
END     = $02
PAT     = $04
WIDTH   = $06
; work
ptr     = $07           ; 2 bytes
pat     = $09           ; 2 bytes, working pattern

        .segment "CODE"

start:
; ---- working pattern: 8-bit -> both phases PAT0 ----
        lda     PAT
        sta     pat
        ldx     WIDTH
        cpx     #2
        beq     @w16
        sta     pat+1
        jmp     check
@w16:   lda     PAT+1
        sta     pat+1

; ---- range checks (16-bit compare: CMP lo, SBC hi -> C=0 means A<B) ----
check:  lda     END             ; END < START ?
        cmp     START
        lda     END+1
        sbc     START+1
        bcc     bad

        lda     START           ; START < PROTECT ?
        cmp     #<PROTECT
        lda     START+1
        sbc     #>PROTECT
        bcc     bad

        lda     #<(prog_end-1)  ; last byte of program < START -> no overlap
        cmp     START
        lda     #>(prog_end-1)
        sbc     START+1
        bcc     fill
        lda     END             ; END < start -> no overlap
        cmp     #<start
        lda     END+1
        sbc     #>start
        bcs     bad             ; otherwise it would overwrite itself

; ---- fill ----
fill:   jsr     setptr
@loop:  lda     pat,x
        sta     (ptr),y
        jsr     next
        bne     @loop

; ---- verify ----
        jsr     setptr
@vloop: lda     pat,x
        cmp     (ptr),y
        bne     verr
        jsr     next
        bne     @vloop

        ldx     #msg_done - msgs
        jsr     print
        jmp     WOZMON

bad:    ldx     #msg_range - msgs
        jsr     print
        jmp     WOZMON

verr:   ldx     #msg_err - msgs
        jsr     print
        lda     ptr+1
        jsr     PRBYTE
        lda     ptr
        jsr     PRBYTE
        lda     #'=' | $80
        jsr     ECHO
        ldy     #0
        lda     (ptr),y
        jsr     PRBYTE
        lda     #$8D            ; CR
        jsr     ECHO
        jmp     WOZMON

; ---------------------------------------------------------------------------
; setptr: ptr = START, X = 0 (pattern phase), Y = 0
; ---------------------------------------------------------------------------
setptr: lda     START
        sta     ptr
        lda     START+1
        sta     ptr+1
        ldx     #0
        ldy     #0
        rts

; ---------------------------------------------------------------------------
; next: if ptr == END return Z=1 (finished).
;       else ptr++, X ^= 1 (next pattern byte), return Z=0.
; Compares before incrementing, so END = $FFFF works. Keeps Y.
; ---------------------------------------------------------------------------
next:   lda     ptr
        cmp     END
        bne     @adv
        lda     ptr+1
        cmp     END+1
        beq     @rts            ; Z=1: done
@adv:   inc     ptr
        bne     @tog
        inc     ptr+1
@tog:   txa
        eor     #1
        tax
        lda     #1              ; force Z=0
@rts:   rts

; ---------------------------------------------------------------------------
; print: zero-terminated string at msgs+X. Clobbers A, X.
; ---------------------------------------------------------------------------
print:  lda     msgs,x
        beq     @done
        ora     #$80
        jsr     ECHO
        inx
        bne     print
@done:  rts

msgs:
msg_done:  .byte  $0D, "DONE", $0D, 0
msg_range: .byte  $0D, "ERR RANGE", $0D, 0
msg_err:   .byte  $0D, "ERR ", 0

prog_end:
