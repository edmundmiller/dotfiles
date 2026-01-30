{
  lib,
  python3Packages,
  jujutsu,
}:

python3Packages.buildPythonApplication rec {
  pname = "agent-fleet";
  version = "0.1.0";
  format = "pyproject";

  src = ../projects/agent-fleet;

  nativeBuildInputs = with python3Packages; [
    hatchling
  ];

  propagatedBuildInputs = with python3Packages; [
    typer
    rich
  ];

  nativeCheckInputs = with python3Packages; [
    pytestCheckHook
  ];

  # Ensure jj is available at runtime
  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ jujutsu ]}"
  ];

  pythonImportsCheck = [ "agent_fleet" ];

  meta = with lib; {
    description = "Manage parallel JJ workspaces for AI coding agents";
    homepage = "https://github.com/emiller88/dotfiles";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "agent-fleet";
  };
}
