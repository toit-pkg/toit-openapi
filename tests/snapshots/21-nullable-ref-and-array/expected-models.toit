import core

class Category:
  id/int? := null
  name/string? := null

  constructor.from-json data/Map:
    id = data.get "id"
    name = data.get "name"

  to-json -> Map:
    return {"id": id, "name": name}


class Tag:
  name/string? := null

  constructor.from-json data/Map:
    name = data.get "name"

  to-json -> Map:
    return {"name": name}


class Pet:
  id/int := ?
  name/string := ?
  category/Category? := null
  tags/List? := null

  constructor.from-json data/Map:
    id = data["id"]
    name = data["name"]
    category = ((data.get "category") == null) ? null : (Category.from-json (data.get "category"))
    tags = ((data.get "tags") == null) ? null : ((data.get "tags").map: | it |
      Tag.from-json it)

  to-json -> Map:
    return {"id": id, "name": name, "category": (category == null) ? null : category.to-json, "tags": (tags == null) ? null : (tags.map: | it |
      it.to-json)}


