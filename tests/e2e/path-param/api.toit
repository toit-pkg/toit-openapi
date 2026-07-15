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

  /** Variant of $(get-item --item-id) that returns the raw HTTP response. */
  get-item --raw/True --item-id/string -> http.Response:
    path := "/items/{itemId}"
    headers := http.Headers
    query-params := []
    cookie-params := []
    path = path.replace --all
        "{itemId}"
        (openapi-runtime.encode-path-param "itemId" item-id)
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null

  get-item --item-id/string:
    get-item --raw --item-id=item-id
    return null


