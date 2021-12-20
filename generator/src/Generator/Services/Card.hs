module Generator.Services.Card
  ( CardAction (..)
  , MonadCard (..)
  , HasCard (..)
  ) where

import Universum

import Control.Concurrent.STM.TQueue (TQueue)
import Data.Aeson (encode)

import Generator.Data.Base (genCatalogAction, genCatalogList)
import Generator.Data.Common (UserId(..))
import Generator.Kafka (MonadKafka(..))

data CardAction = CardActionE UserId | CardVisit UserId

class Monad m => MonadCard m where
  cardVisit :: UserId -> m ()
  cardActionE :: UserId -> m ()

class HasCard env where
  getCardQueue :: env -> TQueue CardAction

instance (MonadIO m, Monad m, MonadKafka m) => MonadCard m where
  cardVisit userId = do
    (req, reqDb, rep) <- liftIO $ genCatalogList userId
    logKafka $ decodeUtf8 $ encode req
    logKafka $ decodeUtf8 $ encode reqDb
    logKafka $ decodeUtf8 $ encode rep
  cardActionE userId = do
    (req, reqDb, rep) <- liftIO $ genCatalogAction userId
    logKafka $ decodeUtf8 $ encode req
    logKafka $ decodeUtf8 $ encode reqDb
    logKafka $ decodeUtf8 $ encode rep
