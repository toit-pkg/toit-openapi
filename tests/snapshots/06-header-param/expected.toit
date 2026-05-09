import http show Response Headers
import net show Client
import openapi-runtime show ApiClient Authentication encode-header-param

class Api:
  api-client_/ApiClient? := ?
  items-api_/ItemsApi? := null

  constructor --api-client/ApiClient:
    api-client_ = api-client


  constructor network/Client:
    api-client_ = openapi-runtime.ApiClient network --base-path=""

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
  authentication/Authentication? := null
  api-client_/ApiClient := ?

  constructor client/ApiClient --auth/Authentication?=null:
    api-client_ = client
    authentication = auth

  ping --raw/True --x-trace-id/string -> Response:
    path := "/ping"
    headers := http.Headers
    query-params := []
    cookie-params := []
    openapi-runtime.encode-header-param headers "X-Trace-Id" x-trace-id
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null

  /** - $x-trace-id:  */
  ping --x-trace-id/string:
    ping --raw --x-trace-id=x-trace-id
    return null


