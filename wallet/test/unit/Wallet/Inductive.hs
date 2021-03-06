module Wallet.Inductive (
    -- * Wallet events
    WalletEvent(..)
  , walletEventIsRollback
    -- * Inductive wallets
  , Inductive(..)
  , uptoFirstRollback
  , inductiveInit
  ) where

import           Universum

import qualified Data.List as List
import qualified Data.Set as Set
import           Formatting (bprint, build, (%))
import qualified Formatting.Buildable
import           Pos.Core.Chrono
import           Serokell.Util (listJson)

import           UTxO.DSL
import           UTxO.Util

{-------------------------------------------------------------------------------
  Wallet events
-------------------------------------------------------------------------------}

-- | Wallet event
data WalletEvent h a =
    -- | Inform the wallet of a new block added to the blockchain
    ApplyBlock (Block h a)

    -- | Submit a new transaction to the wallet to be included in the blockchain
  | NewPending (Transaction h a)

    -- | Roll back the last block added to the blockchain
  | Rollback

walletEventIsRollback :: WalletEvent h a -> Bool
walletEventIsRollback Rollback = True
walletEventIsRollback _        = False

{-------------------------------------------------------------------------------
  Inductive wallets
-------------------------------------------------------------------------------}

-- | Inductive definition of a wallet
data Inductive h a = Inductive {
      -- | Bootstrap transaction
      inductiveBoot   :: Transaction h a

      -- | Addresses that belong to the wallet
    , inductiveOurs   :: Set a

      -- | Wallet events
    , inductiveEvents :: OldestFirst [] (WalletEvent h a)
    }

-- | The prefix of the 'Inductive' that doesn't include any rollbacks
uptoFirstRollback :: Inductive h a -> Inductive h a
uptoFirstRollback i@Inductive{..} = i {
      inductiveEvents = liftOldestFirst (takeWhile notRollback) inductiveEvents
    }
  where
    notRollback = not . walletEventIsRollback

inductiveInit :: forall h a. Inductive h a -> Inductive h a
inductiveInit i@Inductive{..} = i {
      inductiveEvents = liftOldestFirst List.init inductiveEvents
    }

{-------------------------------------------------------------------------------
  Pretty-printing
-------------------------------------------------------------------------------}

instance (Hash h a, Buildable a) => Buildable (OldestFirst [] (WalletEvent h a)) where
  build = bprint listJson . getOldestFirst

instance (Hash h a, Buildable a) => Buildable (WalletEvent h a) where
  build (ApplyBlock b) = bprint ("ApplyBlock " % build) b
  build (NewPending t) = bprint ("NewPending " % build) t
  build Rollback       = bprint "Rollback"

instance (Hash h a, Buildable a) => Buildable (Inductive h a) where
  build Inductive{..} = bprint
    ( "Inductive"
    % "{ boot: "   % build
    % ", ours:   " % listJson
    % ", events: " % build
    % "}"
    )
    inductiveBoot
    (Set.toList inductiveOurs)
    inductiveEvents
