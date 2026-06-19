///|
pub(all) enum Cmd {
  None
  Batch(Array[Cmd])
  Effect(String)
  Emit(EventTarget, Event)
  Navigate(String, Source)
} derive(Debug, Eq)

///|
pub let none : Cmd = None

///|
pub fn Cmd::effect(name : String) -> Cmd {
  Effect(name)
}

///|
pub fn Cmd::emit(event : Event, target? : EventTarget = AppTarget) -> Cmd {
  Emit(target, event)
}

///|
pub fn Cmd::navigate(window_label : String, source : Source) -> Cmd {
  Navigate(window_label, source)
}

///|
pub fn Cmd::batch(commands : Array[Cmd]) -> Cmd {
  match commands.length() {
    0 => None
    1 => commands[0]
    _ => Batch(commands)
  }
}

///|
pub fn Cmd::is_empty(self : Cmd) -> Bool {
  match self {
    None => true
    Batch(commands) => commands.all(fn(command) { command.is_empty() })
    Effect(_) => false
    Emit(_) => false
    Navigate(_) => false
  }
}
