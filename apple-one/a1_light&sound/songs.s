; ---------------------------------------------------------------------------
; songs.s - two tunes on the Apple-1 replica speaker flip-flop ($C000-$C0FF)
;   1. Beethoven, Symphony no. 9, "Ode an die Freude" (main theme, 8 bars)
;   2. "Nokia tune": Francisco Tarrega, Gran Vals (1902), bars 13-16, as in the
;      classic ringtone (RTTTL 8e6,8d6,f#,g#,8c#6,8b,d,e,8b,8a,c#,e,2a @ 225)
;
; Set CLOCK to your replica's real CPU clock. 1.000 vs 1.0227 MHz = 39 cents. 
; All loop counts and note lengths are computed from CLOCK.
;
; Every read in $C000-$C0FF toggles the speaker, so rests read plain RAM.
;
; Timing: the loop plays FULL periods: toggle, wait N1, toggle, wait N2.
; Pitch depends only on the full period P, so with N1+N2 = S the pitch
; resolution is one loop step per full period, not per half period.
;
;   mode 7 (bne -> nop):  inner loop 7 cycles/step   P = 7*S + 32
;   mode 5 (bne -> dex):  inner loop 5 cycles/step   P = 5*S + 36
;
; Mode 7 reaches lower notes (S <= 510: down to CLOCK/3602 Hz), mode 5 has
; finer steps for high notes. The mode is set by patching the branch
; offsets per song (self-modifying code).
; ---------------------------------------------------------------------------

        .setcpu "6502"

SPKR    = $C030                 ; speaker toggle (any address $C000-$C0FF)
QUIET   = $0030                 ; plain RAM: reading it does nothing

; zero page, outside the Woz Monitor's $24-$2B
ptr     = $06                   ; $06/$07 pointer into song data
n1      = $08
n2      = $09
cntlo   = $EB                   ; number of full periods, low
cnthi   = $EC                   ; number of full periods, high

CLOCK   = 1000000               ; Hz  <-- set to your replica's clock

MODE7   = $FC                   ; bne offset -4: back to nop
MODE5   = $FD                   ; bne offset -3: back to dex

; --- equal temperament, A4 = 440 Hz, in centihertz ---------------------------
F_D4    = 29366
F_E4    = 32963
F_FS4   = 36999
F_G4    = 39200
F_A4    = 44000
F_CS5   = 55437
F_D5    = 58733
F_E5    = 65926
F_FS5   = 73999
F_GS5   = 83061
F_A5    = 88000
F_B5    = 98777
F_CS6   = 110873
F_D6    = 117466
F_E6    = 131851

; --- event = 5 bytes: N1, N2, full periods (word), high byte of toggle addr --
; ($C0 = speaker, $00 = silent RAM). Song ends with a 0 byte.
; LK, LC (loop step and overhead) and BPM are set per song with .set.

.macro NOTE fc, eighths
        .local S
        S = (CLOCK * 1000 / (fc) - 10 * LC + 5 * LK) / (10 * LK)
        .assert S >= 2 && S <= 510, error, "note out of range for this mode"
        .byte S / 2, S - S / 2
        .word ((eighths) * (CLOCK * 30 / BPM) - CLOCK * 60 / BPM / 16) / (LK * S + LC)
        .byte >SPKR
        .byte 100, 100          ; articulation gap: 1/16 quarter of silence
        .word (CLOCK * 60 / BPM / 16) / (LK * 200 + LC)
        .byte >QUIET
.endmacro

.macro SILENCE ms
        .byte 100, 100
        .word (CLOCK / 1000 * (ms)) / (LK * 200 + LC)
        .byte >QUIET
.endmacro

; ---------------------------------------------------------------------------
        .segment "CODE"

song1:  php
        sei
        lda #<ode
        ldx #>ode
        ldy #MODE7
        jsr play
        plp
        rts

song2:  php  
        sei
        lda #<nokia
        ldx #>nokia
        ldy #MODE5
        jsr play
        plp
        rts

play:   sta ptr
        stx ptr+1
        sty loop1+3             ; patch both bne offsets: loop mode
        sty loop2+3
next:   ldy #0
        lda (ptr),y             ; N1; 0 = end of song
        beq pdone
        sta n1
        iny
        lda (ptr),y
        sta n2
        iny
        lda (ptr),y
        sta cntlo
        iny
        lda (ptr),y
        sta cnthi
        iny
        lda (ptr),y
        sta toggle1+2           ; $C030 (sound) or $0030 (silence)
        sta toggle2+2
        jsr tone
        clc
        lda ptr
        adc #5
        sta ptr
        bcc next
        inc ptr+1
        bne next                ; always
pdone:  rts

; Plays cnthi:cntlo full periods.            mode 7     mode 5
tone:
toggle1: bit SPKR               ; 4
        ldx n1                  ; 3
loop1:  nop                     ; 2 \        7*N1 - 1   5*N1 + 1
        dex                     ; 2  >
        bne loop1               ; 3 / (offset patched)
toggle2: bit SPKR               ; 4
        ldx n2                  ; 3
loop2:  nop                     ;            7*N2 - 1   5*N2 + 1
        dex
        bne loop2
        lda cntlo               ; 3
        bne @lo                 ; 3
        dec cnthi               ; 5 (only when cntlo = 0: +4 cycles, 1x per 256)
@lo:    dec cntlo               ; 5
        lda cntlo               ; 3
        ora cnthi               ; 3
        bne toggle1             ; 3
        rts                     ;            ----------------------
tone_end:                       ;            P = 7*S+32  P = 5*S+36

; branches must not cross a page boundary (+1 cycle)
        .assert >tone = >(tone_end - 1), error, "tone loop crosses a page"

; ---------------------------------------------------------------------------
; Song 1: Ode an die Freude, quarter = 120 (Beethoven: half = 80)
LK      .set 7
LC      .set 32
BPM     .set 120
ode:
        NOTE F_FS4,2
        NOTE F_FS4,2
        NOTE F_G4,2
        NOTE F_A4,2             ; bar 1
        NOTE F_A4,2
        NOTE F_G4,2
        NOTE F_FS4,2
        NOTE F_E4,2             ; bar 2
        NOTE F_D4,2
        NOTE F_D4,2
        NOTE F_E4,2
        NOTE F_FS4,2            ; bar 3
        NOTE F_FS4,3
        NOTE F_E4,1
        NOTE F_E4,4             ; bar 4
        NOTE F_FS4,2
        NOTE F_FS4,2
        NOTE F_G4,2
        NOTE F_A4,2             ; bar 5
        NOTE F_A4,2
        NOTE F_G4,2
        NOTE F_FS4,2
        NOTE F_E4,2             ; bar 6
        NOTE F_D4,2
        NOTE F_D4,2
        NOTE F_E4,2
        NOTE F_FS4,2            ; bar 7
        NOTE F_E4,3
        NOTE F_D4,1
        NOTE F_D4,4             ; bar 8
        .byte 0

; Song 2: Nokia tune, 3/4, quarter = 225
LK      .set 5
LC      .set 36
BPM     .set 225
nokia:
        SILENCE 1000            ; one second between the songs
        NOTE F_E6,1
        NOTE F_D6,1
        NOTE F_FS5,2
        NOTE F_GS5,2            ; bar 1
        NOTE F_CS6,1
        NOTE F_B5,1
        NOTE F_D5,2
        NOTE F_E5,2             ; bar 2
        NOTE F_B5,1
        NOTE F_A5,1
        NOTE F_CS5,2
        NOTE F_E5,2             ; bar 3
        NOTE F_A5,4             ; bar 4 (half note, as in the ringtone)
        .byte 0
