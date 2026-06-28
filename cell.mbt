///|
pub type Emit[Msg] = (Msg) -> Cmd

///|
pub struct Cell {
  id : String
  html : Html
} derive(Debug, Eq)

///|
fn next_cell_id() -> String {
  "lepusa-root"
}

///|
pub fn Cell::new(
  id? : String = next_cell_id(),
  html? : Html = Html::empty(),
) -> Cell {
  { id, html }
}

///|
pub fn Cell::id(self : Cell) -> String {
  self.id
}

///|
pub fn Cell::html(self : Cell) -> Html {
  self.html
}

///|
pub fn[Model, Msg] cell_with_emit(
  model~ : Model,
  update~ : (Msg, Model) -> (Model, Cmd),
  view~ : (Emit[Msg], Model) -> Html,
) -> (Emit[Msg], Cell) {
  let emit : Emit[Msg] = fn(msg) {
    let (_, command) = update(msg, model)
    command
  }
  let html = view(emit, model)
  (emit, Cell::new(html~))
}

///|
pub fn simple_cell(html : Html) -> Cell {
  Cell::new(html~)
}
