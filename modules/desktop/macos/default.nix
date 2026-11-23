# modules/desktop/macos/default.nix
#
# Opinionated macOS system.defaults shared across all Darwin hosts.
# Enable with: modules.desktop.macos.enable = true;
#
# Sets: dock, finder, trackpad, keyboard/text behavior, login window,
# Siri off, ads off, DS_Store prevention, screencapture, etc.
{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.macos;
in
{
  options.modules.desktop.macos = {
    enable = mkBoolOpt false;
  };

  config = optionalAttrs isDarwin (
    mkIf cfg.enable {
      # ref: https://github.com/yannbertrand/macos-defaults
      system.defaults = {
        # minimal dock
        dock = {
          autohide = true;
          orientation = "left";
          show-process-indicators = false;
          show-recents = false;
          mru-spaces = false;
          static-only = true;
          tilesize = 36;
          # disable hot corners
          wvous-bl-corner = 1;
          wvous-br-corner = 1;
          wvous-tl-corner = 1;
          wvous-tr-corner = 1;
        };

        # a finder that tells me what I want to know and lets me work
        finder = {
          _FXShowPosixPathInTitle = true;
          _FXSortFoldersFirst = true;
          AppleShowAllExtensions = true;
          FXDefaultSearchScope = "SCcf";
          FXEnableExtensionChangeWarning = false;
          QuitMenuItem = true;
          ShowPathbar = true;
          ShowStatusBar = true;
        };

        # trackpad: tap to click, two-finger right click, three-finger swipe gestures
        trackpad = {
          Clicking = true;
          TrackpadRightClick = true;
          # keep drag OFF so 3-finger swipes (Mission Control / app switching) work reliably
          TrackpadThreeFingerDrag = false;
          # nix-darwin expects 0 (off) or 2 (on) for these gesture enums.
          TrackpadThreeFingerHorizSwipeGesture = 2;
          TrackpadThreeFingerVertSwipeGesture = 2;
        };

        # keyboard & text behavior
        NSGlobalDomain = {
          "com.apple.keyboard.fnState" = false;
          AppleKeyboardUIMode = 3;
          AppleInterfaceStyle = "Dark";
          ApplePressAndHoldEnabled = false;
          InitialKeyRepeat = 15;
          KeyRepeat = 2;
          # kill all "smart" text substitution
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticDashSubstitutionEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = false;
          NSAutomaticSpellingCorrectionEnabled = false;
          # expand save panel by default
          NSNavPanelExpandedStateForSaveMode = true;
          NSNavPanelExpandedStateForSaveMode2 = true;
        };

        loginwindow = {
          GuestEnabled = false;
          SHOWFULLNAME = true;
        };

        screencapture = {
          location = "~/Desktop";
          type = "png";
        };

        # lock screen immediately after screensaver
        screensaver = {
          askForPassword = true;
          askForPasswordDelay = 0;
        };

        WindowManager.EnableStandardClickToShowDesktop = false;

        CustomUserPreferences = {
          # disable Siri
          "com.apple.assistant.support"."Assistant Enabled" = false;
          "com.apple.Siri" = {
            StatusMenuVisible = false;
            UserHasDeclinedEnable = true;
          };
          # disable personalized ads
          "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
          # avoid .DS_Store on network/USB volumes
          "com.apple.desktopservices" = {
            DSDontWriteNetworkStores = true;
            DSDontWriteUSBStores = true;
          };
          # don't auto-open Photos when plugging in devices
          "com.apple.ImageCapture".disableHotPlug = true;
        };
      };
    }
  );
}
