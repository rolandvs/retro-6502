; wozmon.inc - Apple 1 hardware and Woz Monitor entry points
;
; .include it in a program to use the names, and list it in SYMS in the
; Makefile so da65 labels these addresses too. The ";" comment on each
; line becomes the comment in the disassembly.
;
; Format the info generator understands, one per line:
;     NAME = $hhhh     ; comment
;     NAME := $hhhh    ; comment

; ---- PIA 6820 ----
KBD     = $D010         ; PIA: keyboard data (bit 7 set)
KBDCR   = $D011         ; PIA: keyboard control, bit 7 = key ready
DSP     = $D012         ; PIA: display data, bit 7 = busy
DSPCR   = $D013         ; PIA: display control

; ---- Woz Monitor zero page / buffer ----
XAML    = $24           ; WozMon: last opened location, low
XAMH    = $25           ; WozMon: last opened location, high
STL     = $26           ; WozMon: store address, low
STH     = $27           ; WozMon: store address, high
L       = $28           ; WozMon: hex value parsing, low
H       = $29           ; WozMon: hex value parsing, high
YSAV    = $2A           ; WozMon: Y save
MODE    = $2B           ; WozMon: XAM / STOR / BLOCK XAM mode
IN      = $0200         ; WozMon: input buffer $0200-$027F

; ---- Woz Monitor routines ----
RESET   = $FF00         ; WozMon: cold start
GETLINE = $FF1F         ; WozMon: print backslash prompt, read a line (warm start)
PRBYTE  = $FFDC         ; WozMon: print A as two hex digits
PRHEX   = $FFE5         ; WozMon: print low nibble of A as hex digit
ECHO    = $FFEF         ; WozMon: print character in A
