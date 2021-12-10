
;;; Top level count monitor,
;;; How many times per jiffy (1/100s) do we complete the cyclic_executive

    org $fffa
    word nmi
    word reset_main
    word irq

    org $8000

    include via.s
    include ticks.s
    include nmi_irq.s
    include lcd.s
    include screen.s

    include decimal.s
    include print.s

;;; bytes
g_ticks = $30
g_selected_screen = $31
g_nmi_count = $32
g_nmi_blocked = $33
g_next_screen_flush = $34
g_last_speed_check_time = $35

;;; words
g_speed = $40 ; #repeats of cyclic_executive per jiffy
g_mptr = $42 ; print.s
g_divisor = $44 ; decimal.s
g_mod10 = $46 ; decimal.s


NUM_SCREENS = 1
g_screen_pointers = $80

;;; buffers
g_screens = $200 ; page

reset_main:
    ldx #$ff
    txs
    jsr init_via
    jsr init_ticks
    jsr init_nmi_irq
    jsr init_lcd
    jsr lcd_clear_display
    jsr init_screen

    jsr screen_flush_now ; sets the next(first) time to flush
    jsr init_speed_check
    jmp cyclic_executive

cyclic_executive:
    jsr check_speed
    jsr screen_flush_when_time
    jmp cyclic_executive

init_speed_check:
    lda g_ticks
    sta g_last_speed_check_time
    stz g_speed
    stz g_speed + 1
    rts

check_speed:
    sec
    lda g_last_speed_check_time
    sbc g_ticks
    bmi .we_have_advanced
    inc g_speed
    bne .skip
    inc g_speed + 1
.skip:
    rts
.we_have_advanced:
    jsr screen_return_home
    ;newline
    ;print_char ' '
    print_decimal_word g_speed ; how much slower?
    jsr init_speed_check
    rts