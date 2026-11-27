///|
#derive(Debug, Eq)
pub struct Html {
  content : String
}

///|
pub fn Html::empty() -> Html {
  { content: "", }
}

///|
pub fn Html::text(content : String) -> Html {
  { content, }
}

///|
pub fn Html::content(self : Html) -> String {
  self.content
}
