///|
pub(all) enum Source {
  InlineHtml(String)
  LocalPath(String)
  RemoteUrl(String)
  RabbitaMount(String)
} derive(Debug, Eq)

///|
pub struct ProtocolMapping {
  scheme : String
  root : String
} derive(Debug, Eq)

///|
pub fn ProtocolMapping::new(
  scheme~ : String,
  root~ : String,
) -> ProtocolMapping {
  { scheme, root }
}

///|
pub fn ProtocolMapping::scheme(self : ProtocolMapping) -> String {
  self.scheme
}

///|
pub fn ProtocolMapping::root(self : ProtocolMapping) -> String {
  self.root
}

///|
pub struct VirtualFile {
  path : String
  content : String
} derive(Debug, Eq)

///|
pub fn VirtualFile::new(path~ : String, content~ : String) -> VirtualFile {
  { path, content }
}

///|
pub fn VirtualFile::path(self : VirtualFile) -> String {
  self.path
}

///|
pub fn VirtualFile::content(self : VirtualFile) -> String {
  self.content
}

///|
pub(all) enum ResolvedSourceKind {
  ResolvedInlineHtml
  ResolvedLocalPath
  ResolvedRemoteUrl
  ResolvedRabbitaMount
} derive(Debug, Eq)

///|
pub struct ResolvedSource {
  kind : ResolvedSourceKind
  url : String
  protocol_mappings : Array[ProtocolMapping]
  virtual_files : Array[VirtualFile]
} derive(Debug, Eq)

///|
pub fn ResolvedSource::kind(self : ResolvedSource) -> ResolvedSourceKind {
  self.kind
}

///|
pub fn ResolvedSource::url(self : ResolvedSource) -> String {
  self.url
}

///|
pub fn ResolvedSource::protocol_mappings(
  self : ResolvedSource,
) -> Array[ProtocolMapping] {
  self.protocol_mappings.copy()
}

///|
pub fn ResolvedSource::virtual_files(
  self : ResolvedSource,
) -> Array[VirtualFile] {
  self.virtual_files.copy()
}

///|
pub fn Source::html(content : String) -> Source {
  InlineHtml(content)
}

///|
pub fn Source::local_path(path : String) -> Source {
  LocalPath(path)
}

///|
pub fn Source::url(url : String) -> Source {
  RemoteUrl(url)
}

///|
pub fn Source::rabbita(mount : String) -> Source {
  RabbitaMount(mount)
}

///|
pub fn Source::is_empty(self : Source) -> Bool {
  match self {
    InlineHtml(content) => content == ""
    LocalPath(path) => path == ""
    RemoteUrl(url) => url == ""
    RabbitaMount(mount) => mount == ""
  }
}

///|
pub fn Source::resolve(
  self : Source,
  window_label~ : String,
  asset_protocol? : String = "lepusa",
) -> Result[ResolvedSource, String] {
  if self.is_empty() {
    return Err("source must not be empty")
  }
  if asset_protocol == "" {
    return Err("asset protocol is required")
  }
  let safe_label = window_label.to_asset_segment()
  match self {
    InlineHtml(content) =>
      Ok({
        kind: ResolvedInlineHtml,
        url: "\{asset_protocol}://inline/\{safe_label}/index.html",
        protocol_mappings: [
          ProtocolMapping::new(
            scheme=asset_protocol,
            root="memory:\{safe_label}",
          ),
        ],
        virtual_files: [VirtualFile::new(path="index.html", content~)],
      })
    LocalPath(path) =>
      Ok({
        kind: ResolvedLocalPath,
        url: "\{asset_protocol}://local/\{safe_label}/index.html",
        protocol_mappings: [
          ProtocolMapping::new(scheme=asset_protocol, root=path),
        ],
        virtual_files: [],
      })
    RemoteUrl(url) =>
      Ok({
        kind: ResolvedRemoteUrl,
        url,
        protocol_mappings: [],
        virtual_files: [],
      })
    RabbitaMount(mount) =>
      Ok({
        kind: ResolvedRabbitaMount,
        url: "\{asset_protocol}://rabbita/\{safe_label}/index.html",
        protocol_mappings: [
          ProtocolMapping::new(scheme=asset_protocol, root="rabbita:\{mount}"),
        ],
        virtual_files: [],
      })
  }
}

///|
fn String::to_asset_segment(self : String) -> String {
  let mut segment = ""
  for char in self.to_lower() {
    if (char >= 'a' && char <= 'z') ||
      (char >= '0' && char <= '9') ||
      char == '-' ||
      char == '_' {
      segment = segment + char.to_string()
    } else {
      segment = segment + "-"
    }
  }
  if segment == "" {
    "window"
  } else {
    segment
  }
}
