///|
pub(all) enum BackpressureOverflow {
  RejectNew
  DropOldest
} derive(Debug, Eq)

///|
pub fn BackpressureOverflow::name(self : BackpressureOverflow) -> String {
  match self {
    RejectNew => "reject-new"
    DropOldest => "drop-oldest"
  }
}

///|
pub struct BackpressurePolicy {
  max_pending : Int
  overflow : BackpressureOverflow
} derive(Debug, Eq)

///|
pub fn BackpressurePolicy::unbounded() -> BackpressurePolicy {
  { max_pending: -1, overflow: RejectNew }
}

///|
pub fn BackpressurePolicy::bounded(
  max_pending~ : Int,
  overflow? : BackpressureOverflow = RejectNew,
) -> BackpressurePolicy {
  { max_pending, overflow }
}

///|
pub fn BackpressurePolicy::new(
  max_pending? : Int = -1,
  overflow? : BackpressureOverflow = RejectNew,
) -> BackpressurePolicy {
  { max_pending, overflow }
}

///|
pub fn BackpressurePolicy::max_pending(self : BackpressurePolicy) -> Int {
  self.max_pending
}

///|
pub fn BackpressurePolicy::overflow(
  self : BackpressurePolicy,
) -> BackpressureOverflow {
  self.overflow
}

///|
pub fn BackpressurePolicy::is_bounded(self : BackpressurePolicy) -> Bool {
  self.max_pending >= 0
}

///|
pub fn BackpressurePolicy::is_unbounded(self : BackpressurePolicy) -> Bool {
  !self.is_bounded()
}

///|
pub fn BackpressurePolicy::at_capacity(
  self : BackpressurePolicy,
  pending : Int,
) -> Bool {
  self.is_bounded() && pending >= self.max_pending
}

///|
pub fn BackpressurePolicy::validate(self : BackpressurePolicy) -> Array[String] {
  let problems : Array[String] = []
  if self.is_bounded() && self.max_pending < 1 {
    problems.push("backpressure max pending must be positive")
  }
  problems
}

///|
pub fn BackpressurePolicy::to_json(self : BackpressurePolicy) -> String {
  [
    "{",
    "\"bounded\":\{self.is_bounded().json_bool()},",
    "\"maxPending\":\{self.max_pending},",
    "\"overflow\":\{self.overflow.name().json_string()}",
    "}",
  ].join("")
}
