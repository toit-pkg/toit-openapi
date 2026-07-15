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

  /widgets/{id}-get --raw/True --id/string -> http.Response:
    path := "/widgets/{id}"
    headers := http.Headers
    query-params := []
    cookie-params := []
    path = path.replace --all
        "{id}"
        (openapi-runtime.encode-path-param "id" id)
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null

  /** - $id:  */
  /widgets/{id}-get --id/string:
    /widgets/{id}-get --raw --id=id
    return null


