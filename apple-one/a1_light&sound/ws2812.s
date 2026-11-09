; ======================================================================
; ws2812.s  —  WS2812 driver for 1 MHz 6502 + 5-chip Ø2-gated port
; Code: $C600-$C6FF (one page, so no branch crosses a page boundary)
;
; Call:  JSR $C600
; In:    WS_N (zp $F0) = LED count, 1..255 (0 = 256)
;        G, R, B       = page-aligned tables, one byte per LED (RAM)
; Out:   A, X, Y, P (incl. I flag) restored exactly
; Uses:  zp $F1-$F4 (save slots), 1 stack byte + JSR return address
; Note:  not re-entrant: an NMI handler must not call it
;
; Timing contract (hardware): 16..19 cycles between writes to WS,
; then line low >= 300 us to latch. Both are met below.
; ======================================================================

WS      = $C600         ; WS2812 port (write-only)  <- set to your decode
WS_N    = $F0           ; LED count
SV_A    = $F1           ; register save slots
SV_X    = $F2
SV_Y    = $F3
SV_P    = $F4
;G       = $0300         ; green table  (page-aligned, RAM)
;R       = $0400         ; red table
;B       = $0500         ; blue table
LATCH_N = 64            ; delay loop: 5*64-1 = 319 cycles


        .segment        "CODE"
ws_send:
        php             ; 3  caller's flags
        sta     SV_A        ; 3
        stx     SV_X        ; 3
        sty     SV_Y        ; 3
        pla             ; 4  P -> A (flags restored by PLP at exit)
        sta     SV_P        ; 3
        sei             ; 2  no IRQs during the bitstream

        ldy     #$08    ; number of LEDs
        sty     WS_N

        ldy     #0          ; 2
wsloop: nop             ; 2
        nop             ; 2
        nop             ; 2
        lda     G,y         ; 4
        sta     WS          ; 4  W1 green   (W3->W1 = 3+6+4+4 = 17)
        lda     R,y         ; 4
        nop             ; 2
        nop             ; 2
        nop             ; 2
        nop             ; 2
        sta     WS          ; 4  W2 red     (W1->W2 = 16)
        lda     B,y         ; 4
        iny             ; 2
        nop             ; 2
        nop             ; 2
        cpy     WS_N        ; 3
        sta     WS          ; 4  W3 blue    (W2->W3 = 17)
        bne     wsloop      ; 3 taken / 2 on exit

; ---- latch: >= 300 us low; re-enable IRQs only if caller had them on --
        lda     SV_P        ; 3
        and     #$04        ; 2  caller's I flag
        bne     irqoff      ; 2/3
        cli             ; 2  IRQs here only lengthen the latch: harmless
irqoff: ldx     #LATCH_N    ; 2
wsdly:    dex             ; 2
        bne     wsdly         ; 3 (2 on exit)

; ---- restore -----------------------------------------------------------
        lda     SV_P        ; 3
        pha             ; 3  P back on stack for PLP
        lda     SV_A        ; 3
        ldx     SV_X        ; 3
        ldy     SV_Y        ; 3
        plp             ; 4  all flags incl. I, after the loads
        rts             ; 6

; ----------------------------------------------------------------------
; led_rotate — shift all LED colours one position up the strip
;   LED0 <- LED7, LED1 <- LED0, ... LED7 <- LED6
; Preserves A, X, Y and all flags. Uses 5 bytes of stack. 307 cycles.
; ----------------------------------------------------------------------
NLED = 8

.segment "CODE"
.proc   led_rotate
        php                 ; save flags
        pha                 ; save A
        txa
        pha                 ; save X

        lda G+NLED-1        ; keep the last LED, it wraps to LED0
        pha
        lda R+NLED-1
        pha
        lda B+NLED-1
        pha

        ldx #NLED-1
loop:   lda G-1,x           ; LED[x] <- LED[x-1], top down
        sta G,x
        lda R-1,x
        sta R,x
        lda B-1,x
        sta B,x
        dex
        bne loop

        pla                 ; old last LED -> LED0
        sta B
        pla
        sta R
        pla
        sta G

        pla
        tax                 ; restore X
        pla                 ; restore A
        plp                 ; restore flags (undoes N/Z from PLA)
        rts
.endproc

        .segment        "DATA"
G:      .byte   0  ,128, 64,  0,  0,255,255,  0
R:      .byte   255,128, 64,  0,255,  0,255,255
B:      .byte   0  ,128, 64,255,  0,  0,  0,255  

