///|
async fn main {
  let supplied = drop_program(@env.args())
  let args = if supplied.is_empty() {
    let executable = @os.executable()
    match executable.split_once("/Contents/MacOS/") {
      Some((app, _)) => {
        let contents = app.to_owned() + "/Contents"
        let resources = contents + "/Resources"
        let manifest = resources + "/lepusa/runtime.json"
        if @fs.exists(manifest) {
          let config = @json.parse(@fs.read_file(manifest).text())
          guard config is { "identifier": String(identifier), .. } else {
            fail("Bundled app identifier is missing")
          }
          let data = @os.home() + "/Library/Application Support/" + identifier
          if !@fs.exists(data) {
            @fs.mkdir(data)
          }
          @os.setenv("LEPUSA_APP_DIR", contents)
          @os.setenv("LEPUSA_RESOURCE_DIR", resources)
          @os.setenv("LEPUSA_APP_DATA_DIR", data)
          @os.setenv(
            "PATH",
            contents +
            "/MacOS:" +
            @env.get_env_var("PATH").unwrap_or("/usr/bin:/bin"),
          )
          @os.chdir(resources)
          ["launch", "--manifest", manifest]
        } else {
          supplied
        }
      }
      None => supplied
    }
  } else {
    supplied
  }
  let result = render_runtime_cli_async(args)
  println(result.output)
  if result.exit_code != 0 {
    @sys.exit(result.exit_code)
  }
}
