///|
fn json_array_string(items : Array[Json]) -> String {
  "[\{items.map(json_value_string).join(",")}]"
}

///|
fn json_value_string(value : Json) -> String {
  match value {
    Null => "null"
    True => "true"
    False => "false"
    Number(value, ..) => value.to_string()
    String(value) => value.json_string()
    Array(items) => json_array_string(items)
    Object(object) => json_object_string(object)
  }
}

///|
fn json_object_string(object : Map[String, Json]) -> String {
  let keys : Array[String] = []
  for key in object.keys() {
    keys.push(key)
  }
  keys.sort()
  let fields : Array[String] = []
  for key in keys {
    match object.get(key) {
      Some(value) =>
        fields.push("\{key.json_string()}:\{json_value_string(value)}")
      None => ()
    }
  }
  "{\{fields.join(",")}}"
}

///|
fn String::json_string(self : String) -> String {
  "\"" +
  self
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\t", new="\\t") +
  "\""
}
