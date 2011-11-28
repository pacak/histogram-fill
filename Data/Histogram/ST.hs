{-# LANGUAGE BangPatterns #-}
-- |
-- Module     : Data.Histogram.ST
-- Copyright  : Copyright (c) 2009, Alexey Khudyakov <alexey.skladnoy@gmail.com>
-- License    : BSD3
-- Maintainer : Alexey Khudyakov <alexey.skladnoy@gmail.com>
-- Stability  : experimental
-- 
-- Mutable histograms.

module Data.Histogram.ST ( -- * Mutable histograms
                           MHistogram
                         , newMHistogram
                         , fillOne
                         , fillOneW
                         , fillMonoid
                         -- , fillMonoidAccum
                         , unsafeFreezeHist
                         , freezeHist
                         ) where

import Control.Monad.Primitive

import Data.Monoid
-- import Data.Monoid.Statistics
import qualified Data.Vector.Unboxed as U
import qualified Data.Vector.Unboxed.Mutable as MU
import qualified Data.Vector.Generic as G

import Data.Histogram

----------------------------------------------------------------
-- Mutable histograms
----------------------------------------------------------------

-- | Mutable histogram.
data MHistogram s bin a = MHistogram !bin !(MU.MVector s a) !(MU.MVector s a)

-- | Create new mutable histogram. All bins are set to zero element as
--   passed to function.
newMHistogram :: (PrimMonad m, Bin bin, U.Unbox a) => a -> bin -> m (MHistogram (PrimState m) bin a)
newMHistogram zero bin = do
  uo <- MU.replicate 2 zero
  a  <- MU.replicate (nBins bin) zero
  return $ MHistogram bin uo a
{-# INLINE newMHistogram #-}

-- | Put one value into histogram
fillOne :: (PrimMonad m, Num a, U.Unbox a, Bin bin) => MHistogram (PrimState m) bin a -> BinValue bin -> m ()
fillOne (MHistogram bin uo arr) !x
    | i < 0              = MU.unsafeWrite uo  0 . (+1)  =<< MU.unsafeRead uo 0
    | i >= MU.length arr = MU.unsafeWrite uo  1 . (+1)  =<< MU.unsafeRead uo 1
    | otherwise          = MU.unsafeWrite arr i . (+1)  =<< MU.unsafeRead arr i
    where
      i = toIndex bin x
{-# INLINE fillOne #-}

-- | Put one value into histogram with weight
fillOneW :: (PrimMonad m, Num a, U.Unbox a, Bin bin) => MHistogram (PrimState m) bin a -> (BinValue bin, a) -> m ()
fillOneW (MHistogram bin uo arr) (!x,!w)
    | i < 0              = MU.unsafeWrite uo  0 . (+w)  =<< MU.unsafeRead uo 0
    | i >= MU.length arr = MU.unsafeWrite uo  1 . (+w)  =<< MU.unsafeRead uo 1
    | otherwise          = MU.unsafeWrite arr i . (+w)  =<< MU.unsafeRead arr i
    where
      i = toIndex bin x
{-# INLINE fillOneW #-} 

-- | Put one monoidal element
fillMonoid :: (PrimMonad m, Monoid a, U.Unbox a, Bin bin) => MHistogram (PrimState m) bin a -> (BinValue bin, a) -> m ()
fillMonoid (MHistogram bin uo arr) (!x,!m)
    | i < 0              = MU.unsafeWrite uo  0 . flip mappend m =<< MU.unsafeRead uo  0
    | i >= MU.length arr = MU.unsafeWrite uo  1 . flip mappend m =<< MU.unsafeRead uo  1
    | otherwise          = MU.unsafeWrite arr i . flip mappend m =<< MU.unsafeRead arr i
    where 
      i = toIndex bin x
{-# INLINE fillMonoid #-}

-- -- | Add one element to monoidal accumulator
-- fillMonoidAccum :: (PrimMonad m, StatMonoid val a, U.Unbox val, Bin bin) 
--                 => MHistogram (PrimState m) bin val -> (BinValue bin, a) -> m ()
-- fillMonoidAccum (MHistogram bin uo arr) !(x,a)
--     | i < 0              = MU.unsafeWrite uo  0 . pappend a =<< MU.unsafeRead uo  0
--     | i >= MU.length arr = MU.unsafeWrite uo  1 . pappend a =<< MU.unsafeRead uo  1
--     | otherwise          = MU.unsafeWrite arr i . pappend a =<< MU.unsafeRead arr i
--     where 
--       i = toIndex bin x
-- {-# INLINE fillMonoidAccum #-}
    
-- | Create immutable histogram from mutable one. This operation is
-- unsafe! Accumulator mustn't be used after that
unsafeFreezeHist :: (PrimMonad m, U.Unbox a, Bin bin) => MHistogram (PrimState m) bin a -> m (Histogram bin a)
unsafeFreezeHist (MHistogram bin uo arr) = do
  u <- MU.unsafeRead uo 0
  o <- MU.unsafeRead uo 1
  a <- G.unsafeFreeze arr
  return $ histogramUO bin (Just (u,o)) a
{-# INLINE unsafeFreezeHist #-}  

-- | Create immutable histogram from mutable one.
freezeHist :: (PrimMonad m, U.Unbox a, Bin bin) => MHistogram (PrimState m) bin a -> m (Histogram bin a)
freezeHist (MHistogram bin uo arr) = do
  u <- MU.unsafeRead uo 0
  o <- MU.unsafeRead uo 1
  -- Copy array
  tmp  <- MU.new (MU.length arr)
  MU.copy tmp arr
  a    <- G.unsafeFreeze tmp
  return $ histogramUO bin (Just (u,o)) a
{-# INLINE freezeHist #-}

