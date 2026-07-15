import http
import net
import openapi-runtime

class Api extends openapi-runtime.ApiBase:
  default-api_/DefaultApi? := null

  constructor --api-client/openapi-runtime.ApiClient:
    super api-client


  constructor network/net.Client --authentication/openapi-runtime.Authentication?=null:
    client := openapi-runtime.ApiClient network
        --base-path=""
        --authentication=authentication
    super client

  default-api -> DefaultApi:
    if (not default-api_):
      default-api_ = DefaultApi api-client
    return default-api_


class DefaultApi:
  api-client_/openapi-runtime.ApiClient := ?

  constructor client/openapi-runtime.ApiClient:
    api-client_ = client

  /** Variant of $(ping) that returns the raw HTTP response. */
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


