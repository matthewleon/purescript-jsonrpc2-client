module JSONRPC2.Client where

import Prelude

import Control.Monad.Aff (Aff, runAff_)
import Control.Monad.Aff.AVar (AVAR, AVar, makeVar, putVar, takeVar)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Exception (Error, error)
import Control.Monad.Error.Class (throwError)
import Control.Monad.Reader (ReaderT(..), runReaderT)
import Data.Either (Either(..))
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import JSONRPC2.Identifier (Identifier(..))
import JSONRPC2.Request as Request
import JSONRPC2.Response (Response)
import JSONRPC2.Response as Response
import Network.HTTP.Affjax (AJAX, URL, post)

type Client eff a = ReaderT ClientEnv (Aff (ClientEffects eff)) a

type ClientEffects eff = (avar :: AVAR, ajax :: AJAX | eff)

type ClientEnv = { url :: URL, counterVar :: AVar RequestCounter }

type RequestCounter = Int

runClient
  :: forall a eff
   . URL
  -> RequestCounter
  -> (Either Error a -> Eff (ClientEffects eff) Unit)
  -> Client eff a
  -> Eff (ClientEffects eff) Unit
runClient url counter handler client = runAff_ handler do
  counterVar <- makeVar counter
  runReaderT client {url, counterVar}

runClient'
  :: forall a eff
   . URL
  -> (Either Error a -> Eff (ClientEffects eff) Unit)
  -> Client eff a
  -> Eff (ClientEffects eff) Unit
runClient' url = runClient url 0

-- TODO: better errors?
requestImpl :: forall eff a. String -> Maybe Request.Params -> Client eff Response
requestImpl method params = ReaderT \{url, counterVar} -> do
  counter <- takeVar counterVar
  putVar (counter + 1) counterVar
  let req = { id: Just $ IdNum $ toNumber counter, method, params }
      reqJson = Request.toJson req
  {status, headers, response} <- post url reqJson
  -- TODO: deal with headers and status first...
  case Response.fromJson response of
       Right resp -> pure resp
       Left responseFormatError -> throwError $ error $ show responseFormatError
