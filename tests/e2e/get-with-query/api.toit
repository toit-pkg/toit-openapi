import http
import net
import openapi-runtime

class Api:
  api-client_/openapi-runtime.ApiClient? := ?
  items-api_/ItemsApi? := null

  constructor --api-client/openapi-runtime.ApiClient:
    api-client_ = api-client


  constructor network/net.Client --authentication/openapi-runtime.Authentication?=null:
    api-client_ = openapi-runtime.ApiClient network
        --base-path=""
        --authentication=authentication

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
        --authentication=authentication

  /**
  - $q: 
  - $limit: 
  */
  search --q/string --limit/int?=null:
    search --raw
        --q=q
        --limit=limit
    return null


