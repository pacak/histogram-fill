-- | Helper function for defining Read instances for bin data types.
module Data.Histogram.Bin.Read 
  ( ws
  , eol
  , value
  , maybeValue
  , keyword
  ) where

import Text.Read
import Text.ParserCombinators.ReadP    (ReadP, many, satisfy, char, string)

-- | Whitespaces
ws :: ReadP String
ws = many $ satisfy (`elem` " \t")

-- | End of line
eol :: ReadP Char
eol = char '\n'

-- | Equal sign
eq :: ReadP ()
eq = ws >> char '=' >> return ()

-- | Key value pair
value :: Read a => String -> ReadPrec a
value str = do lift $ key str >> eq
               getVal

-- | Return optional value
maybeValue :: Read a => String -> ReadPrec (Maybe a)
maybeValue str = do lift (key str >> eq)
                    lift (ws >> eol >> return Nothing) <++ (Just `fmap` getVal)

-- | Keyword
keyword :: String -> ReadPrec ()
keyword str = lift $ key str >> ws >> eol >> return ()


key :: String -> ReadP String
key s = char '#' >> ws >> string s 

getVal :: Read a => ReadPrec a
getVal = do x <- readPrec
            lift eol >> return x
