# Conversation intents — voice control via HA Assist
# Works with any voice assistant (Assist, Rhasspy, etc.)
_: {
  services.home-assistant.config = {
    conversation.intents = {
      # --- House modes ---
      SetModeHome = [
        "Set (mode|house) to home"
        "I'm (home|back)"
        "We're (home|back)"
      ];
      SetModeAway = [
        "Set (mode|house) to away"
        "I'm (leaving|going out)"
        "We're (leaving|going out)"
        "Goodbye"
      ];
      SetModeNight = [
        "Set (mode|house) to night"
        "Goodnight"
        "Good night"
        "Bedtime"
      ];
      GoodMorning = [
        "Good morning"
        "Wake up"
        "I'm (up|awake)"
      ];

      # --- TV ---
      TurnOnTv = [
        "Turn on [the] TV"
        "TV on"
      ];
      TurnOffTv = [
        "Turn off [the] TV"
        "TV off"
      ];
      PauseTv = [
        "Pause [the] TV"
        "Pause media"
      ];
      ResumeTv = [
        "Resume [the] TV"
        "Play [the] TV"
        "Resume media"
      ];
      SetSleepTimer = [
        "Set [a] sleep timer for {duration} (minutes|min)"
        "Sleep timer {duration} (minutes|min)"
        "Turn off TV in {duration} (minutes|min)"
      ];
      CancelSleepTimer = [
        "Cancel [the] sleep timer"
        "Stop [the] sleep timer"
      ];
      ElevenLabsSay = [
        "Say {message}"
        "Announce {message}"
        "Announce {message} on [the] homepods"
      ];
      TestElevenLabs = [
        "Test ElevenLabs"
        "Test ElevenLabs voice"
        "Run [a] voice test"
      ];

      # --- Status queries ---
      GetHouseMode = [
        "What (mode|is the mode)"
        "What is the house (mode|status)"
      ];
      GetDnd = [
        "Is do not disturb (on|off|active)"
        "Is DND (on|off|active)"
      ];

      # --- DND ---
      ToggleDnd = [
        "Turn (on|off) do not disturb"
        "Turn (on|off) DND"
        "(Enable|disable) do not disturb"
        "(Enable|disable) DND"
      ];

      # --- Everything off ---
      EverythingOff = [
        "Turn everything off"
        "Everything off"
        "Shut (everything|it all) down"
      ];
    };

    intent_script = {
      # --- House modes ---
      SetModeHome = {
        speech.text = "Welcome home.";
        action = [
          {
            action = "input_boolean.turn_off";
            target.entity_id = "input_boolean.goodnight";
          }
          {
            action = "input_boolean.turn_off";
            target.entity_id = "input_boolean.vacation_mode";
          }
        ];
      };
      SetModeAway = {
        speech.text = "Goodbye. Setting away mode.";
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.leave_home";
          }
        ];
      };
      SetModeNight = {
        speech.text = "Goodnight.";
        action = [
          {
            action = "input_boolean.turn_on";
            target.entity_id = "input_boolean.goodnight";
          }
        ];
      };
      GoodMorning = {
        speech.text = "Good morning.";
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.good_morning";
          }
        ];
      };

      # --- TV ---
      TurnOnTv = {
        speech.text = "Turning on the TV.";
        action = [
          {
            action = "media_player.turn_on";
            target.entity_id = "media_player.tv";
          }
        ];
      };
      TurnOffTv = {
        speech.text = "Turning off the TV.";
        action = [
          {
            action = "media_player.turn_off";
            target.entity_id = "media_player.tv";
          }
        ];
      };
      PauseTv = {
        speech.text = "Pausing the TV.";
        action = [
          {
            action = "media_player.media_pause";
            target.entity_id = "media_player.tv";
          }
        ];
      };
      ResumeTv = {
        speech.text = "Resuming the TV.";
        action = [
          {
            action = "media_player.media_play";
            target.entity_id = "media_player.tv";
          }
        ];
      };
      SetSleepTimer = {
        speech.text = "Sleep timer set for {{ duration }} minutes.";
        action = [
          {
            action = "input_number.set_value";
            target.entity_id = "input_number.tv_sleep_timer";
            data.value = "{{ duration }}";
          }
        ];
      };
      CancelSleepTimer = {
        speech.text = "Sleep timer cancelled.";
        action = [
          {
            action = "timer.cancel";
            target.entity_id = "timer.sleep";
          }
          {
            action = "input_number.set_value";
            target.entity_id = "input_number.tv_sleep_timer";
            data.value = 0;
          }
        ];
      };
      ElevenLabsSay = {
        speech.text = "Announcing on your HomePods now.";
        action = [
          {
            action = "tts.speak";
            target.entity_id = "tts.elevenlabs_text_to_speech";
            data = {
              media_player_entity_id = [
                "media_player.kitchen"
                "media_player.bathroom"
                "media_player.window_nightstand"
                "media_player.bathroom_nightstand"
              ];
              message = "{{ message }}";
            };
          }
        ];
      };
      TestElevenLabs = {
        speech.text = "Running ElevenLabs test on HomePods.";
        action = [
          {
            action = "tts.speak";
            target.entity_id = "tts.elevenlabs_text_to_speech";
            data = {
              media_player_entity_id = [
                "media_player.kitchen"
                "media_player.bathroom"
                "media_player.window_nightstand"
                "media_player.bathroom_nightstand"
              ];
              message = "ElevenLabs voice commands are ready.";
            };
          }
        ];
      };

      # --- Status ---
      GetHouseMode.speech.text = ''
        {% if is_state("input_boolean.vacation_mode", "on") %}The house is in Vacation mode.
        {% elif is_state("input_boolean.goodnight", "on") %}The house is in Night mode.
        {% elif states.person | selectattr('state', 'eq', 'home') | list | length == 0 %}The house is in Away mode.
        {% else %}The house is in Home mode.{% endif %}'';
      GetDnd.speech.text = ''Do not disturb is {{ states("input_boolean.do_not_disturb") }}.'';

      # --- DND ---
      ToggleDnd = {
        speech.text = ''Do not disturb {{ "enabled" if states("input_boolean.do_not_disturb") == "off" else "disabled" }}.'';
        action = [
          {
            action = "input_boolean.toggle";
            target.entity_id = "input_boolean.do_not_disturb";
          }
        ];
      };

      # --- Everything off ---
      EverythingOff = {
        speech.text = "Turning everything off. Goodnight.";
        action = [
          {
            action = "script.everything_off";
          }
        ];
      };
    };
  };
}
