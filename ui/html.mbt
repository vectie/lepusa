///|
pub struct Attr {
  name : String
  value : String
} derive(Debug, Eq)

///|
pub fn Attr::new(name : String, value : String) -> Attr {
  { name, value }
}

///|
pub fn Attr::name(self : Attr) -> String {
  self.name
}

///|
pub fn Attr::value(self : Attr) -> String {
  self.value
}

///|
pub fn Attr::render(self : Attr) -> String {
  if self.name == "" {
    ""
  } else {
    "\{self.name}=\"\{escape_attribute(self.value)}\""
  }
}

///|
pub fn raw(content : String) -> @lepusa.Html {
  @lepusa.Html::text(content)
}

///|
pub fn text(content : String) -> @lepusa.Html {
  raw(escape_text(content))
}

///|
pub fn concat(children : Array[@lepusa.Html]) -> @lepusa.Html {
  raw(children.map(fn(child) { child.content() }).join(""))
}

///|
pub fn attr(name : String, value : String) -> Attr {
  Attr::new(name, value)
}

///|
pub fn id(value : String) -> Attr {
  attr("id", value)
}

///|
pub fn class_name(value : String) -> Attr {
  attr("class", value)
}

///|
pub fn style(value : String) -> Attr {
  attr("style", value)
}

///|
pub fn data(name : String, value : String) -> Attr {
  attr("data-\{name}", value)
}

///|
pub fn aria(name : String, value : String) -> Attr {
  attr("aria-\{name}", value)
}

///|
pub fn on_click(route : String, payload? : String = "{}") -> Attr {
  attr(
    "onclick",
    "window.lepusa&&window.lepusa.invoke(\{js_string(route)},\{payload})",
  )
}

///|
pub fn element(
  tag : String,
  children : Array[@lepusa.Html],
  attrs? : Array[Attr] = [],
) -> @lepusa.Html {
  let rendered_attrs = attrs
    .map(fn(item) { item.render() })
    .filter(fn(item) { item != "" })
    .join(" ")
  let open_tag = if rendered_attrs == "" {
    "<\{tag}>"
  } else {
    "<\{tag} \{rendered_attrs}>"
  }
  raw("\{open_tag}\{concat(children).content()}</\{tag}>")
}

///|
pub fn void_element(tag : String, attrs? : Array[Attr] = []) -> @lepusa.Html {
  let rendered_attrs = attrs
    .map(fn(item) { item.render() })
    .filter(fn(item) { item != "" })
    .join(" ")
  if rendered_attrs == "" {
    raw("<\{tag}>")
  } else {
    raw("<\{tag} \{rendered_attrs}>")
  }
}

///|
pub fn div(
  children : Array[@lepusa.Html],
  attrs? : Array[Attr] = [],
) -> @lepusa.Html {
  element("div", children, attrs~)
}

///|
pub fn span(
  children : Array[@lepusa.Html],
  attrs? : Array[Attr] = [],
) -> @lepusa.Html {
  element("span", children, attrs~)
}

///|
pub fn main_(
  children : Array[@lepusa.Html],
  attrs? : Array[Attr] = [],
) -> @lepusa.Html {
  element("main", children, attrs~)
}

///|
pub fn section(
  children : Array[@lepusa.Html],
  attrs? : Array[Attr] = [],
) -> @lepusa.Html {
  element("section", children, attrs~)
}

///|
pub fn h1(
  children : Array[@lepusa.Html],
  attrs? : Array[Attr] = [],
) -> @lepusa.Html {
  element("h1", children, attrs~)
}

///|
pub fn h2(
  children : Array[@lepusa.Html],
  attrs? : Array[Attr] = [],
) -> @lepusa.Html {
  element("h2", children, attrs~)
}

///|
pub fn p(
  children : Array[@lepusa.Html],
  attrs? : Array[Attr] = [],
) -> @lepusa.Html {
  element("p", children, attrs~)
}

///|
pub fn button(label : String, attrs? : Array[Attr] = []) -> @lepusa.Html {
  element("button", [text(label)], attrs~)
}

///|
pub fn input(attrs? : Array[Attr] = []) -> @lepusa.Html {
  void_element("input", attrs~)
}

///|
pub fn script(source : String) -> @lepusa.Html {
  element("script", [raw(source)])
}

///|
pub fn listen(event_name : String, body : String) -> @lepusa.Html {
  script(
    [
      "(() => {",
      "  const api = window.lepusa;",
      "  if (!api || typeof api.listen !== \"function\") { return; }",
      "  api.listen(\{js_string(event_name)}, (payload, event) => {",
      body,
      "  });",
      "})();",
    ].join("\n"),
  )
}

///|
pub fn text_listener(event_name : String, selector : String) -> @lepusa.Html {
  listen(
    event_name,
    [
      "    const target = document.querySelector(\{js_string(selector)});",
      "    if (!target) { return; }",
      "    target.textContent = payload == null ? \"\" : String(payload.message ?? payload);",
    ].join("\n"),
  )
}

///|
fn escape_text(content : String) -> String {
  content
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
}

///|
fn escape_attribute(content : String) -> String {
  escape_text(content)
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&#39;")
}

///|
fn js_string(content : String) -> String {
  "\"\{content.replace_all(old="\\", new="\\\\").replace_all(old="\"", new="\\\"")}\""
}
