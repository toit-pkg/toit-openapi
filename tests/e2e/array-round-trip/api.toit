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

  create-pets --raw/True body/List -> http.Response:
    path := "/pets/batch"
    headers := http.Headers
    query-params := []
    cookie-params := []
    headers.set "Content-Type" "application/json"
    payload := body.map: | it |
      it.to-json
    return api-client_.invoke-api --path=path
        --method="POST"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null
        --body=json.encode payload

  create-pets body-1/List -> List:
    response := create-pets --raw body-1
    decoded := json.decode response.body.read-all
    return decoded.map: | it |
      Pet.from-json it


