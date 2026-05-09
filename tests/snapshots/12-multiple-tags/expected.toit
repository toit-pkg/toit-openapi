import http show Response Headers
import net show Client
import openapi-runtime show ApiClient Authentication

class Api:
  api-client_/ApiClient? := ?
  pets-api_/PetsApi? := null
  users-api_/UsersApi? := null

  constructor --api-client/ApiClient:
    api-client_ = api-client


  constructor network/Client:
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

  users-api -> UsersApi:
    if (not users-api_):
      users-api_ = UsersApi api-client_
    return users-api_


class PetsApi:
  authentication/Authentication? := null
  api-client_/ApiClient := ?

  constructor client/ApiClient --auth/Authentication?=null:
    api-client_ = client
    authentication = auth

  list-pets --raw/True -> Response:
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

  list-pets:
    list-pets --raw
    return null


class UsersApi:
  authentication/Authentication? := null
  api-client_/ApiClient := ?

  constructor client/ApiClient --auth/Authentication?=null:
    api-client_ = client
    authentication = auth

  list-users --raw/True -> Response:
    path := "/users"
    headers := http.Headers
    query-params := []
    cookie-params := []
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null

  list-users:
    list-users --raw
    return null


