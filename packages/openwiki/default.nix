{
  inputs,
  lib,
  stdenv,
  coreutils,
  fetchFromGitHub,
  fetchPnpmDeps,
  git,
  git-lfs,
  cctools,
  makeWrapper,
  node-gyp,
  nodejs_22,
  pnpm_10,
  pnpmConfigHook,
  python313,
  removeReferencesTo,
  srcOnly,
  writeShellApplication,
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

  openwikiScheduledIngestion = writeShellApplication {
    name = "openwiki-scheduled-ingestion";
    runtimeInputs = [
      coreutils
      git
    ];
    text = ''
      repo="''${OPENWIKI_SCHEDULE_REPO:-$HOME/.local/state/openwiki/obsidian-vault}"
      remote="''${OPENWIKI_SCHEDULE_REMOTE:-git@github.com:edmundmiller/claude-vault.git}"
      branch="automation/openwiki"

      mkdir -p "$(dirname "$repo")"
      if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
        git clone --branch main "$remote" "$repo"
        git -C "$repo" switch -c "$branch"
      fi

      if [ "$(git -C "$repo" remote get-url origin)" != "$remote" ]; then
        echo "openwiki-scheduled-ingestion: unexpected origin URL" >&2
        exit 69
      fi
      if [ -d "$(git -C "$repo" rev-parse --git-path rebase-merge)" ] ||
         [ -d "$(git -C "$repo" rev-parse --git-path rebase-apply)" ]; then
        echo "openwiki-scheduled-ingestion: preserved interrupted rebase" >&2
        exit 75
      fi
      if [ -n "$(git -C "$repo" status --porcelain=v1)" ]; then
        echo "openwiki-scheduled-ingestion: preserved dirty isolated checkout" >&2
        exit 75
      fi

      if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
        git -C "$repo" switch "$branch"
      else
        git -C "$repo" fetch origin main
        git -C "$repo" switch -c "$branch" origin/main
      fi

      publish() {
        for attempt in 1 2 3 4 5; do
          git -C "$repo" fetch origin main
          git -C "$repo" rebase origin/main
          remote_before="$(git -C "$repo" rev-parse origin/main)"
          mutation_tip="$(git -C "$repo" rev-parse HEAD)"
          if push_output="$(git -C "$repo" push origin HEAD:main 2>&1)"; then
            git -C "$repo" fetch origin main
            remote_tip="$(git -C "$repo" rev-parse origin/main)"
            authoritative_tip="$(git -C "$repo" ls-remote origin refs/heads/main | cut -f1)"
            if [ "$remote_tip" != "$authoritative_tip" ] ||
               ! git -C "$repo" merge-base --is-ancestor "$mutation_tip" "$remote_tip"; then
              echo "openwiki-scheduled-ingestion: remote verification failed" >&2
              return 75
            fi
            return 0
          fi

          git -C "$repo" fetch origin main
          remote_after="$(git -C "$repo" rev-parse origin/main)"
          if [ "$remote_before" = "$remote_after" ]; then
            printf '%s\n' "$push_output" >&2
            return 1
          fi
          echo "openwiki-scheduled-ingestion: remote main advanced; retrying ($attempt/5)" >&2
          sleep "$attempt"
        done
        echo "openwiki-scheduled-ingestion: remote main kept advancing" >&2
        return 75
      }

      publish
      git -C "$repo" switch -C "$branch" origin/main
      export OPENWIKI_WIKI_DIR="$repo/04_Resources"
      cd "$repo"
      set +e
      /run/current-system/sw/bin/openwiki ingest all --scheduled --print
      ingestion_status=$?
      set -e
      publish
      exit "$ingestion_status"
    '';
  };

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

        execl(
          "/run/current-system/sw/bin/openwiki-scheduled-ingestion",
          "openwiki-scheduled-ingestion",
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
    ./patches/0010-relative-raw-tool-paths.patch
    ./patches/0011-skip-personal-tweet-index.patch
    ./patches/0012-git-provenance.patch
    ./patches/0013-scheduled-git-mutation-lane.patch
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
    node scripts/patch-deepagents-path-guard.mjs
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/openwiki" "$out/bin"
    cp -r dist node_modules package.json skills README.md LICENSE "$out/lib/openwiki/"
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      ln -s ${lib.getExe openwikiLaunchdLauncher} "$out/bin/openwiki-launchd-launcher"
      ln -s ${lib.getExe openwikiScheduledIngestion} "$out/bin/openwiki-scheduled-ingestion"
    ''}
    makeWrapper ${lib.getExe nodejs_22} "$out/bin/openwiki" \
      --add-flags "$out/lib/openwiki/dist/cli.js" \
      --prefix PATH : ${
        lib.makeBinPath [
          git
          git-lfs
          nodejs_22
        ]
      } \
      ${lib.optionalString stdenv.hostPlatform.isDarwin ''
        --prefix PATH : ${lib.makeBinPath [ imsg ]} \
        --run 'export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"' \
        --run 'export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"' \
        --run 'export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"' \
        --set OPENWIKI_EXECUTABLE /run/current-system/sw/bin/openwiki \
        --set OPENWIKI_LAUNCHER /run/current-system/sw/bin/openwiki-launchd-launcher \
        --run 'export OPENWIKI_SCHEDULE_CWD="$HOME/.local/state/openwiki/obsidian-vault"'
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
