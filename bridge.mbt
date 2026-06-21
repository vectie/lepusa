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
  let routes = self.window_command_routes(config.window_label)
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
    "  const routeSet = new Set(routes);",
    "  const reservedApiKeys = new Set([\"routes\", \"can\", \"command\", \"commands\", \"listen\", \"unlisten\", \"invoke\", \"InvokeError\", \"isInvokeError\"]);",
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
    "  class LepusaInvokeError extends Error {",
    "    constructor(message, options = {}) {",
    "      super(message);",
    "      this.name = \"LepusaInvokeError\";",
    "      this.code = options.code || \"handler-error\";",
    "      this.route = options.route || \"\";",
    "      this.id = options.id || \"\";",
    "      this.failure = options.failure || null;",
    "      this.response = options.response || null;",
    "    }",
    "  }",
    "  const createInvokeError = (response, route = \"\") => {",
    "    const failure = response && typeof response.failure === \"object\" ? response.failure : null;",
    "    const message = (response && response.error) || (failure && failure.message) || \"Lepusa invoke failed\";",
    "    return new LepusaInvokeError(message, {",
    "      code: (response && response.errorCode) || (failure && failure.code) || \"handler-error\",",
    "      route: (failure && failure.route) || route || \"\",",
    "      id: (response && response.id) || \"\",",
    "      failure,",
    "      response: response || null,",
    "    });",
    "  };",
    "  const invokeControlError = (code, route, message) => new LepusaInvokeError(message, {",
    "    code,",
    "    route,",
    "    failure: { code, message, route },",
    "    response: null,",
    "  });",
    "  const withInvokeControls = (promise, route, options = {}) => {",
    "    const signal = options && options.signal;",
    "    const timeoutMs = Number(options && options.timeoutMs ? options.timeoutMs : 0);",
    "    if ((!signal || typeof signal !== \"object\") && !(timeoutMs > 0)) {",
    "      return promise;",
    "    }",
    "    return new Promise((resolve, reject) => {",
    "      let settled = false;",
    "      let timeoutId = 0;",
    "      let abortHandler = null;",
    "      const cleanup = () => {",
    "        if (timeoutId) {",
    "          clearTimeout(timeoutId);",
    "        }",
    "        if (signal && abortHandler && typeof signal.removeEventListener === \"function\") {",
    "          signal.removeEventListener(\"abort\", abortHandler);",
    "        }",
    "      };",
    "      const settle = (fn, value) => {",
    "        if (settled) {",
    "          return;",
    "        }",
    "        settled = true;",
    "        cleanup();",
    "        fn(value);",
    "      };",
    "      if (signal && signal.aborted) {",
    "        settle(reject, invokeControlError(\"cancelled\", route, \"invoke cancelled\"));",
    "        return;",
    "      }",
    "      if (timeoutMs > 0) {",
    "        timeoutId = setTimeout(() => settle(reject, invokeControlError(\"timeout\", route, \"invoke timed out\")), timeoutMs);",
    "      }",
    "      if (signal && typeof signal.addEventListener === \"function\") {",
    "        abortHandler = () => settle(reject, invokeControlError(\"cancelled\", route, \"invoke cancelled\"));",
    "        signal.addEventListener(\"abort\", abortHandler, { once: true });",
    "      }",
    "      promise.then((value) => settle(resolve, value), (error) => settle(reject, error));",
    "    });",
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
    "  const createInvoker = (route) => (payload = null, options = {}) => api.invoke(route, payload, options);",
    "  const installRoute = (target, route, options = {}) => {",
    "    const parts = route.split(\".\").filter(Boolean);",
    "    if (parts.length === 0) {",
    "      return;",
    "    }",
    "    if (options.direct && reservedApiKeys.has(parts[0])) {",
    "      return;",
    "    }",
    "    const leaf = parts.pop();",
    "    let scope = target;",
    "    for (const part of parts) {",
    "      const existing = scope[part];",
    "      if (existing != null && (typeof existing !== \"object\" || Array.isArray(existing))) {",
    "        return;",
    "      }",
    "      scope = scope[part] ||= {};",
    "    }",
    "    if (scope[leaf] == null) {",
    "      scope[leaf] = createInvoker(route);",
    "    }",
    "  };",
    "  const freezeTree = (value) => {",
    "    if (!value || typeof value !== \"object\" || Object.isFrozen(value)) {",
    "      return value;",
    "    }",
    "    for (const key of Object.keys(value)) {",
    "      freezeTree(value[key]);",
    "    }",
    "    return Object.freeze(value);",
    "  };",
    "  const commands = {};",
    "  for (const route of routes) {",
    "    installRoute(commands, route);",
    "  }",
    "  const api = {",
    "    routes: () => routes.slice(),",
    "    can: (route) => routeSet.has(route),",
    "    command: (route) => {",
    "      if (!routeSet.has(route)) {",
    "        throw new LepusaInvokeError(`Unknown Lepusa command route: ${route}`, { code: \"unknown-command\", route });",
    "      }",
    "      return createInvoker(route);",
    "    },",
    "    commands: freezeTree(commands),",
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
    "    invoke: async (route, payload = null, options = {}) => {",
    "      if (!routeSet.has(route)) {",
    "        throw new LepusaInvokeError(`Unknown Lepusa command route: ${route}`, { code: \"unknown-command\", route });",
    "      }",
    "      const hook = globalThis[nativeHook];",
    "      if (typeof hook !== \"function\") {",
    "        throw new LepusaInvokeError(`Missing Lepusa native hook: ${nativeHook}`, { code: \"transport-error\", route });",
    "      }",
    "      const parts = route.split(\".\");",
    "      const callbackId = String(++nextId);",
    "      const errorId = String(++nextId);",
    "      const request = {",
    "        id: callbackId,",
    "        window_label: windowLabel,",
    "        plugin: parts[0],",
    "        command: parts.slice(1).join(\".\"),",
    "        payload: payload == null ? \"\" : JSON.stringify(payload),",
    "        callback_id: callbackId,",
    "        error_id: errorId,",
    "      };",
    "      const response = await withInvokeControls(Promise.resolve().then(() => hook(request)), route, options);",
    "      if (response && response.error) {",
    "        throw createInvokeError(response, route);",
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
    "    InvokeError: LepusaInvokeError,",
    "    isInvokeError: (error) => error instanceof LepusaInvokeError || (error && error.name === \"LepusaInvokeError\" && typeof error.code === \"string\"),",
    "  };",
    "  Object.defineProperty(globalThis, eventDispatchHook, {",
    "    value: dispatchEvent,",
    "    configurable: true,",
    "  });",
    "  for (const route of routes) {",
    "    installRoute(api, route, { direct: true });",
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
