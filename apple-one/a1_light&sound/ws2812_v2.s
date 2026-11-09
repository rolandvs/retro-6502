; ======================================================================
; ws2812.s  —  WS2812 driver for 1 MHz 6502 + 5-chip Ø2-gated port
; Code: $0300-$0349 (frame sender), $0380-$03FC (IRQ blinker), all in RAM
; Port: $C600
;
; Wozmon: 300R  -> entry stub: JSR ws_send, then JMP back to Wozmon
; Programs: JSR ws_send ($0306) -> returns with RTS
; In:    WS_N (zp $F0) = LED count, 1..255 (0 = 256)
;        G, R, B       = $0400/$0500/$0600, one byte per LED
; Out:   A, X, Y, P (incl. I flag) restored exactly
; Uses:  zp $F1-$F4 (save slots), 1 stack byte + JSR return address
; Note:  not re-entrant: an NMI handler must not call it
;
; IRQ blinker (needs the 555/74LS74 timer at CTRL = $C700):
;   380R  start: vector $0000 -> irq, enable timer, return to Wozmon
;   3A0R  stop:  disable timer, LED off, return to Wozmon
;   IRQ   every 10 ms; LED 1 toggles every BLINK_N ticks
;   While the blinker runs, do not call ws_send (the ISR owns the strip)
;
; Timing contract (hardware): 16..19 cycles between writes to WS,
; then line low >= 300 us to latch. Both are met below.
; ======================================================================

WS      = $C600         ; WS2812 port (write-only)
WS_N    = $F0           ; LED count
SV_A    = $F1           ; register save slots
SV_X    = $F2
SV_Y    = $F3
SV_P    = $F4
G       = $0400         ; green table  (page-aligned, RAM)
R       = $0500         ; red table
B       = $0600         ; blue table
LATCH_N = 64            ; delay loop: 5*64-1 = 319 cycles
WOZ     = $FF1F         ; Wozmon GETLINE (Apple-1 Wozmon) <- check yours

; ---- IRQ blinker ------------------------------------------------------
CTRL    = $C700         ; timer control (write-only): D0=1 run, D0=0 stop;
                        ; ANY write also acknowledges (clears) the IRQ
TICK    = $F5           ; ticks left until next toggle
STATE   = $F6           ; 0 = LED off, 3 = LED on (offset into COLTAB)
CTRL_SH = $F7           ; shadow of the CTRL enable bit
BLINK_N = 50            ; 50 x 10 ms = 0.5 s on, 0.5 s off
COL_R   = $20           ; preset colour (R,G,B) = $20,$64,$00
COL_G   = $64
COL_B   = $00

        .org $0300

; ---- entry for Wozmon 'R' (R is a JMP, not a JSR) ------------------
entry:  jsr ws_send     ; 6
        jmp WOZ         ; 3  back to the monitor prompt

ws_send:
        php             ; 3  caller's flags
        sta SV_A        ; 3
        stx SV_X        ; 3
        sty SV_Y        ; 3
        pla             ; 4  P -> A (flags restored by PLP at exit)
        sta SV_P        ; 3
        sei             ; 2  no IRQs during the bitstream

        ldy #0          ; 2
loop:   nop             ; 2
        nop             ; 2
        nop             ; 2
        lda G,y         ; 4
        sta WS          ; 4  W1 green   (W3->W1 = 3+6+4+4 = 17)
        lda R,y         ; 4
        nop             ; 2
        nop             ; 2
        nop             ; 2
        nop             ; 2
        sta WS          ; 4  W2 red     (W1->W2 = 16)
        lda B,y         ; 4
        iny             ; 2
        nop             ; 2
        nop             ; 2
        cpy WS_N        ; 3
        sta WS          ; 4  W3 blue    (W2->W3 = 17)
        bne loop        ; 3 taken / 2 on exit

; ---- latch: >= 300 us low; re-enable IRQs only if caller had them on --
        lda SV_P        ; 3
        and #$04        ; 2  caller's I flag
        bne irqoff      ; 2/3
        cli             ; 2  IRQs here only lengthen the latch: harmless
irqoff: ldx #LATCH_N    ; 2
dly:    dex             ; 2
        bne dly         ; 3 (2 on exit)

; ---- restore -----------------------------------------------------------
        lda SV_P        ; 3
        pha             ; 3  P back on stack for PLP
        lda SV_A        ; 3
        ldx SV_X        ; 3
        ldy SV_Y        ; 3
        plp             ; 4  all flags incl. I, after the loads
        rts             ; 6

; ======================================================================
; IRQ blinker
; ======================================================================
        .org $0380

; ---- start: 380R ------------------------------------------------------
start:  sei
        lda #$4C        ; $0000: JMP irq   (Wozmon's IRQ/BRK vector = $0000)
        sta $00
        lda #<irq
        sta $01
        lda #>irq
        sta $02
        lda #BLINK_N
        sta TICK
        lda #0
        sta STATE       ; start with LED off (first toggle turns it on)
        lda #1
        sta CTRL_SH
        sta CTRL        ; enable timer + clear any stale IRQ
        cli
        jmp WOZ

        .org $03A0
; ---- stop: 3A0R -------------------------------------------------------
stop:   sei
        lda #0
        sta CTRL_SH
        sta CTRL        ; disable timer + clear pending IRQ
        sta STATE
        ldx #0
        jsr send1       ; LED off
        cli
        jmp WOZ

; ---- IRQ / BRK handler ------------------------------------------------
irq:    pha             ; 3
        txa             ; 2
        pha             ; 3
        tsx             ; 2
        lda $0103,x     ; 4  P pushed by the IRQ/BRK
        and #$10        ; 2  B flag
        bne isbrk       ; 2
        lda CTRL_SH     ; 3
        sta CTRL        ; 4  acknowledge (keeps current enable state)
        dec TICK        ; 5
        bne done        ; 2/3
        lda #BLINK_N    ; 2
        sta TICK        ; 3
        lda STATE       ; 3
        eor #3          ; 2  0 <-> 3
        sta STATE       ; 3
        tax             ; 2
        jsr send1       ; 6
done:   pla             ; 4
        tax             ; 2
        pla             ; 4
        rti             ; 6
isbrk:  jmp WOZ         ;    BRK: back to the monitor (I stays set)

; ---- send one LED: X = 0 (off) or 3 (on); writes 16 cycles apart -----
send1:  lda COLTAB,x    ; 4
        sta WS          ; 4  W1 green
        nop             ; 2
        nop             ; 2
        nop             ; 2
        nop             ; 2
        lda COLTAB+1,x  ; 4
        sta WS          ; 4  W2 red     (16)
        nop             ; 2
        nop             ; 2
        nop             ; 2
        nop             ; 2
        lda COLTAB+2,x  ; 4
        sta WS          ; 4  W3 blue    (16)
        rts             ; 6

COLTAB: .byte $00, $00, $00             ; off  (G,R,B)
        .byte COL_G, COL_R, COL_B       ; on   (G,R,B: wire order is GRB)
