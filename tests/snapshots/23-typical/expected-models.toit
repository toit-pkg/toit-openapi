import core

class Owner:
  name/core.string

  constructor --.name/core.string:


  constructor.from-json data/core.Map:
    name = data["name"]

  to-json -> core.Map:
    result := {"name": name}
    return result


class Pet:
  id/core.int
  name/core.string
  tag/core.string?
  owner/Owner?

  constructor --.id/core.int --.name/core.string --.tag/core.string?=null --.owner/Owner?=null:


  constructor.from-json data/core.Map:
    id = data["id"]
    name = data["name"]
    tag = data.get "tag"
    owner = ((data.get "owner") == null) ? null : (Owner.from-json (data.get "owner"))

  to-json -> core.Map:
    result := {"id": id, "name": name}
    if (tag != null):
      result["tag"] = tag
    if (owner != null):
      result["owner"] = (owner == null) ? null : owner.to-json
    return result


