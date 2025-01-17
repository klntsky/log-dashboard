module Generator.Data.Base
  ( CommonData (..)
  , Data (..)

  , dAction
  , dCommonData
  , dData
  , cdLogLevel
  , cdServerName
  , cdTime
  , cdUserId
  , cdRequestId

  , genLoginData
  , genLogoutData
  , genProductDataC
  , genCatalogData
  ) where

import Universum

import Control.Lens (makeLenses)
import Data.Time (UTCTime, getCurrentTime)
import Hedgehog.Gen (sample)

import Generator.Data.Catalog
  (CatalogDbReply, CatalogDbRequest, CatalogRequest(..), LinkedProductsDbReply,
  LinkedProductsDbRequest, ProductDbReply, ProductDbRequest, ProductRequest, genCatalogDbReply,
  genCatalogDbRequest, genLinkedProductsDbReply, genLinkedProductsDbRequest, genProductDbReply,
  genProductDbRequest, genProductRequest, pdrepStatus, prProductId)
import Generator.Data.Common
  (Level(..), RequestId, ServerName(..), Status(..), UserId, genRequestId, genUserId)
import Generator.Data.Login
  (LoginDbRequest, LoginReply, LoginRequest, LogoutDbRequest, LogoutReply, LogoutRequest(..),
  genLoginDbRequest, genLoginReply, genLoginRequest, genLogoutDbRequest, genLogoutReply,
  lreqPasswordHash)
import Generator.Data.Util (deriveToJSON)

data ActionType
  = LoginReq
  | LoginDbReq
  | LoginRep
  | LogoutReq
  | LogoutDbReq
  | LogoutRep

  | CatalogProductReq
  | CatalogProductDbReq
  | CatalogProductDbRep
  | CatalogLinkedProductsDbReq
  | CatalogLinkedProductsDbRep

  | CatalogReq
  | CatalogDbReq
  | CatalogDbRep
deriveToJSON ''ActionType

data CommonData = CommonData
  { _cdLogLevel :: Level
  , _cdServerName :: ServerName
  , _cdTime :: UTCTime
  , _cdUserId :: UserId
  , _cdRequestId :: RequestId
  }
makeLenses ''CommonData
deriveToJSON 'CommonData

data Data a = Data
  { _dAction :: ActionType
  , _dCommonData :: CommonData
  , _dData :: a
  }
makeLenses ''Data
deriveToJSON 'Data

genLoginData :: IO (Data LoginRequest, Data LoginDbRequest, Data LoginReply)
genLoginData = do
  userId <- sample genUserId
  requestId <- sample genRequestId
  loginRequest <- sample genLoginRequest
  let loginDbRequest = genLoginDbRequest userId $ loginRequest ^. lreqPasswordHash
  loginReply <- sample genLoginReply
  time <- getCurrentTime
  let commonData = CommonData
        { _cdLogLevel = Info
        , _cdServerName = Login
        , _cdTime = time
        , _cdUserId = userId
        , _cdRequestId = requestId
        }
  pure
    ( Data LoginReq commonData loginRequest
    , Data LoginDbReq commonData loginDbRequest
    , Data LoginRep commonData loginReply
    )

genLogoutData :: UserId -> IO (Data LogoutRequest, Data LogoutDbRequest, Data LogoutReply)
genLogoutData userId = do
  requestId <- sample genRequestId
  let logoutRequest = LogoutRequest
  let logoutDbRequest = genLogoutDbRequest userId
  logoutReply <- sample genLogoutReply
  time <- getCurrentTime
  let commonData = CommonData
        { _cdLogLevel = Info
        , _cdServerName = Login
        , _cdTime = time
        , _cdUserId = userId
        , _cdRequestId = requestId
        }
  pure
    ( Data LogoutReq commonData logoutRequest
    , Data LogoutDbReq commonData logoutDbRequest
    , Data LogoutRep commonData logoutReply
    )

genProductDataC
  :: UserId
  -> IO
     ( Data ProductRequest
     , Data ProductDbRequest
     , Data ProductDbReply
     , Maybe (Data LinkedProductsDbRequest)
     , Maybe (Data LinkedProductsDbReply)
     )
genProductDataC userId = do
  requestId <- sample genRequestId
  productRequest <- sample genProductRequest
  let pid = productRequest ^. prProductId
  let productDbRequest = genProductDbRequest pid
  productDbReply <- sample $ genProductDbReply pid
  time <- getCurrentTime
  let commonData = CommonData
        { _cdLogLevel = Info
        , _cdServerName = Catalog
        , _cdTime = time
        , _cdUserId = userId
        , _cdRequestId = requestId
        }
  case productDbReply ^. pdrepStatus of
    Invalid -> pure
      ( Data CatalogProductReq commonData productRequest
      , Data CatalogProductDbReq commonData productDbRequest
      , Data CatalogProductDbRep commonData productDbReply
      , Nothing
      , Nothing
      )
    Valid -> do
      let linkedProductsDbRequest = genLinkedProductsDbRequest pid
      linkedProductsDbReply <- sample genLinkedProductsDbReply
      pure
        ( Data CatalogProductReq commonData productRequest
        , Data CatalogProductDbReq commonData productDbRequest
        , Data CatalogProductDbRep commonData productDbReply
        , Just $ Data CatalogLinkedProductsDbReq commonData linkedProductsDbRequest
        , Just $ Data CatalogLinkedProductsDbRep commonData linkedProductsDbReply
        )

genCatalogData :: UserId -> IO (Data CatalogRequest, Data CatalogDbRequest, Data CatalogDbReply)
genCatalogData userId = do
  requestId <- sample genRequestId
  time <- getCurrentTime
  let commonData = CommonData
        { _cdLogLevel = Info
        , _cdServerName = Catalog
        , _cdTime = time
        , _cdUserId = userId
        , _cdRequestId = requestId
        }
      catalogRequest = CatalogRequest
      catalogDbRequest = genCatalogDbRequest
  catalogDbReply <- sample genCatalogDbReply
  pure
    ( Data CatalogReq commonData catalogRequest
    , Data CatalogDbReq commonData catalogDbRequest
    , Data CatalogDbRep commonData catalogDbReply
    )
