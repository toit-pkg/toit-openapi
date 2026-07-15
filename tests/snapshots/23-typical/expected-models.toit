import core

class Owner:
  name/string := ?

  constructor.from-json data/Map:
    name = data["name"]

  to-json -> Map:
    return {"name": name}


class Pet:
  id/int := ?
  name/string := ?
  tag/string? := null
  owner/Owner? := null

  constructor.from-json data/Map:
    id = data["id"]
    name = data["name"]
    tag = data.get "tag"
    owner = ((data.get "owner") == null) ? null : (Owner.from-json (data.get "owner"))

  to-json -> Map:
    return {"id": id, "name": name, "tag": tag, "owner": (owner == null) ? null : owner.to-json}


