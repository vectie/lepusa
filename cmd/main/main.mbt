///|
async fn main {
  let result = render_cli_async(drop_program(@sys.get_cli_args()))
  println(result.output)
  if result.exit_code != 0 {
    @sys.exit(result.exit_code)
  }
}
