{
  hermesH5py,
  hermesPatchedCtypes,
  hermesPython,
  pkgs,
}:
# Keep the routine check at the failing boundary. Pre-activation verification
# separately realizes and exercises the full optional-integration Hermes venv.
pkgs.runCommand "hermes-local-libffi-regression"
  {
    nativeBuildInputs = [ pkgs.cctools ];
  }
  ''
    test '${hermesPython}' = '${pkgs.python312}'
    test -d '${hermesH5py}/${hermesPython.sitePackages}/h5py'

    set -- ${hermesPatchedCtypes}/${hermesPython.sitePackages}/_ctypes*.so
    test "$#" -eq 1
    ctypes_module="$1"

    otool -L "$ctypes_module" | grep -F '/usr/lib/libffi.dylib'

    export PYTHONPATH='${hermesPatchedCtypes}/${hermesPython.sitePackages}'

    ${hermesPython}/bin/python3 - <<'PY'
    from ctypes import CFUNCTYPE, c_int

    callback = CFUNCTYPE(c_int, c_int)(lambda value: value + 1)
    assert callback(1) == 2
    PY

    mkdir -p "$out"
    printf '%s\n' "Hermes h5py and ctypes use the Darwin system libffi." > "$out/result"
  ''
