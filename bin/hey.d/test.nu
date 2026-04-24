use ./common.nu *

def "main ztest" [...args: string] {
  let ctx = (context)
  cd $ctx.flake_dir

  if ((^bash -lc "command -v zunit >/dev/null 2>&1" | complete).exit_code != 0) {
    print -e "zunit not found. Install with: brew install zunit-zsh/zunit/zunit"
    error make {msg: "zunit not found"}
  }

  if ($args | is-not-empty) {
    ^zunit ...$args
  } else {
    let tests = (ls config/**/*.zunit | get name)
    for t in $tests {
      ^zunit $t
    }
  }
}
