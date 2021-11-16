
;;; Play with (forth-based) ideas to structure computations:
;;; - 0 basic 16bit leaf ops (+, inc) which can be combined DONE
;;; - 1 use of data-stack for arguments and results DONE
;;; - 2 forth style composition DONE
;;; - 3 maintain own return stack, so...
;;; - 4 task switching (each with own pair of stacks)
;;; - 5 explore co-operative vs pre-emptive task switching
;;; Try out assembly macros
;;; Idea for computations:
;;; - counting DONE
;;; - collatz
;;; - slow fib calculation
;;; - prime generation
;;; - binary2decimal DONE
;;; - multiplication
;;; - ops for implementing a clock
;;; Beter LCD abstraction
;;; - perhaps manipulate screen-contents in memory DONE
;;; - with sep thread which keeps LCD up to date with mem

    .org $fffc
    .word reset_main
    .word ticks_irq

    .org $8000

g_ticks = $10
g_number = $11 ; 2 bytes

g_divisor = $13 ; 2 bytes
g_mod10 = $15 ; 2 bytes

    include ticks.s
    include lcd.s

reset_main:
    jsr init_via
    jsr init_ticks
    jsr init_lcd
    jsr lcd_clear_display
    jsr init_screen
    jsr example
spin:
    jmp spin

    include via.s ; TODO: move to top

;;;--------------------
;;; example which manipulates 16bit number in mem
;;; by dispatching to stack based ops
example:
    jsr init_number
    jsr init_ds_stack
    jsr print_screen_now
example_loop:
    jsr put_number_dec
    jsr put_dot
    jsr print_screen_when_time
    jsr push_number
    jsr ds_increment
    jsr pull_number
    jmp example_loop

next_screen_print = $33
print_screen_when_time:
    lda next_screen_print
    sec
    sbc g_ticks
    beq print_screen_now
    rts
print_screen_now:
    jsr print_screen
    lda g_ticks
    clc
    adc #5 ; 20 times/sec
    sta next_screen_print
    rts

sleep:
    clc
    adc g_ticks
    pha ; goal ticks
sleep_wait:
    sec
    pla
    pha
    sbc g_ticks
    bne sleep_wait
    pla
    rts

init_number:
    lda #0
    sta g_number
    lda #0
    sta g_number + 1
    rts

put_number_dec: ; print 1-5 decimal digits for 16 bit number
    jsr screen_return_home
    lda g_number
    ldx g_number + 1
    jsr put_word_ax_in_decimal
    rts

put_dot:
    pha ; make sure this debug routine changes no registers!
    lda #'.'
    jsr screen_putchar_raw
    pla
    rts

push_number:
    lda g_number
    ldx g_number + 1
    jsr ds_push_ax
    rts

pull_number:
    jsr ds_pull_ax
    sta g_number
    stx g_number + 1
    rts


;;;--------------------
;;; derived data-stack (ds)  ops

ds_triple: ;not used at moment
    jsr ds_dup
    jsr ds_dup
    jsr ds_add
    jsr ds_add
    rts

ds_increment:
    jsr ds_push_one
    jsr ds_add
    rts

ds_decrement:
    jsr ds_push_minus_one
    jsr ds_add
    rts

ds_push_one:
    lda #1 ; lo
    ldx #0 ; hi
    jsr ds_push_ax
    rts

ds_push_minus_one:
    lda #$ff ; lo
    ldx #$ff ; hi
    jsr ds_push_ax
    rts

;;;--------------------
;;; primitive data-stack (ds) of 16bit values
;;; keep data stack in zero page, growing downwards; using y to index

init_ds_stack:
    ldy #$ff
    rts

ds_push_ax: ; ( -- x;a )
    dey
    dey
    sta 1,y
    stx 2,y
    rts

ds_pull_ax: ; ( x;a -- )
    lda 1,y
    ldx 2,y
    iny
    iny
    rts

ds_dup: ; (V -- V V)
    dey
    dey
    lda 4,y
    sta 2,y
    lda 3,y
    sta 1,y
    rts

ds_add: ; (A B -- A+B)
    clc
    lda 1,y
    adc 3,y ;lo
    sta 3,y
    lda 2,y
    adc 4,y ;hi
    sta 4,y
    iny
    iny
    rts

;;;--------------------
;;; sleep for N (in acc) 1/100s
;; sleep:
;;     clc
;;     adc g_ticks
;;     pha ; goal ticks
;; sleep_wait:
;;     sec
;;     pla
;;     pha
;;     sbc g_ticks
;;     bne sleep_wait
;;     pla
;;     rts


;;; TODO: delete in favour of using version in decimal
;;; after having adapted to use teh scrolling version
put_word_ax_in_decimal:
    sta g_divisor ;lo
    stx g_divisor + 1 ;hi
    lda #0
    pha ; marker for print
each_digit:
    lda #0
    sta g_mod10
    sta g_mod10 + 1
    clc
    ldx #16
each_bit:
    rol g_divisor
    rol g_divisor + 1
    rol g_mod10
    rol g_mod10 + 1
    sec
    lda g_mod10
    sbc #10
    pha ; save
    lda g_mod10 + 1
    sbc #0
    bcc ignore_result
    sta g_mod10 + 1
    pla
    pha
    sta g_mod10
ignore_result:
    pla ;drop
    dex
    bne each_bit
    rol g_divisor
    rol g_divisor + 1
    clc
    lda g_mod10
    adc #'0'
    pha ;save on stack for reverse print
    lda g_divisor
    ora g_divisor + 1
    bne each_digit
put_from_stack:
    pla
    beq done
    jsr screen_putchar_raw ; TODO: use scrolling
    jmp put_from_stack
done:
    rts

;;;--------------------
;;; async lcd printing

g_screen = $200 ; 32 bytes
g_screen_pointer = $220
    include screen.s            ; TODO move to top
