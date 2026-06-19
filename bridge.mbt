///|
pub struct BridgeConfig {
  global_name : String
  native_hook : String
  event_dispatch_hook : String
  window_label : String
} derive(Debug, Eq)

///|
pub fn BridgeConfig::new(
  global_name? : String = "lepusa",
  native_hook? : String = "__lepusaInvoke",
  event_dispatch_hook? : String = "__lepusaDispatchEvent",
  window_label? : String = "main",
) -> BridgeConfig {
  { global_name, native_hook, event_dispatch_hook, window_label }
}

///|
pub fn BridgeConfig::validate(self : BridgeConfig) -> Array[String] {
  let problems : Array[String] = []
  if self.global_name == "" {
    problems.push("bridge global name is required")
  }
  if self.native_hook == "" {
    problems.push("bridge native hook is required")
  }
  if self.event_dispatch_hook == "" {
    problems.push("bridge event dispatch hook is required")
  }
  if self.window_label == "" {
    problems.push("bridge window label is required")
  }
  problems
}

///|
pub struct BridgeScript {
  global_name : String
  native_hook : String
  event_dispatch_hook : String
  window_label : String
  routes : Array[String]
  source : String
} derive(Debug, Eq)

///|
pub fn BridgeScript::global_name(self : BridgeScript) -> String {
  self.global_name
}

///|
pub fn BridgeScript::native_hook(self : BridgeScript) -> String {
  self.native_hook
}

///|
pub fn BridgeScript::event_dispatch_hook(self : BridgeScript) -> String {
  self.event_dispatch_hook
}

///|
pub fn BridgeScript::window_label(self : BridgeScript) -> String {
  self.window_label
}

///|
pub fn BridgeScript::routes(self : BridgeScript) -> Array[String] {
  self.routes.copy()
}

///|
pub fn BridgeScript::source(self : BridgeScript) -> String {
  self.source
}

///|
pub fn RuntimePlan::bridge_script(
  self : RuntimePlan,
  config? : BridgeConfig = BridgeConfig::new(),
) -> Result[BridgeScript, Array[String]] {
  let problems = config.validate()
  let routes = self.command_routes()
  for route in routes {
    if route == "" {
      problems.push("bridge route is required")
    }
  }
  if problems.is_empty() {
    Ok({
      global_name: config.global_name,
      native_hook: config.native_hook,
      event_dispatch_hook: config.event_dispatch_hook,
      window_label: config.window_label,
      routes,
      source: bridge_source(config, routes),
    })
  } else {
    Err(problems)
  }
}

///|
fn bridge_source(config : BridgeConfig, routes : Array[String]) -> String {
  let route_literals = routes
    .map(fn(route) { route.js_string_literal() })
    .join(",")
  let global_name = config.global_name.js_string_literal()
  let native_hook = config.native_hook.js_string_literal()
  let event_dispatch_hook = config.event_dispatch_hook.js_string_literal()
  let window_label = config.window_label.js_string_literal()
  [
    "(() => {",
    "  const globalName = \{global_name};",
    "  const nativeHook = \{native_hook};",
    "  const eventDispatchHook = \{event_dispatch_hook};",
    "  const windowLabel = \{window_label};",
    "  const routes = [\{route_literals}];",
    "  let nextId = 0;",
    "  const eventHandlers = new Map();",
    "  const decodePayload = (payload) => {",
    "    if (typeof payload !== \"string\") {",
    "      return payload ?? null;",
    "    }",
    "    if (payload === \"\") {",
    "      return null;",
    "    }",
    "    try {",
    "      return JSON.parse(payload);",
    "    } catch (_) {",
    "      return payload;",
    "    }",
    "  };",
    "  const dispatchEvent = (event) => {",
    "    if (!event || typeof event.name !== \"string\") {",
    "      return false;",
    "    }",
    "    const handlers = eventHandlers.get(event.name);",
    "    if (!handlers || handlers.size === 0) {",
    "      return false;",
    "    }",
    "    const payload = decodePayload(event.payload);",
    "    for (const handler of Array.from(handlers)) {",
    "      handler(payload, event);",
    "    }",
    "    return true;",
    "  };",
    "  const api = {",
    "    routes: () => routes.slice(),",
    "    listen: (name, handler) => {",
    "      if (typeof name !== \"string\" || name === \"\") {",
    "        throw new Error(\"Lepusa event name is required\");",
    "      }",
    "      if (typeof handler !== \"function\") {",
    "        throw new Error(\"Lepusa event handler must be a function\");",
    "      }",
    "      let handlers = eventHandlers.get(name);",
    "      if (!handlers) {",
    "        handlers = new Set();",
    "        eventHandlers.set(name, handlers);",
    "      }",
    "      handlers.add(handler);",
    "      return () => api.unlisten(name, handler);",
    "    },",
    "    unlisten: (name, handler) => {",
    "      const handlers = eventHandlers.get(name);",
    "      if (!handlers) {",
    "        return false;",
    "      }",
    "      const removed = handlers.delete(handler);",
    "      if (handlers.size === 0) {",
    "        eventHandlers.delete(name);",
    "      }",
    "      return removed;",
    "    },",
    "    invoke: async (route, payload = null) => {",
    "      if (!routes.includes(route)) {",
    "        throw new Error(`Unknown Lepusa command route: ${route}`);",
    "      }",
    "      const hook = globalThis[nativeHook];",
    "      if (typeof hook !== \"function\") {",
    "        throw new Error(`Missing Lepusa native hook: ${nativeHook}`);",
    "      }",
    "      const parts = route.split(\".\");",
    "      const request = {",
    "        id: String(++nextId),",
    "        windowLabel,",
    "        window_label: windowLabel,",
    "        plugin: parts[0],",
    "        command: parts.slice(1).join(\".\"),",
    "        payload: payload == null ? \"\" : JSON.stringify(payload),",
    "      };",
    "      const response = await hook(request);",
    "      if (response && response.error) {",
    "        throw new Error(response.error);",
    "      }",
    "      if (!response || response.payload == null) {",
    "        return null;",
    "      }",
    "      if (typeof response.payload !== \"string\") {",
    "        return response.payload;",
    "      }",
    "      try {",
    "        return JSON.parse(response.payload);",
    "      } catch (_) {",
    "        return response.payload;",
    "      }",
    "    },",
    "  };",
    "  Object.defineProperty(globalThis, eventDispatchHook, {",
    "    value: dispatchEvent,",
    "    configurable: true,",
    "  });",
    "  for (const route of routes) {",
    "    const parts = route.split(\".\");",
    "    const leaf = parts.pop();",
    "    let scope = api;",
    "    for (const part of parts) {",
    "      scope = scope[part] ||= {};",
    "    }",
    "    scope[leaf] = (payload = null) => api.invoke(route, payload);",
    "  }",
    "  Object.defineProperty(globalThis, globalName, {",
    "    value: Object.freeze(api),",
    "    configurable: true,",
    "  });",
    "})();",
    "",
  ].join("\n")
}

///|
fn String::js_string_literal(self : String) -> String {
  "\"" +
  self
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\t", new="\\t") +
  "\""
}
