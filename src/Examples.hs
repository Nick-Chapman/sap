
module Examples
  ( variousInstructions
  , countdown5to0
  , multiply5by7
  , fibA, fibB, fibC
  , vSmall
  , fibForever, fibUnrolled
  , fib2vars, fib3vars
  , varProg1, varProg0
  , collatz
  , openCountLoop, tightCountLoop
  , countdownForeverZ, countdownForeverC
  ) where

import Asm

variousInstructions :: [Op]
variousInstructions =
  [ LIA, IMM 42
  , LIB, IMM 33
  , ADD
  , OUT -- expect 75
  , LIB, IMM 1
  , SUB
  , OUT -- expect 74
  , LIX, IMM 50
  , LIA, IMM 111
  , SXA
  , LIX, IMM 51
  , LIA, IMM 222
  , SXA
  , TAX
  , LIA, IMM 77
  , SXA
  , LIX, IMM 50
  , LXA
  , OUT -- expect 111
  , LIA, IMM 50
  , OUTM -- expect 111
  , LIB, IMM 1
  , ADDX
  , LXA
  , OUT -- expect 222
  , LIA, IMM 0
  , LIX, IMM 51
  , LXX
  , LXA
  , OUT -- expect 77
  , HLT
  ]

-- TODO: recode remaining example using Asm

countdown5to0 :: [Op]
countdown5to0 =
  [ LIB, IMM 1
  , LIA, IMM 5
--4:
  , OUT
  , SUB
  , LIX, IMM 12, JXZ
  , LIX, IMM 4, JXU
--12:
  , OUT
  , HLT
  ]

multiply5by7 :: [Op]
multiply5by7 =
  [ LIX, IMM 11, JXU
-- static mem storage
  , IMM 5 -- #3 left
  , IMM 7 -- #4 right
  , IMM 0 -- #5 result
-- 6: finish
  , LIX, IMM result, LXA
  , OUT
  , HLT
-- 11: main loop
  , LIX, IMM left, LXA
  , LIX, IMM 6, JXZ
  , LIB, IMM 1
  , SUB
  , LIX, IMM left, SXA
  , LIX, IMM right, LXB
  , LIX, IMM result, LXA
  , ADD
  , SXA
  , LIX, IMM 11, JXU
  ]
  where
    left = 3
    right = 4
    result = 5

fibA :: [Op]
fibA =
  [ LIX, IMM 7, JXU
-- 3:
  , HLT
  , IMM 0
  , IMM 1
  , IMM 0
-- 7:
  , LIX, IMM 4, LXA, TAB
  , LIX, IMM 5, LXA, OUT
  , ADD, LIX, IMM 6, SXA
  , LIB, IMM 144, SUB, LIX, IMM 3, JXZ
  , LIX, IMM 5, LXA, LIX, IMM 4, SXA
  , LIX, IMM 6, LXA, LIX, IMM 5, SXA
  , LIX, IMM 7, JXU
  ]

fibB :: [Op]
fibB = assemble $ mdo
  jump loop
  done <- Here
  halt
  p <- variable 0
  q <- variable 1
  loop <- Here
  loadA q
  out
  lb 89; sub; jz done; add
  loadB p
  storeAdd q
  storeA p
  jump loop

fibC :: [Op]
fibC = assemble $ mdo
  lb 0
  la 1
  loop <- Here
  out; addx
  tab; txa
  jc done
  jump loop
  done <- Here
  halt

vSmall :: [Op]
vSmall = assemble $ do
  la 21
  tab
  add
  out
  halt

fibForever :: [Op]
fibForever = assemble $ mdo
  la 1
  loop <- Here
  out; addx
  tab; txa
  jump loop

fibUnrolled :: [Op]
fibUnrolled = assemble $ mdo
  lb 1
  addout
  add
  addout
  addb
  addout
  add
  addout
  addb
  addout
  add
  addout
  addb
  halt

fib2vars :: [Op] -- program which uses memory for variable storage (2 vars)
fib2vars = assemble $ mdo
  start <- Here
  la 1
  storeA q
  la 0
  storeA p
  loop <- Here
  loadB p
  loadA q
  storeA p
  add
  storeA q
  out
  lb 233; sub
  jz start --Emit [TAX, JXZ]
  jump loop
  pure ()
  p <- variable 0
  q <- variable 0
  pure ()

fib3vars :: [Op] -- program which uses memory for variable storage (3 vars)
fib3vars = assemble $ mdo
  start <- Here
  la 0
  storeA p
  la 1
  storeA q
  loop <- Here
  loadA p
  loadB q
  add
  storeA r
  loadA q
  storeA p
  loadA r
  storeA q
  out
  lb 233; sub; jz start
  jump loop
  p <- variable 0
  q <- variable 0
  r <- variable 0
  pure ()

varProg1 :: [Op] -- small program which does something useful with memory
varProg1 = assemble $ mdo
  start <- Here
  loadA v1
  out
  lb 1
  add
  storeA v1
  la 0
  out
  jump start
  v1 <- variable 42
  pure ()

varProg0 :: [Op] -- even smaller
varProg0 = assemble $ mdo
  lb 1
  loop <- Here
  loadA v1
  out
  add
  --storeA v1
  sxa
  jump loop
  v1 <- variable 17
  pure ()


collatz :: [Op]
collatz = assemble $ mdo
  main <- Here
  loadA next
  storeA current
  lb 1; add; storeA next

  la 0; storeA steps
  sequence <- Here
  increment steps 1
  loadA current
  out
  lb 1; sub; jz reached1; add

  -- try to divide by 2
  storeA tmp
  la 0; storeA count
  div2 <- Here
  loadA tmp
  jz after_div2
  lb 2; sub
  jc mult3plus1 -- not divisible by 2
  storeA tmp
  increment count 1
  jump div2
  after_div2 <- Here
  loadA count
  storeA current -- divide by 2
  jump sequence

  count <- variable 0
  tmp <- variable 0

  -- multiply by 3 and +1
  mult3plus1 <- Here
  loadA current
  tab; add; add; lb 1; add
  storeA current
  jump sequence

  reached1 <- Here
  loadA steps; out
  jump main

  next <- variable 7
  current <- variable 0
  steps <- variable 0
  pure ()


openCountLoop :: [Op]
openCountLoop = assemble $ do
  lb 1
  add
  out

tightCountLoop :: [Op]
tightCountLoop = assemble $ mdo
  lb 1
  lx loop
  loop <- Here
  add
  out
  --jump loop
  jxu

countdownForeverZ :: [Op]
countdownForeverZ = assemble $ do
  lb 1
  start <- Here
  la 5
  loop <- Here
  out
  jz start
  sub
  jump loop

countdownForeverC :: [Op]
countdownForeverC = assemble $ do
  lb 1
  start <- Here
  la 5
  loop <- Here
  out
  sub
  jc loop
  jump start
