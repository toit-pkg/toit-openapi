import core

class Credentials:
  username/string := ?
  password/string := ?

  constructor.from-json data/Map:
    username = data["username"]
    password = data["password"]

  to-json -> Map:
    return {"username": username, "password": password}


