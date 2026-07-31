import core

class Pet:
  id/int
  name/string

  constructor --.id/int --.name/string:


  constructor.from-json data/Map:
    id = data["id"]
    name = data["name"]

  to-json -> Map:
    return {"id": id, "name": name}


