import core

class Owner:
  name/string

  constructor --.name/string:


  constructor.from-json data/Map:
    name = data["name"]

  to-json -> Map:
    result := {"name": name}
    return result


class Pet:
  id/int
  name/string
  tag/string?
  owner/Owner?

  constructor --.id/int --.name/string --.tag/string?=null --.owner/Owner?=null:


  constructor.from-json data/Map:
    id = data["id"]
    name = data["name"]
    tag = data.get "tag"
    owner = ((data.get "owner") == null) ? null : (Owner.from-json (data.get "owner"))

  to-json -> Map:
    result := {"id": id, "name": name}
    if (tag != null):
      result["tag"] = tag
    if (owner != null):
      result["owner"] = (owner == null) ? null : owner.to-json
    return result


