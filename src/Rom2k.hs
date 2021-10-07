module Rom2k (generateAll) where

import Data.Bits (shiftL)
import Data.Word8 (Word8)
import Examples
import Op (Op)
import Prelude hiding (take)
import qualified Data.ByteString as BS
import qualified Emu (encodeOp)

take :: Int -> [a] -> [a]
take n = loop (0::Int) n
  where
    loop _ 0 _ = []
    loop i n xs = case xs of
      [] -> error (show ("take, not enough, have",i,"need another",n))
      x:xs -> x : loop (i+1) (n-1) xs

pad :: Word8 -> Int -> [Word8] -> [Word8]
pad filler n xs =
  if length xs > n then error (show ("pad",n,"will truncate from  size",length xs)) else
    take n (xs ++ repeat filler)

generateAll :: IO ()
generateAll = do
  putStrLn "*generating roms*"
  genRom2k "zero" $ replicate 2048 0x00
  genRom2k "erased" $ replicate 2048 0xff
  genRom2k "decimalLED" decimalLED
  genRom2k "hexLED" hexLED
  genRom2k "decimalAndHexLED" decimalAndHexLED
  genRom2k "progs" progs

genRom2k :: String -> [Word8] -> IO ()
genRom2k name bytes = do
  let n = length bytes
  if n == 2048 then pure () else error (show ("genRom2k",name,"wrong-size",n))
  --putStrLn $ "- " ++ name
  BS.writeFile ("roms/" ++ name ++ ".rom") (BS.pack bytes)

----------------------------------------------------------------------
-- LED roms

decimalLED :: [Word8]
decimalLED = concat
  [ erasedPage
  , take 256 (concat (repeat (ddigs order)))
  , take 256 (concat (repeat (concat $ map (replicate 10) (ddigs order))))
  , take 256 (concat (repeat (concat $ map (replicate 100) (ddigs order))))
  , erasedPage
  , erasedPage
  , erasedPage
  , erasedPage
  ]
  where
    order = SegOrder [P,G,F,A,B,C,D,E]

hexLED :: [Word8]
hexLED = concat
  [ erasedPage
  , erasedPage
  , erasedPage
  , erasedPage
  , erasedPage
  , erasedPage
  , concat (replicate 16 (hdigs order))
  , concat (map (replicate 16) (hdigs order))
  ]
  where
    order = SegOrder [P,G,F,A,B,C,D,E]

decimalAndHexLED :: [Word8]
decimalAndHexLED = concat
  [ erasedPage
  , take 256 (concat (repeat (ddigs order1)))
  , take 256 (concat (repeat (concat $ map (replicate 10) (ddigs order1))))
  , take 256 (concat (repeat (concat $ map (replicate 100) (ddigs order1))))
  , erasedPage
  , erasedPage
  , concat (replicate 16 (hdigs order2))
  , concat (map (replicate 16) (hdigs order2))
  ]
  where
    order1 = SegOrder [P,G,F,A,B,C,D,E] -- orig
    order2 = SegOrder [E,D,P,C,G,B,F,A] -- new

erasedPage :: [Word8]
erasedPage = replicate 256 0xff

ddigs :: SegOrder -> [Word8]
ddigs order = [ encodeSegs order (segs i) | i <- [0..9] ]

hdigs :: SegOrder -> [Word8]
hdigs order = [ encodeSegs order (segs i) | i <- [0..15] ]


newtype SegOrder = SegOrder [Seg] -- encoding order: from most to least sig bit

data Seg = A | B | C | D | E | F | G | P deriving Eq
{-
                      A
                    F   B
                      G
                    E   C
                      D      P (decimal point)
-}
segs :: Int -> [Seg]
segs = \case
  0x0 -> [ A, B, C, D, E, F    ]
  0x1 -> [    B, C             ]
  0x2 -> [ A, B,    D, E,    G ]
  0x3 -> [ A, B, C, D,       G ]
  0x4 -> [    B, C,       F, G ]
  0x5 -> [ A,    C, D,    F, G ]
  0x6 -> [ A,    C, D, E, F, G ]
  0x7 -> [ A, B, C             ]
  0x8 -> [ A, B, C, D, E, F, G ]
  0x9 -> [ A, B, C,       F, G ]
  0xa -> [ A, B, C,    E, F, G ]
  0xb -> [       C, D, E, F, G ]
  0xc -> [ A,       D, E, F    ]
  0xd -> [    B, C, D, E,    G ]
  0xe -> [ A,       D, E, F, G ]
  0xf -> [ A,          E, F, G ]
  n ->
    error (show ("segs",n))

encodeSegs :: SegOrder -> [Seg] -> Word8
encodeSegs order segs = sum [ 1 `shiftL` (segBit order) seg | seg <- segs ]

segBit :: SegOrder -> Seg -> Int
segBit (SegOrder order) seg = the [ n | (x,n) <- bitMap, x == seg]
  where
    bitMap = zip (reverse order) [0..]

the :: Show a => [a] -> a
the = \case
  [x] -> x
  xs -> error (show ("the",xs))

----------------------------------------------------------------------
-- program rom

progs :: [Word8]
progs = concat
  [ compile countdownForeverZ
  , compile countdownForeverC
  , compile fibForever
  , compile varProg0
  , erasedPage
  , erasedPage
  , compile (primes False)
  , erasedPage
  ]

compile :: [Op] -> [Word8]
compile prog = pad 0x0 256 (map Emu.encodeOp prog)
