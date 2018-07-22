module JSONRPC2.Client where

import Prelude

import Control.Monad.Error.Class (throwError)
import Control.Monad.Reader (ReaderT(..), runReaderT)
import Data.Either (Either(..))
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.Newtype (unwrap, wrap)
import Effect (Effect)
import Effect.AVar (AVar)
import Effect.Aff (Aff, runAff_)
import Effect.Aff.AVar as AVar
import Effect.Exception (Error, error)
import JSONRPC2.Identifier (Identifier(..))
import JSONRPC2.Request (Request(..))
import JSONRPC2.Request as Request
import JSONRPC2.Response (Response)
import JSONRPC2.Response as Response
import Network.HTTP.Affjax (URL, post)
import Network.HTTP.Affjax.Request as AffRequest
import Network.HTTP.Affjax.Response as AffResponse

type Client a = ReaderT ClientEnv Aff a

type ClientEnv = { url :: URL, counterVar :: AVar RequestCounter }

type RequestCounter = Int

runClient
  :: forall a
   . URL
  -> RequestCounter
  -> (Either Error a -> Effect Unit)
  -> Client a
  -> Effect Unit
runClient url counter handler client = runAff_ handler $ do
  counterVar <- AVar.new counter
  runReaderT client {url, counterVar}

runClient'
  :: forall a
   . URL
  -> (Either Error a -> Effect Unit)
  -> Client a
  -> Effect Unit
runClient' url = runClient url 0

-- TODO: better errors?
requestImpl :: String -> Maybe Request.Params -> Client Response
requestImpl method params = ReaderT \{url, counterVar} -> do
  counter <- AVar.take counterVar
  AVar.put (counter + 1) counterVar
  let req = Request { id: Just $ IdNum $ toNumber counter, method, params }
      reqJson = AffRequest.json $ unwrap $ Request.toJson req
  {status, headers, response} <- post AffResponse.json url reqJson
  -- TODO: deal with headers and status first...
  case Response.fromJson $ wrap response of
       Right resp -> pure resp
       Left responseFormatError -> throwError $ error $ show responseFormatError
