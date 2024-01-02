{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "catgpt";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "ibuildthecloud";
    repo = "catgpt";
    rev = "v${version}";
    hash = "sha256-2smt7C8YK2qPuUChmfDhWYYG2poxz/W5qXBgUtJLEIk=";
  };

  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  ldflags = ["-s" "-w"];

  meta = with lib; {
    description = "Catgpt` is a command-line tool that uses the OpenAI model to generate text based on user input";
    homepage = "https://github.com/ibuildthecloud/catgpt";
    license = licenses.asl20;
    maintainers = with maintainers; [];
    mainProgram = "catgpt";
  };
}
