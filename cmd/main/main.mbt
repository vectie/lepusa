///|
async fn main {
  let result = render_cli_async(drop_program(@env.args()))
  println(result.output)
  if result.exit_code != 0 {
    @sys.exit(result.exit_code)
  }
}
