{ pkgs, ... }:
{

  toFilteredImage =
    imageFile: options:
    let
      result = "result.png";
      filteredImage = pkgs.runCommand "filterWallpaper" { buildInputs = [ pkgs.imagemagick ]; } ''
        mkdir "$out"
        convert ${options} ${imageFile} $out/${result}
      '';
    in
    "${filteredImage}/${result}";
}
