    org $fffa
    word nmi
    word main
    word deprecated_ticks_irq
    org $8000

cpu_clks_per_sec = 4 * MHz ; run more slowly for the ACIA chip

    include via.s
    include arith16.s
    include acia.s
    include ticks1.s
    include lcd.s
    include screen.s
    include macs.s
    include decimal16.s
    include print.s
    include sleep.s

g_ticks = $32
g_selected_screen = $34

g_nmi_count = $35
g_next_screen_flush = $37

g_divisor = $54 ; decimal16.s
g_mod10 = $56 ; decimal16.s
g_mptr = $58 ; print.s / acia.put_string
g_putchar = $5a ; decimal16.s

NUM_SCREENS = 2
g_screen_pointers = $80
g_screens = $200

nmi:
    rti

main:
;;; local vars in zero page
.count = 0
.received = 1
    ldx #$ff
    txs
    jsr init_via
    jsr init_ticks
    jsr lcd.init
    jsr lcd.clear_display
    jsr screen.init
    jsr acia.init
    stz .count
.again:
    inc .count

    print_decimal_byte .count
    print_char '-'
    screen_flush_selected

    acia_print_string "WALL OF TEXT\n"
    lda #>wall_of_text
    pha
    lda #<wall_of_text
    pha
    jsr acia.put_string
    pla
    pla
    acia_print_string "press a key\n"
    jsr acia.read_blocking
    sta .received
    jsr screen.putchar

    print_hex_byte .received
    print_char ' '
    screen_flush_selected

    jmp .again


wall_of_text: ; a little over 2Kb (xs82*25 + 2 = 2052)
    text "a.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "b.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "c.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "d.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "e.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "f.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "g.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "h.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "i.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "j.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "k.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "l.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "m.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "n.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "o.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "p.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "q.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "r.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "s.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "t.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "u.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "v.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "w.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "x.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "y.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789\n"
    text "z\n"
