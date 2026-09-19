# Apple II Speaker

The Apple-One does not feature a speaker. The Apple II does and is of WOZ simplicity. Reading from address `$C030` toggles the speaker through a `74LS74` by two divider and AC drives a Darlington amplifier.

![SPKR](/apple-one/a1_beep/doc/A1-SPKR.png)

By adding the same circuit to the Apple-One it is simple enough to add sound generating software like the white-noise generator and of course the familiar Apple II startup beep.

The use of `$C000` conflicts with the cassette recorder interface. To make it even more compatible with the Apple II the address `$C030` can be decoded by adding the following circuitry and put it in between the `X'` and `X` in the schematic. 

![xx30](/apple-one/a1_beep/doc/c030_decoder.png)

## PEEK(49200)

The code for the beep comes straight from the Apple II Monitor.

```
                SPKR   EQU $C030

FBD9: C9 87     BELL1  CMP #$87     ; Ctrl-G?
FBDB: D0 12            BNE RTS2B    ; no, return
                ;
FBDD: A9 40            LDA #$40     ; delay ~.01 s
FBDF: 20 A8 FC         JSR WAIT
FBE2: A0 C0            LDY #$C0     ; 192 toggles
FBE4: A9 0C     BELL2  LDA #$0C     ; half-period delay
FBE6: 20 A8 FC         JSR WAIT     ; 1kHz for 0.1 sec
FBE9: AD 30 C0         LDA SPKR     ; $C030 toggle
FBEC: 88               DEY
FBED: D0 F5            BNE BELL2
FBEF: 60        RTS2B  RTS
                ;
FCA8: 38        WAIT   SEC
FCA9: 48        WAIT2  PHA
FCAA: E9 01     WAIT3  SBC #$01
FCAC: D0 FC            BNE WAIT3    ; 1.0204 usec
FCAE: 68               PLA          ; (13+27/2*A+5/2*A*A)
FCAF: E9 01            SBC #$01
FCB1: D0 F6            BNE WAIT2      
FCB3: 60               RTS
```

## Beeeeeeep

```
0300: A9 00     LDA #$00
0302: AD 00 C0  LDA $C000     ; 4 cycles

0305: A2 FF     LDX #$FF      ; 2
0307: A0 26     LDY #$26      ; 2   (was $4A)
0309: 88        DEY           ; 2
030A: D0 FD     BNE $0309     ; 3 taken / 2 not
030C: CA        DEX           ; 2
030D: D0 F8     BNE $0307     ; 3 taken / 2 not
030F: 49 01     EOR #$01      ; 2
0311: 4C 02 03  JMP $0302     ; 3
```

## Relocated for APPLE-ONE

The only absolute addresses are the two **JSR WAIT** calls. Woz Mon's `R` command jumps to the code rather than calling it, so a RTS would crash, therefore replaced by `JMP $FF1F` **GETLINE**.

A 1MHz clock would put the pitch about 2% lower. That's inaudible for a beep.

In this case the address for the **SPKR** is `$C000` instead of `$C030`.

For quick testing:

```
# ported BELL
300: A9 40 20 15 03 A0 C0 A9 0C 20 15 03
30C: AD 00 C0 88 D0 F5 4C 1F FF
315: 38 48 E9 01 D0 FC 68 E9 01 D0 F6 60
300R
```

```
# beep
300: A9 00 8D 00 C0 A2 FF A0 26 88 D0 FD
30C: CA D0 F8 49 01 4C 02 03

300R
```

## Hardware in action

![HW](/apple-one/a1_beep/doc/IMG_4211.jpeg)
