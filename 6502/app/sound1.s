
;;; first attempts to drive 76489 sound chip

    org $fffc
    word main_reset
    word ticks_irq

    org $8000

g_ticks = $50

    include via.s
    include ticks.s
    include lcd.s
    include sound.s
    include sleep.s

main_reset:
    jsr init_via
    jsr init_lcd
    jsr init_sound
    jsr init_ticks

    lda #'!'
    jsr message
    jsr pause

    lda #'X'
    jsr message
    jsr silence_all
loop:
    jsr pause

    lda #'D'
    jsr message
    jsr loud_0
    jsr tone_d
    jsr pause

    lda #'E'
    jsr message
    jsr tone_e
    jsr pause

    lda #'-'
    jsr message
    jsr silence_0
    jmp loop

pause:
    lda #100
    jmp sleep_blocking

message:
    pha
    jsr lcd_clear_display
    pla
    jsr lcd_putchar
    rts

tone_d:
    lda #$8a
    jsr sound_send_data
    lda #$06
    jsr sound_send_data
    rts

tone_e:
    lda #$8f
    jsr sound_send_data
    lda #$05
    jsr sound_send_data
    rts

silence_all:
    jsr silence_0
    jsr silence_1
    jsr silence_2
    jsr silence_3
    rts

silence_0:
    lda #$9f
    jsr sound_send_data
    rts

silence_1:
    lda #$bf
    jsr sound_send_data
    rts

silence_2:
    lda #$df
    jsr sound_send_data
    rts

silence_3:
    lda #$ff
    jsr sound_send_data
    rts

loud_0:
    lda #$90
    jsr sound_send_data
    rts