; ee_common.inc - shared settings and routines for eeprog.s / eeerase.s
;                 X2816 EEPROM (2K x 8) at $C800-$CFFF, Apple 1 / Woz Monitor

        .setcpu "6502"

        .include "wozmon.inc"

; ---- settings (override on the command line, e.g. ca65 -D SRC='$7000') ----
.ifndef SRC
SRC     = $7800         ; RAM copy of the ROM image
.endif
.ifndef DST
DST     = $C800         ; EEPROM base
.endif
.ifndef PAGES
PAGES   = 8             ; 8 x 256 = 2K = whole X2816
.endif
.ifndef CLK_N
CLK_N   = 8             ; delay: 8 -> 10328 cycles = 10.1 ms at 1.023 MHz
.endif                  ; other clocks: CLK_N = ceil(MHz * 10000 / 1289)

WOZMON  = GETLINE         ; back to the "\" prompt

; ---- zero page (Woz Monitor uses $24-$2B, avoided) ----
sptr    = $00           ; 2 bytes, source pointer
dptr    = $02           ; 2 bytes, EEPROM pointer
dcnt    = $04           ; delay counter
pages   = $05           ; pages left

        .segment "CODE"
        jmp     start           ; entry at load address -> main program

; ---------------------------------------------------------------------------
; delay10: ~10 ms write-cycle wait. Clobbers A, X. Keeps Y.
;   inner  : 255*5 + 4                    = 1279 cycles
;   outer  : (2 + 1279 + 5 + 3) * N - 1   = 1289*N - 1
;   total  : 1289*N - 1 + 5 + RTS 6 + JSR 6
;   N = 8  : 10328 cycles = 10.10 ms @ 1.023 MHz
; A page-crossing branch only adds cycles, so the delay is never shorter.
; ---------------------------------------------------------------------------
delay10:
        lda     #CLK_N          ; 2
        sta     dcnt            ; 3
@outer: ldx     #0              ; 2
@inner: dex                     ; 2
        bne     @inner          ; 3 / 2
        dec     dcnt            ; 5
        bne     @outer          ; 3 / 2
        rts                     ; 6

; ---------------------------------------------------------------------------
; puts: print zero-terminated string at (A=lo, X=hi). Clobbers A, X, Y.
; ---------------------------------------------------------------------------
puts:   sta     sptr
        stx     sptr+1
        ldy     #0
@loop:  lda     (sptr),y
        beq     @done
        ora     #$80            ; Apple 1 / Woz Monitor convention
        jsr     ECHO
        iny
        bne     @loop
@done:  rts

; ---------------------------------------------------------------------------
; setup: dptr = DST, pages = PAGES, Y = 0
; ---------------------------------------------------------------------------
setup:  lda     #<DST
        sta     dptr
        lda     #>DST
        sta     dptr+1
        lda     #PAGES
        sta     pages
        ldy     #0
        rts

; ---------------------------------------------------------------------------
; fail: print "ERR hhll" (failing EEPROM address = dptr+1 : Y), exit
; ---------------------------------------------------------------------------
fail:   sty     dcnt            ; save low byte of address
        lda     #<msg_err
        ldx     #>msg_err
        jsr     puts
        lda     dptr+1
        jsr     PRBYTE
        lda     dcnt
        jsr     PRBYTE
        lda     #$8D            ; CR
        jsr     ECHO
        jmp     WOZMON

done:   lda     #<msg_ok
        ldx     #>msg_ok
        jsr     puts
        jmp     WOZMON

        .segment "RODATA"
msg_err: .byte   $0D, "ERR ", 0
msg_ok:  .byte   $0D, "DONE", $0D, 0
msg_run: .byte   $0D, "RUN", $0D, 0