import core

class Pet:
  id/core.int
  name/core.string

  constructor --.id/core.int --.name/core.string:


  constructor.from-json data/core.Map:
    id = data["id"]
    name = data["name"]

  to-json -> core.Map:
    result := {"id": id, "name": name}
    return result


