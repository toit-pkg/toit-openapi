import http
import net
import openapi-runtime

class Api extends openapi-runtime.ApiBase:
  items-api_/ItemsApi? := null

  constructor --api-client/openapi-runtime.ApiClient:
    super api-client


  constructor network/net.Client --authentication/openapi-runtime.Authentication?=null:
    client := openapi-runtime.ApiClient network
        --base-path=""
        --authentication=authentication
    super client

  items-api -> ItemsApi:
    if (not items-api_):
      items-api_ = ItemsApi api-client
    return items-api_


class ItemsApi:
  api-client_/openapi-runtime.ApiClient := ?

  constructor client/openapi-runtime.ApiClient:
    api-client_ = client

  ping --raw/True --x-trace-id/string -> http.Response:
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


