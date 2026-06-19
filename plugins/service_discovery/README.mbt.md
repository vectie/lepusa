# Lepusa service discovery plugin

`@lepusa/plugins/service_discovery` declares a compact native contract for
discovering app-local and companion services without choosing a transport
backend.

```moonbit no-check
///|
let plugin = @service_discovery.plugin()

///|
let grant = @service_discovery.capability_for_window("main")

///|
let policy = @service_discovery.ServiceDiscoveryPolicy::new().service(
  @service_discovery.ServiceEndpoint::new(
    name="api",
    url="http://127.0.0.1:8080",
    health_path="/health",
  ),
)
```

The manifest routes are `serviceDiscovery.list`, `serviceDiscovery.resolve`,
`serviceDiscovery.status`, `serviceDiscovery.watch`, and
`serviceDiscovery.onServiceChanged`.
