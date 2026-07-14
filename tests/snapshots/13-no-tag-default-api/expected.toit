import http
import net
import openapi-runtime

class Api:
  api-client_/openapi-runtime.ApiClient? := ?
  default-api_/DefaultApi? := null

  constructor --api-client/openapi-runtime.ApiClient:
    api-client_ = api-client


  constructor network/net.Client --authentication/openapi-runtime.Authentication?=null:
    api-client_ = openapi-runtime.ApiClient network
        --base-path=""
        --authentication=authentication

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
  authentication/openapi-runtime.Authentication? := null
  api-client_/openapi-runtime.ApiClient := ?

  constructor client/openapi-runtime.ApiClient --auth/openapi-runtime.Authentication?=null:
    api-client_ = client
    authentication = auth

  ping --raw/True -> http.Response:
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
        --authentication=authentication

  ping:
    ping --raw
    return null


