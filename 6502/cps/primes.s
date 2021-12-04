
True = 1
False = 0

JUMP: macro DEST
    ;; Maybe switch task here
    jmp \DEST
endmacro

enter_fp: macro
    copy_word_from_frame0 cp
    JUMP (cp)
endmacro

;;; ----------------------------------------------------------------------
;;; Number args/locals from 1 (because of plan to have fp as 0)
;;; BUT IT NEEDS TO START FROM 2, because fp is a word!

;;; ----------------------------------------------------------------------
;;; array access

load_byte_from_array: macro A, N
    ldy #\N
    lda (\A),y
endmacro

read_indexed0: macro P, V
    lda (\P)
    sta \V
    ldy #1
    lda (\P),y
    sta \V + 1
endmacro

;;; ----------------------------------------------------------------------
;;; push/pull macros

push_word_immediate: macro LIT
    lda #>\LIT
    pha
    lda #<\LIT
    pha
endmacro

;;; ----------------------------------------------------------------------
;;; cons-cell of 16-bit numbers
;;; (we need to know the element's size & that it's not a heap value)
;;;
;;; fp
;;;     .23 .45
;;; [..  i   tail]
cons_cell_i16:
    byte 'C'
    word .roots, .evac, .scav
.code:
    ;; \n c -> c i tail
    pla ; cL
    sta temp
    pla ; cH
    sta temp + 1
    pla ; nL
    pla ; nH
    ;; setup head/tail
    load_byte_from_array data_pointer, 3
    pha ; iH
    load_byte_from_array data_pointer, 2
    pha ; iL
    load_byte_from_array data_pointer, 5
    pha ; tailH
    load_byte_from_array data_pointer, 4
    pha ; tailL
    jmp (temp)
.roots:
    impossible_roots
.evac:
    evacuate 6
.scav
    scavenge_cell_at 4 ; tail
    scavenge_done 6


nil_cell_i16:
    byte 'N'
    word .roots, .evac, .scav
.code:
    pla ; cL
    pla ; cH
    pla ; nL
    sta temp
    pla ; nH
    sta temp + 1
    jmp (temp)
.roots:
    impossible_roots
.evac:
    no_evacuate_because_static
.scav:
    impossible_scavenge_because_static
.static_closure:
    word .code


;; primes:
;; .code:
;; .evac:
;; .scav:
;; .static_closure:

;; primes :: IO ()
;; primes = search 2 nil

;; search :: Int -> List Int -> IO ()
;; search i ps = do
;;   candidate i ps $ \b ->
;;     case b of
;;       True -> do
;;         let ps' = cons (i,ps)
;;         print i
;;         search (i+1) ps'
;;       False ->
;;         search (i+1) ps

;;; TODO: search

;;; candidate :: Int -> List Int -> (Bool -> r) -> r
;;; candidate i ps k = do
;;;   let nil = \() -> k True
;;;   let cons = \p ps ->
;;;     let k1 = make_candidate_cont (i,ps,k)
;;;     divides i p k1
;;;   match ps nil cons
;;;
;;; fp    23 45 67
;;; [..] (i  ps k)
candidate:
    byte 'A'
    word .roots, .evac, .scav
.code:
    ;; match ps nil cons
    push_word_immediate .nil
    push_word_immediate .cons
    copy_word arg4,data_pointer ;ps
    read_indexed0 data_pointer, cp
    JUMP (cp)
.nil:
    copy_word arg6,fp ;k
    lda #True
    sta arg2
    enter_fp ; k True
.cons:
    ;; \p ps' -> let k1 = make_candidate_cont (i,ps,k) ...
    heap_alloc 'd', 8
    ;; fill in closure
    copy_code_pointer_to_heap0 candidate_cont.code
    copy_word_local_to_heap arg2, 2 ; i
    pla ; ps'L
    store_heap 4
    pla ; ps'H
    store_heap 5
    copy_word_local_to_heap arg6, 6 ; k
    ;; setup args
    ;; iL,iH already in arg2,arg3
    pla ; pL
    sta arg4
    pla ; pH
    sta arg5
    copy_word clo, arg6
    copy_code_pointer_to_local divides.static_closure, fp
    JUMP divides.code ; divides i p k1
.roots:
    gc_root_at arg4 ; ps
    gc_root_at arg6 ; k
    rts
.evac:
    no_evacuate_because_static
.scav:
    impossible_scavenge_because_static
.static_closure:
    word .code

;;; make_candidate_cont :: (Int,List Int,(Bool -> r)) -> Bool -> r
;;; make_candidate_cont (i,ps,k) = \b -> if b then k False else candidate i ps k
;;;
;;; fp                2
;;;    .23 .45 .67
;;; [.. i   ps  k  ] (b)
candidate_cont:
    byte 'B'
    word .roots, .evac, .scav
.code:
    lda arg2 ; b
    bne .bTrue
    ;; candidate i ps k
    copy_word_from_frame 2, arg2 ; i
    copy_word_from_frame 4, arg4 ; ps
    copy_word_from_frame 6, arg6 ; k
    copy_code_pointer_to_local candidate.static_closure, fp
    JUMP candidate.code
.bTrue:
    copy_word_from_frame 6, arg3 ; k -> fp (using 2 as a temp)
    copy_word arg3, fp
    lda #False
    sta arg2
    enter_fp ; k False
.roots:
    rts ; no roots
.evac:
    evacuate 8
.scav:
    scavenge_cell_at 4 ; ps
    scavenge_cell_at 6 ; k
    scavenge_done 8


;;; divides :: Int -> Int -> (Bool -> r) -> r
;;; divides i p k =
;;;   if i == 0 then k True else let i' = i-p in if i' < 0 then k False else divides i' p k
;;;
;;; fp    23 45 67
;;; [..] (i  p  k)
divides:
    byte 'D'
    word .roots, .evac, .scav
.code:
    lda arg2 ;iL
    ora arg3 ;iH
    beq .baseT ;i==0
    sec
    lda arg2 ;iL
    sbc arg4 ;pL
    sta arg2 ;i'L (ok to save even if we branch to baseF)
    lda arg3 ;iL
    sbc arg5 ;pL
    bmi .baseF
    sta arg3 ; i'H
    JUMP .code ; divides i' p k
.baseT:
    copy_word arg6,fp ;k
    lda #True
    sta arg2
    enter_fp ; k True
.baseF:
    copy_word arg6,fp ;k
    lda #False
    sta arg2
    enter_fp ; k False
.roots:
    gc_root_at arg6 ; k
    rts
.evac:
    no_evacuate_because_static
.scav:
    impossible_scavenge_because_static
.static_closure:
    word .code