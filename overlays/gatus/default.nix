_final: prev: {
  gatus = prev.gatus.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/0001-durable-custom-transitions.patch ];
  });
}
