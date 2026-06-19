///|
pub type Dispatch[Msg] = (Msg) -> Cmd

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
pub fn[Model, Msg] cell_with_dispatch(
  model~ : Model,
  update~ : (Msg, Model) -> (Model, Cmd),
  view~ : (Dispatch[Msg], Model) -> Html,
) -> (Dispatch[Msg], Cell) {
  let dispatch : Dispatch[Msg] = fn(msg) {
    let (_, command) = update(msg, model)
    command
  }
  let html = view(dispatch, model)
  (dispatch, Cell::new(html~))
}

///|
pub fn simple_cell(html : Html) -> Cell {
  Cell::new(html~)
}
