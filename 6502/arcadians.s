
;;; Play the start music from the BBC Micro's Arcadians

    .org $fffc
    .word main_reset
    .word ticks_irq

    .org $8000

;;; VIA
PORTB = $6000 ; (7 MSBs for lcd); LSB is sound control bit
PORTA = $6001 ; 76489 data
DDRB = $6002
DDRA = $6003

g_ticks = $71 ; maintained by irq; +1 every 10ms
    include ticks.s
    include sound.s
    include lcd.s

bptr = $72 ;2 bytes
g_sleep_ticks = $74

main_reset:
    lda #%11111111
    sta DDRA
    lda #%11111111
    sta DDRB

    jsr init_ticks
    jsr init_sound
    jsr init_lcd
    jsr lcd_clear_display
    jsr print_message
    jmp play_music

print_message:
    ldy #0
print_message_loop:
    lda message,y
    beq print_message_done
    jsr lcd_putchar
    iny
    jmp print_message_loop
print_message_done:
    rts

message: .asciiz "** Arcadians ** "

play_music:
    lda #(data & $ff)       ;lo
    sta bptr
    lda #(data >> 8)        ;hi
    sta bptr+1
    ldy #0
    lda (bptr),y            ; read DEL
    asl                     ; double it; to change units from 1/50s -> 1/100s
    clc
    adc g_ticks
    sta g_sleep_ticks
top_loop:
    jsr send_if_time_to_send
    jmp top_loop

send_if_time_to_send:
    sec
    lda g_sleep_ticks
    sbc g_ticks
    beq send_bytes
    rts
send_bytes:
    ;; bptr points to the delay we just did, at +1 we have #bytes to send
    ldy #1
    lda (bptr),y                 ; read N, the #bytes to send
    beq finish                     ; stop if 0
    tax
continue_send_bytes:
    iny                         ; y=2 (skipping DEL,N)
    ;; x: N, N-1 ... 1
    ;; y: 2, 3 ... N+2
    lda (bptr),y                 ; read data byte to send
    jsr sound_send_data
    dex
    bne continue_send_bytes
    iny                     ; y is now N+2
    ;; read next DEL and increment g_sleep_ticks
    lda (bptr),y
    asl                         ; double DEL
    clc
    adc g_sleep_ticks
    sta g_sleep_ticks
    ;; shift buffer pointer by y (N+2)
    tya
    clc
    adc bptr
    sta bptr
    bcc shift_btr_no_carry
    inc bptr + 1
shift_btr_no_carry:
    rts

finish:
spin:
    jmp spin

;;; buffer format: repeats of: DEL, N, b1,b2..bN,
;;; DEL in 1/50s, N is number of following bytes

data:
    include arc-data.s
    .byte 0, 0                     ;FINISH
