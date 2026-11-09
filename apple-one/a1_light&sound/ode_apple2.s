; ---------------------------------------------------------------------------
; ode.s  -  Beethoven, Symfonie nr. 9, "Ode an die Freude" (hoofdthema, 8 maten)
;           via de 1-bit luidspreker van de Apple II ($C030)
;
; Assembler : ca65 (cc65-suite)
; Bouwen    : ca65 ode.s -o ode.o
;             ld65 -t none -S $0C00 ode.o -o ode.bin
; Draaien   : laad ode.bin op $0C00 en start met  CALL 3072
;             (bijv. AppleCommander:  ac -p schijf.dsk ODE B 0x0C00 < ode.bin
;              en dan  BRUN ODE)
;
; Principe  : elke leestoegang tot $C030 klapt de flipflop om, de conus
;             beweegt naar de andere stand. Twee toggles = een volledige
;             periode van een blokgolf.
;
; Timing van een halve periode (alle zp-operanden, geen paginagrens-
; overschrijding, gecontroleerd met .assert onderaan):
;
;   toggle: bit SPKR       4
;           ldx period     3
;   @d:     dex            2  \
;           nop            2   > 7 per ronde, laatste ronde 6  =>  7N - 1
;           bne @d         3  /
;           lda durlo      3
;           bne @lo        3
;   @lo:    dec durlo      5
;           lda durlo      3
;           ora durhi      3
;           bne toggle     3
;                         ---
;           halve periode = 7N + 26 cycli
;
;   (Eens per 256 toggles kost de 16-bit carry 4 cycli extra: onhoorbaar.)
;
; Klok: NTSC Apple II gemiddeld 1.020.484 Hz (14,31818 MHz x 65/912).
;       Toonhoogte f = 1020484 / (2 x (7N + 26)).
;
;   noot  doel (Hz)  N    7N+26   gerealiseerd (Hz)  afwijking
;   D4    293,66     245  1741    293,07             -3,5 cent
;   E4    329,63     217  1545    330,25             +3,3 cent
;   F#4   369,99     193  1377    370,55             +2,6 cent
;   G4    392,00     182  1300    392,49             +2,2 cent
;   A4    440,00     162  1160    439,86             -0,6 cent
; ---------------------------------------------------------------------------

        .setcpu "6502"

SPKR    = $C030                 ; luidspreker-toggle
KBD     = $C000                 ; toetsenbord-data: lezen heeft geen bijwerking

; Zero page: vrije locaties onder Applesoft/DOS 3.3/ProDOS
ptr     = $06                   ; $06/$07  wijzer in melodietabel
period  = $08                   ; N
durlo   = $09                   ; aantal toggles, laag
durhi   = $EB                   ; aantal toggles, hoog

; --- tempo en lengtes (door de assembler berekend) -------------------------
CLOCK   = 1020484               ; Hz
BPM     = 120                   ; kwart = 120 (Beethoven: halve = 80 -> 160)
QUARTER = CLOCK * 60 / BPM      ; cycli per kwartnoot
EIGHTH  = QUARTER / 2
GAP     = QUARTER / 16          ; stilte na elke noot (~31 ms) voor articulatie
REST_N  = 100                   ; willekeurige N voor de stille lus

; --- toonhoogtes (N-waarden, zie tabel hierboven) --------------------------
N_D4    = 245
N_E4    = 217
N_FS4   = 193
N_G4    = 182
N_A4    = 162

; Elke gebeurtenis = 4 bytes: N, aantal halve perioden (word), adres-lowbyte
; ($30 = $C030 luidspreker, $00 = $C000 stil). NOTE zet een noot plus de
; korte stilte erachter; samen duren ze exact 'achtsten' x EIGHTH.
.macro NOTE nval, achtsten
        .byte nval
        .word ((achtsten) * EIGHTH - GAP) / (7 * (nval) + 26)
        .byte <SPKR
        .byte REST_N
        .word GAP / (7 * REST_N + 26)
        .byte <KBD
.endmacro

; ---------------------------------------------------------------------------
        .segment "CODE"

start:  php
        sei                     ; geen onderbrekingen tijdens het timen
        lda #<melody
        sta ptr
        lda #>melody
        sta ptr+1

next:   ldy #0
        lda (ptr),y             ; N; 0 = einde
        beq done
        sta period
        iny
        lda (ptr),y
        sta durlo
        iny
        lda (ptr),y
        sta durhi
        iny
        lda (ptr),y
        sta toggle+1            ; zelfmodificerend: $C030 (geluid) of $C000 (stil)
        jsr tone
        clc
        lda ptr
        adc #4
        sta ptr
        bcc next
        inc ptr+1
        bne next                ; altijd

done:   plp
        rts

; Speelt durhi:durlo halve perioden van 7N+26 cycli.
tone:
toggle: bit SPKR                ; 4   (operand-lowbyte wordt aangepast)
        ldx period              ; 3
@d:     dex                     ; 2
        nop                     ; 2
        bne @d                  ; 3/2
        lda durlo               ; 3
        bne @lo                 ; 3/2
        dec durhi               ; 5   (alleen als durlo = 0)
@lo:    dec durlo               ; 5
        lda durlo               ; 3
        ora durhi               ; 3
        bne toggle              ; 3
        rts
tone_end:

; Takken mogen geen paginagrens overschrijden (dat kost 1 cyclus extra).
        .assert >toggle = >(tone_end - 1), error, "tone-lus kruist een paginagrens"

; ---------------------------------------------------------------------------
; Melodie: lengte in achtsten (2 = kwart, 3 = gepunteerde kwart, 4 = halve)
melody:
        NOTE N_FS4,2
        NOTE N_FS4,2
        NOTE N_G4,2
        NOTE N_A4,2             ; maat 1
        NOTE N_A4,2
        NOTE N_G4,2
        NOTE N_FS4,2
        NOTE N_E4,2             ; maat 2
        NOTE N_D4,2
        NOTE N_D4,2
        NOTE N_E4,2
        NOTE N_FS4,2            ; maat 3
        NOTE N_FS4,3
        NOTE N_E4,1
        NOTE N_E4,4             ; maat 4
        NOTE N_FS4,2
        NOTE N_FS4,2
        NOTE N_G4,2
        NOTE N_A4,2             ; maat 5
        NOTE N_A4,2
        NOTE N_G4,2
        NOTE N_FS4,2
        NOTE N_E4,2             ; maat 6
        NOTE N_D4,2
        NOTE N_D4,2
        NOTE N_E4,2
        NOTE N_FS4,2            ; maat 7
        NOTE N_E4,3
        NOTE N_D4,1
        NOTE N_D4,4             ; maat 8
        .byte 0                 ; einde
