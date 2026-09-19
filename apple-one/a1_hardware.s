; Apple-1 Hardware
;
KBD	=	$D010		; PIA: keyboard data
KBDCR	=	$D011		; keyboard control (bit 7 = key ready)
DSP	=	$D012		; display data (bit 7 clears when accepted)
DSPCR	=	$D013
ECHO	=	$FFEF		; Woz monitor: print char in A
	* = 	$0280    	; safe origin; $0200-$027F is the monitor's input buffer

; Zero page $24–$2B belongs to the monitor
; RAM is $0000–$0FFF
; BASIC expansion 4K at $E000–$EFFF

; note: turn this in a "ranges" file for use with DA65.
