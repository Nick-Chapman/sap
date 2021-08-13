
module Emu
  ( runIO, runCollectOutput
  , Cycles(..), OutOfGas(..)
  ) where

import Data.Bits (testBit,shiftL,shiftR,(.&.))
import Data.Map (Map)
import Op (Op(..),Byte)
import Text.Printf (printf)
import qualified Data.Map as Map

runIO :: [Op] -> IO ()
runIO prog = do
  --print prog
  let state0 = initState prog
  loop 0 state0
  where
    loop :: Int -> State -> IO ()
    loop i s = do
      let State{ir} = s
      --printf "%3d : %s : %s\n" i (show s) (show (decodeOp ir))
      let cat = decodeCat ir
      --print cat
      let con = cat2control cat
      --print con
      let (s'Maybe,oMaybe) = step s con
      case oMaybe of
        Nothing -> pure ()
        Just (Output byte) -> print ("output",byte)
      case s'Maybe of
        Nothing -> do
          --print (mem s)
          pure () --done
        Just s' -> loop (i+1) s'

runCollectOutput :: Cycles -> [Op] -> Either OutOfGas (Cycles,[Byte])
runCollectOutput max prog = do
  let state0 = initState prog
  loop (Cycles 0) [] state0
  where
    loop :: Cycles -> [Byte] -> State -> Either OutOfGas (Cycles,[Byte])
    loop cycles acc s = if cycles > max then Left OutOfGas else do
      let State{ir} = s
      let cat = decodeCat ir
      let con = cat2control cat
      let (s'Maybe,oMaybe) = step s con
      let acc' = case oMaybe of
            Nothing -> acc
            Just (Output byte) -> byte:acc
      case s'Maybe of
        Nothing -> Right (cycles, reverse acc') -- done
        Just s' -> loop (cycles+1) acc' s'


data OutOfGas = OutOfGas
newtype Cycles = Cycles Int deriving (Eq,Ord,Num,Show)


----------------------------------------------------------------------
-- Cat

data Cat = Cat -- Control atributes
  { xbit7 :: Bool
  , xbit6 :: Bool -- if-zero bit for jump instruction; sub-bit for alu
  -- TODO: rename writer/reader as src/dest (of bus)
  , writer :: WriterD -- bit 5,4
  , reader :: ReaderD -- bit 3,2,1
  , indexed :: Bool -- bit 0 (address bus driven from X otherwise PC++)
  }
  | Lit Byte
  deriving Show

op2cat :: Op -> Cat
op2cat = \case
  NOP -> Cat o o FromMem ToI o
  LIA -> Cat o o FromMem ToA o
  LIB -> Cat o o FromMem ToB o
  LIX -> Cat o o FromMem ToM o
  LXA -> Cat o o FromMem ToA x
  LXB -> Cat o o FromMem ToB x
  LXX -> Cat o o FromMem ToM x
  SXA -> Cat o o FromAcc Store x
  JIU -> Cat o x FromMem ToP  o
  JIZ -> Cat o o FromMem ToP  o
  JXU -> Cat o x FromMem ToP  x
  JXZ -> Cat o o FromMem ToP  x
  JAU -> Cat o x FromAcc ToP  x
  ADD -> Cat o o FromAlu ToA x
  ADDB -> Cat o o FromAlu ToB x
  ADDX -> Cat o o FromAlu ToM x
  ADDM -> Cat o o FromAlu Store x
  ADDOUT -> Cat o o FromAlu Out x
  SUB -> Cat o x FromAlu ToA x
  SUBB -> Cat o x FromAlu ToB x
  SUBX -> Cat o x FromAlu ToM x
  OUT -> Cat o o FromAcc Out x
  OUTM -> Cat o o FromMem Out x
  TAB -> Cat o o FromAcc ToB x
  TAX -> Cat o o FromAcc ToM x
  TXA -> Cat o o FromX ToA x
  HLT -> Cat o o FromMem Halt x
  IMM b -> Lit b
  where
    o = False
    x = True

encodeCat :: Cat -> Byte
encodeCat = \case
  Cat{xbit7,xbit6,writer,reader,indexed} ->
    0
    + (if xbit7 then 1 else 0) `shiftL` 7
    + (if xbit6 then 1 else 0) `shiftL` 6
    + encodeWriter writer `shiftL` 4
    + encodeReader reader `shiftL` 1
    + (if indexed then 1 else 0)
  Lit b ->
    b

decodeCat :: Byte -> Cat
decodeCat b = do
  let xbit7 = b `testBit` 7
  let xbit6 = b `testBit` 6
  let writer = decodeWriter ((b `shiftR` 4) .&. 3)
  let reader = decodeReader ((b `shiftR` 1) .&. 7)
  let indexed = b `testBit` 0
  Cat {xbit7,xbit6,writer,reader,indexed}


data WriterD = FromAcc | FromMem | FromAlu | FromX
  deriving Show

encodeWriter :: WriterD -> Byte
encodeWriter = \case
  FromMem -> 0
  FromAcc -> 1
  FromAlu -> 2
  FromX -> 3

decodeWriter :: Byte -> WriterD
decodeWriter = \case
  0 -> FromMem
  1 -> FromAcc
  2 -> FromAlu
  3 -> FromX
  x -> error (show ("decodeWriter",x))


data ReaderD
  = ToI | ToP | ToA | ToB
  | ToM -- TODO: rename ToX
  | Store | Out | Halt
  deriving (Eq,Show)

encodeReader :: ReaderD -> Byte
encodeReader =  \case
  ToI -> 0
  ToP -> 1
  ToA -> 2
  ToB -> 3
  ToM -> 4
  Store -> 5
  Out -> 6
  Halt -> 7 -- TODO: dont encode halt this way. save one of the 8 encodings for future

decodeReader :: Byte -> ReaderD
decodeReader = \case
  0 -> ToI
  1 -> ToP
  2 -> ToA
  3 -> ToB
  4 -> ToM
  5 -> Store
  6 -> Out
  7 -> Halt
  x -> error (show ("decodeReader",x))

----------------------------------------------------------------------
-- Control

data Control = Control
  { writeAbus :: WriterA --TODO: kill. just use indexed (or negate to immediate)
  , writeDbus :: WriterD --TODO: Have 4 enables instead of this
  , loadIR :: Bool
  , loadPC :: Bool
  , loadAcc :: Bool
  , loadB :: Bool
  , loadMar :: Bool
  , storeMem :: Bool
  , doOut :: Bool
  , halt :: Bool
  , incPC :: Bool
  , doSubtract :: Bool
  , unconditionalJump :: Bool
  } deriving Show

data WriterA = WA_PC | WA_Mar deriving Show

cat2control :: Cat -> Control
cat2control = \case
  Lit{} -> error "unexpected Cat/Lit"
  Cat{xbit6,reader,writer,indexed} -> do
    let writeAbus = if indexed then WA_Mar else WA_PC
    let writeDbus = writer
    let loadIR = (reader == ToI)
    let loadPC = (reader == ToP)
    let loadAcc = (reader == ToA)
    let loadB = (reader == ToB)
    let loadMar = (reader == ToM)
    let storeMem = (reader == Store)
    let doOut = (reader == Out)
    let halt = (reader == Halt)
    let incPC = not indexed
    let doSubtract = xbit6
    let unconditionalJump = xbit6
    Control {writeAbus,writeDbus
            ,loadIR,loadPC,loadAcc,loadB,loadMar,storeMem
            ,doOut,halt,incPC,doSubtract,unconditionalJump}

----------------------------------------------------------------------
-- State

data State = State
  { mem :: Map Byte Byte
  , ir :: Byte
  , pc :: Byte
  , acc :: Byte
  , b :: Byte
  , mar :: Byte -- TODO: rename x
  }

instance Show State where
  show State{ir,pc,acc,b,mar} =
    printf "PC=%02X IR=%02X A=%02X B=%02X MAR=%02X" pc ir acc b mar

initState :: [Op] -> State
initState prog = State
  { mem = initMem prog
  , ir = 0
  , pc = 0
  , acc = 0
  , b = 0
  , mar = 0
  }

initMem :: [Op] -> Map Byte Byte
initMem prog = Map.fromList (zip [0..] (map encodeOp prog))

encodeOp :: Op -> Byte
encodeOp = encodeCat . op2cat

data Output = Output Byte

step :: State -> Control -> (Maybe State,Maybe Output)
step state control = do
  let State{mem,ir=_,pc,acc,b,mar} = state
  let Control{writeAbus,writeDbus
             ,loadAcc,loadB,loadMar,loadIR,loadPC,storeMem
             ,doOut,halt,incPC,doSubtract,unconditionalJump} = control
  let aIsZero = (acc == 0)
  let jumpControl = unconditionalJump || aIsZero
  let abus = case writeAbus of
        WA_PC -> pc
        WA_Mar -> mar
  let alu =
        if doSubtract then (acc - b) else (acc + b) -- `mod` 256 -- sub!
  let dbus = case writeDbus of
        FromAcc -> acc
        FromMem -> maybe 0 id (Map.lookup abus mem)
        FromAlu -> alu
        FromX -> mar
  let s' = State
        { mem = if storeMem then Map.insert abus dbus mem else mem
        , ir = if loadIR then dbus else 0
        , pc = if loadPC && jumpControl then dbus else if incPC then incByte pc else pc
        , acc = if loadAcc then dbus else acc
        , b = if loadB then dbus else b
        , mar = if loadMar then dbus else mar
        }
  (if halt then Nothing else Just s',
   if doOut then Just (Output dbus) else Nothing
    )

incByte :: Byte -> Byte
incByte b = if b == 255 then 0 else b + 1
