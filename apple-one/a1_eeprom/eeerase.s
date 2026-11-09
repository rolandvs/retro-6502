; eeerase.s - fill X2816 EEPROM $C800-$CFFF with $FF
;
; Byte by byte, 10 ms write cycle per byte, verified after each write.
; Bytes that are already $FF are skipped (faster, less EEPROM wear).
; Prints DONE, or ERR hhll with the first address that failed to verify.

        .include "ee_common.inc"

        .segment "CODE"

start:  lda     #<msg_run       ; indicate the start
        ldx     #>msg_run
        jsr     puts
        
        jsr     setup

loop:   lda     (dptr),y
        cmp     #$FF
        beq     next            ; already erased
        lda     #$FF
        sta     (dptr),y        ; start EEPROM write cycle
        jsr     delay10         ; wait it out (keeps Y)
        lda     (dptr),y        ; verify
        cmp     #$FF
        bne     fail
next:   iny
        bne     loop
        inc     dptr+1
        dec     pages
        bne     loop
        jmp     done
