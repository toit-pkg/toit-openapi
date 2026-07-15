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

  search --raw/True --q/string --limit/int?=null -> http.Response:
    path := "/search"
    headers := http.Headers
    query-params := []
    cookie-params := []
    query-params.add-all (openapi-runtime.encode-query-param "q" q)
    if (limit != null):
      query-params.add-all (openapi-runtime.encode-query-param "limit" limit)
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null

  /**
  - $q: 
  - $limit: 
  */
  search --q/string --limit/int?=null:
    search --raw
        --q=q
        --limit=limit
    return null


