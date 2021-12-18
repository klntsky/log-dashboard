module Generator.Runner
 ( runner
 ) where

import Universum

import Control.Concurrent (threadDelay)
import Control.Concurrent.Async (async, wait)
import Control.Concurrent.STM.TQueue (tryReadTQueue, writeTQueue)
import Control.Monad.IO.Unlift (UnliftIO(..), askUnliftIO)
import System.Random (randomRIO)

import Generator.Services.Card (CardAction(..), HasCard(..), MonadCard(..))
import Generator.Services.Catalog (CatalogAction(..), HasCatalog(..), MonadCatalog(..))
import Generator.Services.Login (HasLogin(..), MonadLogin(..))
import Generator.Setup (GeneratorWorkMode)

loginAction :: GeneratorWorkMode m => m ()
loginAction = forever $ do
  liftIO $ threadDelay 1000000
  mUserId <- login
  case mUserId of
    Just userId -> do
      catalogQueue <- getCatalogQueue <$> ask
      atomically $ writeTQueue catalogQueue $ CatalogVisit userId
    _ -> pure ()

logoutAction :: GeneratorWorkMode m => m ()
logoutAction = forever $ do
  liftIO $ threadDelay 1000000
  logoutQueue <- getLogoutQueue <$> ask
  mUserId <- atomically $ tryReadTQueue logoutQueue
  case mUserId of
    Just userId -> logout userId
    _ -> pure ()

pageAction :: GeneratorWorkMode m => m ()
pageAction = forever $ do
  liftIO $ threadDelay 1000000
  rn <- liftIO $ randomRIO (1 :: Int, 10)
  catalogQueue <- getCatalogQueue <$> ask
  logoutQueue <- getLogoutQueue <$> ask
  cardQueue <- getCardQueue <$> ask
  mAction <- atomically $ tryReadTQueue catalogQueue
  case mAction of
    Just (CatalogVisit userId) -> do
      catalogVisit userId
      if rn == 1
      then atomically $ writeTQueue logoutQueue userId
      else if rn < 4
        then atomically $ writeTQueue catalogQueue $ ProductVisit userId
        else atomically $ writeTQueue cardQueue $ CardVisit userId
    Just (ProductVisit userId) -> do
      productVisit userId
      if rn == 1
      then atomically $ writeTQueue logoutQueue userId
      else if rn < 4
           then atomically $ writeTQueue catalogQueue $ CatalogVisit userId
           else if rn < 7
             then atomically $ writeTQueue catalogQueue $ ProductVisit userId
             else if rn < 7
               then atomically $ writeTQueue cardQueue $ CardVisit userId
               else atomically $ writeTQueue cardQueue $ CardActionE userId
    _ -> pure ()

catalogAction :: GeneratorWorkMode m => m ()
catalogAction = forever $ do
  liftIO $ threadDelay 1000000
  rn <- liftIO $ randomRIO (1 :: Int, 10)
  catalogQueue <- getCatalogQueue <$> ask
  logoutQueue <- getLogoutQueue <$> ask
  cardQueue <- getCardQueue <$> ask
  mAction <- atomically $ tryReadTQueue cardQueue
  case mAction of
    Just (CardActionE userId) -> do
      cardActionE userId
      pure ()
    Just (CardVisit userId) -> do
      cardVisit userId
      if rn == 1
      then atomically $ writeTQueue logoutQueue userId
      else if rn < 4
           then atomically $ writeTQueue catalogQueue $ CatalogVisit userId
           else atomically $ writeTQueue catalogQueue $ ProductVisit userId
    _ -> pure ()

runner :: GeneratorWorkMode m => m ()
runner = do
  UnliftIO unlift <- askUnliftIO
  a1 <- liftIO $ async $ unlift loginAction
  _ <- liftIO $ async $ unlift pageAction
  _ <- liftIO $ async $ unlift logoutAction
  _ <- liftIO $ async $ unlift catalogAction
  liftIO $ wait a1
