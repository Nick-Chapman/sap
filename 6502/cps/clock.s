;;; clock task, in cps style

;;; clock 2 3 4 5
;;; [..]  (h m s j)
clock:
.h = 2 ; hours
.m = 3 ; minutes
.s = 4 ; seconds
.j = 5 ; jiffy to tick
.roots:
    rts ; no roots
.evac:
    rts ; static
.scav:
    impossible_scavenge_because_static
.begin:
    store16i .static_closure, fp ; TODO: need ,x based indexing? -- hmm, perhaps not
    stz .s, x
    stz .m, x
    stz .h, x
.again:
    jsr .display
    jsr .tick
    clc
    lda g_ticks
    adc #100
    sta .j, x
    rts
.static_closure:
    word .code
    word .roots, .evac, .scav
.code
    lda g_ticks
    cmp .j, x
    bpl .go
    enter_fp
.go:
    jsr .again
    enter_fp

print_leading_zero: macro V
    lda \V, x
    cmp #10
    bcs .skip\@
    print_char '0'
.skip\@:
endmacro

.display:
    jsr screen_return_home
    print_leading_zero .h
    print_decimal_byte_x .h
    print_char ':'
    print_leading_zero .m
    print_decimal_byte_x .m
    print_char ':'
    print_leading_zero .s
    print_decimal_byte_x .s
    print_string "   " ; just in case we get corrupton; better chance to see the data
    newline
    print_string "clock"
    rts

increment_modulo: macro V, N
    inc \V, x
    lda \V, x
    cmp #\N
    bne .done
    stz \V, x
endmacro

.tick:
    increment_modulo .s, 60
    increment_modulo .m, 60
    increment_modulo .h, 24
.done:
    rts
