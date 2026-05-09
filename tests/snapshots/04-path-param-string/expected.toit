import http show Response Headers
import net show Client
import openapi-runtime show ApiClient Authentication

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

  get-item --raw/True --item-id/string -> Response:
    path := "/items/{itemId}"
    headers := http.Headers
    query-params := []
    cookie-params := []
    path = path.replace --all
        "{itemId}"
        "$item-id"
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null

  /** - $item-id:  */
  get-item --item-id/string:
    get-item --raw --item-id=item-id
    return null


