; eeprog.s - copy RAM $7800-$7FFF to X2816 EEPROM $C800-$CFFF
;
; Byte by byte, 10ms write cycle per byte, verified after each write.
; Bytes that already match are skipped (faster, less EEPROM wear).
; Prints DONE, or ERR <addr> with the first address that failed to verify.

        .include "ee_common.inc"

        .segment "CODE"

start:  lda     #<msg_run       ; indicate the start
        ldx     #>msg_run
        jsr     puts
;
        jsr     setup
        lda     #<SRC
        sta     sptr
        lda     #>SRC
        sta     sptr+1

loop:   lda     (sptr),y
        cmp     (dptr),y
        beq     next            ; already correct, no write needed
        sta     (dptr),y        ; start EEPROM write cycle
        jsr     delay10         ; wait it out (keeps Y)
        lda     (sptr),y        ; verify
        cmp     (dptr),y
        bne     fail
next:   iny
        bne     loop
        inc     sptr+1
        inc     dptr+1
        dec     pages
        bne     loop
        jmp     done
