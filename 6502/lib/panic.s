
;;; TODO: take a string, not just a char

panic: macro CHAR
    lda #\CHAR
    jmp panic.stop
endmacro

panic:
.stop:
    pha
    lda #'!'
    jsr screen_putchar
    pla
    jsr screen_putchar
    jsr print_screen
.spin:
    jmp .spin