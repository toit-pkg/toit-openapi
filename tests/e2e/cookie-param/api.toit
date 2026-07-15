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

  ping --raw/True --session/string --csrf/string -> http.Response:
    path := "/ping"
    headers := http.Headers
    query-params := []
    cookie-params := []
    cookie-params.add "session=$session"
    cookie-params.add "csrf=$csrf"
    headers.set "Cookie" (cookie-params.join "; ")
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null

  /**
  - $session: 
  - $csrf: 
  */
  ping --session/string --csrf/string:
    ping --raw
        --session=session
        --csrf=csrf
    return null


