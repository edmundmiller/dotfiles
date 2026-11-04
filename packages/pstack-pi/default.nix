{
  applyPatches,
  fetchFromGitHub,
}:

applyPatches {
  name = "pstack-pi-0.16.0";

  src = fetchFromGitHub {
    owner = "0xrsydn";
    repo = "pstack-pi";
    rev = "c99321ac76bb8a08444a4a5bc8d844e2cf9ff4b5";
    hash = "sha256-67kpnmBmtU8BzQB4XcBcsJHYrqlGzSDumZ3h5/Mgt5Y=";
  };

  patches = [
    ./patches/0001-reject-ambiguous-batch-readonly.patch
    ./patches/0002-document-packaged-runtime-limits.patch
  ];
}
