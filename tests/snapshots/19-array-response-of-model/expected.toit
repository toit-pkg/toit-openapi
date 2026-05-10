import http
import net
import openapi-runtime
import .models
import encoding.json

class Api:
  api-client_/openapi-runtime.ApiClient? := ?
  pets-api_/PetsApi? := null

  constructor --api-client/openapi-runtime.ApiClient:
    api-client_ = api-client


  constructor network/net.Client:
    api-client_ = openapi-runtime.ApiClient network --base-path=""

  close:
    if (not api-client_):
      return
    api-client_.close
    api-client_ = null

  pets-api -> PetsApi:
    if (not pets-api_):
      pets-api_ = PetsApi api-client_
    return pets-api_


class PetsApi:
  authentication/openapi-runtime.Authentication? := null
  api-client_/openapi-runtime.ApiClient := ?

  constructor client/openapi-runtime.ApiClient --auth/openapi-runtime.Authentication?=null:
    api-client_ = client
    authentication = auth

  list-pets --raw/True -> http.Response:
    path := "/pets"
    headers := http.Headers
    query-params := []
    cookie-params := []
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null

  list-pets -> List:
    response := list-pets --raw
    decoded := json.decode response.body.read-all
    return decoded.map: | it |
      Pet.from-json it


