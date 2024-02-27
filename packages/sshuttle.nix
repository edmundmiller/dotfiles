{
  lib,
  python3,
  fetchFromGitHub,
  fetchpatch,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "sshuttle";
  version = "1.1.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "sshuttle";
    repo = "sshuttle";
    rev = "v${version}";
    hash = "sha256-7jiDTjtL4FiQ4GimSPtUDKPUA29l22a7XILN/s4/DQY=";
  };

  patches = [
    (fetchpatch
      {
        url = "https://github.com/NixOS/nixpkgs/raw/nixos-unstable/pkgs/tools/security/sshuttle/sudo.patch";
        hash = "sha256-wPHnnbP3YhYtnspJm/AfroSFtRm/VcsDNGkNXPrRHzU=";
      })
  ];

  postPatch = ''
    substituteInPlace setup.cfg \
      --replace '--cov=sshuttle --cov-branch --cov-report=term-missing' ""
  '';

  nativeBuildInputs = [
    python3.pkgs.poetry-core
  ];

  propagatedBuildInputs = with python3.pkgs; [
    furo
    sphinx
  ];

  pythonImportsCheck = ["sshuttle"];

  meta = with lib; {
    description = "Transparent proxy server that works as a poor man's VPN.  Forwards over ssh.  Doesn't require admin.  Works with Linux and MacOS.  Supports DNS tunneling";
    homepage = "https://github.com/sshuttle/sshuttle";
    changelog = "https://github.com/sshuttle/sshuttle/blob/${src.rev}/CHANGES.rst";
    license = licenses.lgpl21Only;
    maintainers = with maintainers; [];
    mainProgram = "sshuttle";
  };
}
