import http
import net
import openapi-runtime

class Api:
  api-client_/openapi-runtime.ApiClient? := ?
  items-api_/ItemsApi? := null

  constructor --api-client/openapi-runtime.ApiClient:
    api-client_ = api-client


  constructor network/net.Client:
    api-client_ = openapi-runtime.ApiClient network --base-path="/v3"

  close:
    if (not api-client_):
      return
    api-client_.close
    api-client_ = null

  items-api -> ItemsApi:
    if (not items-api_):
      items-api_ = ItemsApi api-client_
    return items-api_


class ItemsApi:
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

  ping:
    ping --raw
    return null


