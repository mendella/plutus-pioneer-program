{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE DeriveAnyClass        #-}
{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}

module Week06.Oracle.Test where

import           Control.Monad              hiding (fmap)
import           Control.Monad.Freer.Extras as Extras
import           Data.Monoid                (Last (..))
import           Data.Text                  (Text)
import           Plutus.Contract            as Contract hiding (when)
import           Plutus.Trace.Emulator      as Emulator
import           PlutusTx.Prelude           hiding (Semigroup(..), unless)
import           Wallet.Emulator.Wallet

import Week06.Oracle.Core

test :: IO ()
test = runEmulatorTraceIO myTrace

checkOracle :: Oracle -> Contract () BlockchainActions Text a
checkOracle oracle = do
    m <- findOracle oracle
    case m of
        Nothing        -> return ()
        Just (_, _, x) -> Contract.logInfo $ "Oracle value: " ++ show x
    Contract.waitNSlots 1 >> checkOracle oracle

myTrace :: EmulatorTrace ()
myTrace = do
    h <- activateContractWallet (Wallet 1) $ runOracle 1000000
    void $ Emulator.waitNSlots 1
    oracle <- getOracle h
    void $ activateContractWallet (Wallet 2) $ checkOracle oracle
    callEndpoint @"update" h 42
    void $ Emulator.waitNSlots 3
    callEndpoint @"update" h 666
    void $ Emulator.waitNSlots 10

  where
    getOracle :: ContractHandle (Last Oracle) OracleSchema Text -> EmulatorTrace Oracle
    getOracle h = do
        l <- observableState h
        case l of
            Last Nothing       -> Emulator.waitNSlots 1 >> getOracle h
            Last (Just oracle) -> Extras.logInfo (show oracle) >> return oracle