import http show Response Headers
import net show Client
import openapi-runtime show ApiClient Authentication

class Api:
  api-client_/ApiClient? := ?
  default-api_/DefaultApi? := null

  constructor --api-client/ApiClient:
    api-client_ = api-client


  constructor network/Client:
    api-client_ = openapi-runtime.ApiClient network --base-path=""

  close:
    if (not api-client_):
      return
    api-client_.close
    api-client_ = null

  default-api -> DefaultApi:
    if (not default-api_):
      default-api_ = DefaultApi api-client_
    return default-api_


class DefaultApi:
  authentication/Authentication? := null
  api-client_/ApiClient := ?

  constructor client/ApiClient --auth/Authentication?=null:
    api-client_ = client
    authentication = auth

  ping --raw/True -> Response:
    path := "/ping"
    headers := http.Headers
    query-params := []
    cookie-params := []
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null

  ping:
    ping --raw
    return null


