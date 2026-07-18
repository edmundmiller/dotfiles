{
  inputs,
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  cctools,
  makeWrapper,
  node-gyp,
  nodejs_22,
  pnpm_10,
  pnpmConfigHook,
  python313,
  removeReferencesTo,
  srcOnly,
}:

let
  imsg =
    if stdenv.hostPlatform.isDarwin then
      inputs.nix-steipete-tools.packages.${stdenv.hostPlatform.system}.imsg.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          cp -R imsg-bridge-helper.dylib PhoneNumberKit_PhoneNumberKit.bundle SQLite.swift_SQLite.bundle "$out/bin/"
        '';
      })
    else
      null;

  openwikiLaunchdLauncher = stdenv.mkDerivation {
    pname = "openwiki-launchd-launcher";
    version = "1";
    dontUnpack = true;

    buildPhase = ''
      cat > openwiki-launchd-launcher.c <<'EOF'
      #include <limits.h>
      #include <pwd.h>
      #include <stdio.h>
      #include <stdlib.h>
      #include <string.h>
      #include <unistd.h>

      extern char **environ;
      static char *empty_environment[] = { NULL };

      static int prepare_environment(void) {
        const struct passwd *user = getpwuid(getuid());
        if (user == NULL) {
          fputs("openwiki-launchd-launcher: cannot resolve user\n", stderr);
          return 70;
        }

        environ = empty_environment;
        if (
          setenv("HOME", user->pw_dir, 1) != 0 ||
          setenv("USER", user->pw_name, 1) != 0 ||
          setenv(
            "PATH",
            "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            1
          ) != 0
        ) {
          perror("openwiki-launchd-launcher");
          return 70;
        }

        return 0;
      }

      static int enter_wiki(void) {
        const struct passwd *user = getpwuid(getuid());
        char wiki[PATH_MAX];
        if (user == NULL) {
          fputs("openwiki-launchd-launcher: cannot resolve user\n", stderr);
          return 70;
        }
        const int length = snprintf(
          wiki,
          sizeof(wiki),
          "%s/obsidian-vault",
          user->pw_dir
        );
        if (length < 0 || (size_t)length >= sizeof(wiki) || chdir(wiki) != 0) {
          perror("openwiki-launchd-launcher");
          return 72;
        }
        return 0;
      }

      int main(int argc, char **argv) {
        int status = prepare_environment();
        if (status != 0) {
          return status;
        }

      #ifdef OPENWIKI_LAUNCHER_TEST
        const int self_test = 1;
      #else
        const int self_test =
          argc == 2 && strcmp(argv[1], "--self-test") == 0;
      #endif
        if (self_test) {
          return getenv("NODE_OPTIONS") != NULL ||
            strcmp(
              getenv("PATH"),
              "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            ) != 0;
        }
        if (argc != 1) {
          fputs("usage: openwiki-launchd-launcher\n", stderr);
          return 64;
        }

        status = enter_wiki();
        if (status != 0) {
          return status;
        }
        execl(
          "/run/current-system/sw/bin/openwiki",
          "openwiki",
          "ingest",
          "all",
          "--scheduled",
          "--print",
          (char *)NULL
        );
        perror("openwiki-launchd-launcher");
        return 126;
      }
      EOF
      cat > hostile-launcher-library.c <<'EOF'
      #include <stdio.h>
      #include <stdlib.h>

      __attribute__((constructor))
      static void injected(void) {
        const char *marker = getenv("OPENWIKI_INJECTION_MARKER");
        if (marker != NULL) {
          FILE *file = fopen(marker, "w");
          if (file != NULL) {
            fclose(file);
          }
        }
      }
      EOF
      $CC -Os openwiki-launchd-launcher.c -o openwiki-launchd-launcher
      $CC -Os -DOPENWIKI_LAUNCHER_TEST openwiki-launchd-launcher.c \
        -o openwiki-launchd-launcher-test
      $CC -dynamiclib hostile-launcher-library.c -o hostile-launcher-library.dylib
      /usr/bin/codesign --force --sign - --options runtime \
        openwiki-launchd-launcher openwiki-launchd-launcher-test

      marker="$PWD/hostile-library-loaded"
      NODE_OPTIONS=/tmp/hostile-node-options HOME=/tmp/hostile-home \
        PATH=/tmp/hostile-path \
        DYLD_INSERT_LIBRARIES="$PWD/hostile-launcher-library.dylib" \
        OPENWIKI_INJECTION_MARKER="$marker" \
        ./openwiki-launchd-launcher-test
      test ! -e "$marker"
    '';

    installPhase = ''
      mkdir -p "$out/bin"
      cp openwiki-launchd-launcher "$out/bin/"
    '';

    postFixup = ''
      /usr/bin/codesign --force --sign - --options runtime \
        "$out/bin/openwiki-launchd-launcher"
    '';

    meta.mainProgram = "openwiki-launchd-launcher";
  };
in

stdenv.mkDerivation (finalAttrs: {
  pname = "openwiki";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "langchain-ai";
    repo = "openwiki";
    rev = "d4e94ab513ab13908c6b61346b23dc17bbd59b1f";
    hash = "sha256-jble+grUAwAV8+E8EfuGZ86nDwOmwVOuzV2pogplbdY=";
  };

  patches = [
    ./patches/0001-configurable-personal-wiki-directory.patch
    ./patches/0002-imessage-connector.patch
    ./patches/0003-read-only-skills-regression.patch
    ./patches/0004-writable-skill-replacement.patch
    ./patches/0005-evlog-ingestion-events.patch
    ./patches/0006-links-connector.patch
    ./patches/0007-discrawl-connector.patch
    ./patches/0008-rss-connector-regression.patch
    ./patches/0009-rss-connector.patch
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      patches
      pname
      src
      version
      ;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-g2gxm4iBRcnKfXLwZJ326IGbEBRhcXE8iXakh3dU4cY=";
  };

  nativeBuildInputs = [
    makeWrapper
    nodejs_22
    node-gyp
    pnpm_10
    pnpmConfigHook
    python313
    removeReferencesTo
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    cctools.libtool
  ];

  buildPhase = ''
    runHook preBuild
    pushd node_modules/.pnpm/better-sqlite3@12.11.1/node_modules/better-sqlite3
    npm run build-release --offline "--nodedir=${srcOnly nodejs_22}"
    find build -type f -exec ${removeReferencesTo}/bin/remove-references-to -t "${srcOnly nodejs_22}" {} \;
    popd

    pnpm rebuild esbuild
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/openwiki" "$out/bin"
    cp -r dist node_modules package.json skills README.md LICENSE "$out/lib/openwiki/"
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      ln -s ${lib.getExe openwikiLaunchdLauncher} "$out/bin/openwiki-launchd-launcher"
    ''}
    makeWrapper ${lib.getExe nodejs_22} "$out/bin/openwiki" \
      --add-flags "$out/lib/openwiki/dist/cli.js" \
      ${lib.optionalString stdenv.hostPlatform.isDarwin ''
        --prefix PATH : ${lib.makeBinPath [ imsg ]} \
        --set OPENWIKI_EXECUTABLE /run/current-system/sw/bin/openwiki \
        --set OPENWIKI_LAUNCHER /run/current-system/sw/bin/openwiki-launchd-launcher
      ''}

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -f "$out/lib/openwiki/skills/write-connector/SKILL.md"
    test -f "$out/lib/openwiki/skills/migrate-wiki-to-okf/SKILL.md"
    test -f "$out/lib/openwiki/node_modules/fast-xml-parser/package.json"
    runHook postInstallCheck
  '';

  meta = {
    description = "Agent-generated documentation wiki for codebases";
    homepage = "https://github.com/langchain-ai/openwiki";
    license = lib.licenses.mit;
    mainProgram = "openwiki";
    platforms = lib.platforms.unix;
  };
})
