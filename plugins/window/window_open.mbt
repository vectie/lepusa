///|
pub struct WindowOpenOperation {
  window_label : String
  payload : String
} derive(Debug, Eq)

///|
pub fn WindowOpenOperation::new(
  window_label~ : String,
  payload~ : String,
) -> WindowOpenOperation {
  { window_label, payload }
}

///|
pub fn WindowOpenOperation::window_label(self : WindowOpenOperation) -> String {
  self.window_label
}

///|
pub fn WindowOpenOperation::payload(self : WindowOpenOperation) -> String {
  self.payload
}

///|
pub fn WindowOpenOperation::to_json(self : WindowOpenOperation) -> String {
  self.to_json_value().stringify()
}

///|
fn handle_open(payload : String) -> Result[String, String] {
  match @lepusa.WindowConfig::parse_open_payload(payload) {
    Err(problem) => Err(problem)
    Ok(window) => {
      let operation = WindowOpenOperation::new(
        window_label=window.label(),
        payload~,
      )
      Ok(
        Json::object({
          "status": Json::string("queued"),
          "windowLabel": Json::string(window.label()),
          "action": Json::string("open"),
          "operation": operation.to_json_value(),
        }).stringify(),
      )
    }
  }
}

///|
fn WindowOpenOperation::to_json_value(self : WindowOpenOperation) -> Json {
  Json::object({
    "windowLabel": Json::string(self.window_label),
    "action": Json::string("open"),
    "payload": Json::string(self.payload),
  })
}
