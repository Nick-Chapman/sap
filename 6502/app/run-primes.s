;;; Top level app to generate primes numbers

    org $fffa
    word nmi
    word reset_main
    word irq
    org $8000

    include via.s
    include ticks.s
    include nmi_irq.s
    include lcd.s
    include arith16.s
    include acia.s
    include sleep.s
    include screen.s
    include macs.s
    include decimal.s
    include print.s
    include debug.s
    include panic.s
    include macs.s
    include arith16.s
    include heap.s

find_roots:
    find_roots_from fp
    rts

task_vars_offset = 20

enter_fp: macro
    load16_0 fp, cp
    jsr screen_flush_when_time
    ldx #task_vars_offset
    jmp (cp)
endmacro

    include primes.s

;;; bytes
heap_end_page = $30
g_ticks = $32
gc_screen = $33
g_selected_screen = $34
g_nmi_count = $35
g_nmi_blocked = $36
g_next_screen_flush = $37

;;; words
g_heap_pointer = $40
heap_start = $4e
gc_count = $50
space_switcher = $52
g_divisor = $54 ; decimal.s
g_mod10 = $56 ; decimal.s
g_mptr = $58 ; print.s
g_putchar = $5a ; decimal.s

NUM_SCREENS = 2
g_screen_pointers = $80
g_screens = $200 ; 4*32 bytes

reset_main:
    ldx #$ff
    txs
    jsr init_via
    jsr init_ticks
    jsr init_nmi_irq
    jsr init_acia
    jsr init_lcd
    jsr lcd_clear_display
    jsr init_screen
    init_heap 1 ; screen-number
    ldx #task_vars_offset
    jsr primes.begin
    enter_fp
