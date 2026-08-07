import core

class Category:
  id/int?
  name/string?

  constructor --.id/int?=null --.name/string?=null:


  constructor.from-json data/Map:
    id = data.get "id"
    name = data.get "name"

  to-json -> Map:
    result := {:}
    if (id != null):
      result["id"] = id
    if (name != null):
      result["name"] = name
    return result


class Tag:
  name/string?

  constructor --.name/string?=null:


  constructor.from-json data/Map:
    name = data.get "name"

  to-json -> Map:
    result := {:}
    if (name != null):
      result["name"] = name
    return result


class Pet:
  id/int
  name/string
  category/Category?
  tags/List?

  constructor --.id/int --.name/string --.category/Category?=null --.tags/List?=null:


  constructor.from-json data/Map:
    id = data["id"]
    name = data["name"]
    category = ((data.get "category") == null) ? null : (Category.from-json (data.get "category"))
    tags = ((data.get "tags") == null) ? null : ((data.get "tags").map: | it |
      Tag.from-json it)

  to-json -> Map:
    result := {"id": id, "name": name}
    if (category != null):
      result["category"] = (category == null) ? null : category.to-json
    if (tags != null):
      result["tags"] = (tags == null) ? null : (tags.map: | it |
        it.to-json)
    return result


