def "main opencode-update" [] {
  let cache_dir = ($env.HOME | path join ".cache" "opencode")
  let node_modules = ($cache_dir | path join "node_modules")
  let bun_lock = ($cache_dir | path join "bun.lock")

  if (($node_modules | path exists) or ($bun_lock | path exists)) {
    print "Clearing OpenCode plugin cache..."
    if ($node_modules | path exists) { rm -rf $node_modules }
    if ($bun_lock | path exists) { rm -f $bun_lock }
  }
}
