import http
import net
import openapi-runtime
import encoding.json

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

  /** Variant of $(create-item body) that returns the raw HTTP response. */
  create-item --raw/True body/Map -> http.Response:
    path := "/items"
    headers := http.Headers
    query-params := []
    cookie-params := []
    return api-client_.invoke-api --path=path
        --method="POST"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type="application/json"
        --body=json.encode body

  create-item body/Map:
    create-item --raw body
    return null


