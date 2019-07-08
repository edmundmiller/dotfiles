{ stdenv, fetchurl, }:

stdenv.mkDerivation {
  version = "3.2.0";
  name = "cypress-${version}";
  src = fetchurl {
    url = "https://download.cypress.io/desktop/${version}?platform=linux64";
    sha256 = "0vz1dv7l10kzaqbsgsbvma531n5pi3vfdnyqpwia5b0m31j6wj0y";
  };
}
