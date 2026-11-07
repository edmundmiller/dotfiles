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
  pnpm_11,
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
      git-lfs
    ];
    text = ''
      repo="''${OPENWIKI_SCHEDULE_REPO:-$HOME/.local/state/openwiki/obsidian-vault}"
      remote="''${OPENWIKI_SCHEDULE_REMOTE:-git@github.com:edmundmiller/claude-vault.git}"
      openwiki_executable="''${OPENWIKI_SCHEDULE_EXECUTABLE:-/run/current-system/sw/bin/openwiki}"
      branch="automation/openwiki"

      if [ "''${OPENWIKI_SCHEDULE_PUBLISH:-0}" != "1" ]; then
        echo "openwiki-scheduled-ingestion: publication requires OPENWIKI_SCHEDULE_PUBLISH=1" >&2
        exit 78
      fi

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
        echo "openwiki-scheduled-ingestion: preserved dirty worktree; review it before retrying" >&2
        exit 75
      fi
      if [ "$(git -C "$repo" branch --show-current)" != "$branch" ]; then
        echo "openwiki-scheduled-ingestion: unexpected branch; refusing to switch existing work" >&2
        exit 75
      fi
      git -C "$repo" fetch origin main
      if ! git -C "$repo" merge-base --is-ancestor HEAD origin/main; then
        echo "openwiki-scheduled-ingestion: preserved unpublished commits; review them before retrying" >&2
        exit 75
      fi
      git -C "$repo" merge --ff-only origin/main
      run_base="$(git -C "$repo" rev-parse HEAD)"

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

      export OPENWIKI_WIKI_DIR="$repo/04_Resources"
      cd "$repo"
      ingestion_status=0
      "$openwiki_executable" ingest all --scheduled --print || ingestion_status=$?
      if [ "$ingestion_status" -ne 0 ]; then
        echo "openwiki-scheduled-ingestion: ingestion failed; preserving local output without publication" >&2
        exit "$ingestion_status"
      fi
      if [ -n "$(git status --porcelain=v1)" ]; then
        echo "openwiki-scheduled-ingestion: uncommitted output; refusing publication" >&2
        exit 75
      fi
      if [ "$(git branch --show-current)" != "$branch" ] ||
         ! git merge-base --is-ancestor "$run_base" HEAD; then
        echo "openwiki-scheduled-ingestion: branch changed during ingestion; refusing publication" >&2
        exit 75
      fi
      if [ "$(git rev-parse HEAD)" = "$run_base" ]; then
        exit 0
      fi
      if [ -n "$(git diff --name-only "$run_base" HEAD -- . ':!04_Resources')" ]; then
        echo "openwiki-scheduled-ingestion: changes outside wiki; refusing publication" >&2
        exit 75
      fi
      publish
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
          if (getenv("NODE_OPTIONS") != NULL) {
            fputs("openwiki-launchd-launcher: self-test retained NODE_OPTIONS\n", stderr);
            return 1;
          }
          if (strcmp(
              getenv("PATH"),
              "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            ) != 0) {
            fputs("openwiki-launchd-launcher: self-test PATH mismatch\n", stderr);
            return 1;
          }
          return 0;
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
      # Tell dyld to restrict injection independently of runtime code-signing flags.
      $CC -Os -Wl,-sectcreate,__RESTRICT,__restrict,/dev/null \
        openwiki-launchd-launcher.c -o openwiki-launchd-launcher
      $CC -Os -DOPENWIKI_LAUNCHER_TEST openwiki-launchd-launcher.c \
        -Wl,-sectcreate,__RESTRICT,__restrict,/dev/null \
        -o openwiki-launchd-launcher-test
      $CC -dynamiclib hostile-launcher-library.c -o hostile-launcher-library.dylib
      /usr/bin/codesign --force --sign - --options runtime \
        openwiki-launchd-launcher openwiki-launchd-launcher-test || {
        echo "openwiki-launchd-launcher: runtime signing failed" >&2
        exit 1
      }

      marker="$PWD/hostile-library-loaded"
      launcher_status=0
      NODE_OPTIONS=/tmp/hostile-node-options HOME=/tmp/hostile-home \
        PATH=/tmp/hostile-path \
        DYLD_INSERT_LIBRARIES="$PWD/hostile-launcher-library.dylib" \
        OPENWIKI_INJECTION_MARKER="$marker" \
        ./openwiki-launchd-launcher-test || launcher_status=$?
      if [ "$launcher_status" -ne 0 ]; then
        echo "openwiki-launchd-launcher: hardened self-test exited $launcher_status" >&2
      fi
      if [ -e "$marker" ]; then
        echo "openwiki-launchd-launcher: injected library created marker" >&2
        /usr/bin/codesign --display --verbose=4 openwiki-launchd-launcher-test >&2
        /usr/bin/csrutil status >&2 || true
        exit 1
      fi
      if [ "$launcher_status" -ne 0 ]; then
        exit "$launcher_status"
      fi
      echo "openwiki-launchd-launcher: hardened self-test passed; injection marker absent"
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
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "langchain-ai";
    repo = "openwiki";
    rev = "261b9ffa57493f9768d6e565d444194c7ee5cadc";
    hash = "sha256-Jt1Qv9rLZnDxYhfXYIRPlpKvLKCM24QytOigef+TXlA=";
  };

  patches = [
    ./patches/0101-openwiki-0.9-local-connectors.patch
    ./patches/0102-openwiki-0.9-git-ingestion.patch
    ./patches/0103-openwiki-0.9-personal-safety.patch
    ./patches/0104-openwiki-personal-ingestion-regressions.patch
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      patches
      pname
      src
      version
      ;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-ooju0QHGl4cIt8KdOFci8UXXOvCcplZtKMV2dNvg5Ho=";
  };

  nativeBuildInputs = [
    makeWrapper
    nodejs_22
    node-gyp
    pnpm_11
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
    cp -r dist integrations node_modules package.json skills README.md LICENSE "$out/lib/openwiki/"
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      ln -s ${lib.getExe openwikiLaunchdLauncher} "$out/bin/openwiki-launchd-launcher"
      ln -s ${lib.getExe openwikiScheduledIngestion} "$out/bin/openwiki-scheduled-ingestion"
    ''}
    makeWrapper ${lib.getExe nodejs_22} "$out/bin/openwiki" \
      --add-flags "$out/lib/openwiki/dist/cli/cli.js" \
      --set-default OPENWIKI_TELEMETRY_DISABLED 1 \
      --set-default DO_NOT_TRACK 1 \
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

  # The pnpm tree contains many executable scripts; stripping each one is
  # expensive and does not affect runtime correctness.
  dontStrip = true;
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -f "$out/lib/openwiki/integrations/openwiki/SKILL.md"
    test -f "$out/lib/openwiki/dist/integrations/pi/openwiki.js"
    test -f "$out/lib/openwiki/skills/write-connector/SKILL.md"
    test -f "$out/lib/openwiki/skills/mermaid-diagrams/SKILL.md"
    test -f "$out/lib/openwiki/node_modules/fast-xml-parser/package.json"
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      PATH=${
        lib.makeBinPath [
          git
          git-lfs
        ]
      }:$PATH \
        bash ${./test-scheduled-ingestion-recovery.sh} "$out/bin/openwiki-scheduled-ingestion"
    ''}
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
