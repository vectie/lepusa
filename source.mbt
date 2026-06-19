///|
pub(all) enum Source {
  InlineHtml(String)
  LocalPath(String)
  RemoteUrl(String)
  RabbitaMount(String)
} derive(Debug, Eq)

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
