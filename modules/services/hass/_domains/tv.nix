# TV/media domain — inputs, scripts, automations for media_player.tv
{ lib, ... }:
let
  # --- Helper functions ---
  tvAction = action: {
    inherit action;
    target.entity_id = "media_player.tv";
  };

  tvOn = tvAction "media_player.turn_on";
  tvOff = tvAction "media_player.turn_off";
in
{
  services.home-assistant.config = {
    input_number.tv_sleep_timer = {
      name = "TV Sleep Timer";
      icon = "mdi:timer-outline";
      min = 0;
      max = 240;
      step = 15;
      unit_of_measurement = "min";
    };

    timer.sleep = {
      name = "Sleep Timer";
      icon = "mdi:timer-sand";
      duration = "02:00:00";
    };

    counter.tv_on_today = {
      name = "TV Sessions Today";
      icon = "mdi:television";
      step = 1;
    };

    script = {
      tv_on = {
        alias = "Turn on TV";
        icon = "mdi:television";
        sequence = [ tvOn ];
      };
      tv_off = {
        alias = "Turn off TV";
        icon = "mdi:television-off";
        sequence = [ tvOff ];
      };
    };

    automation = lib.mkAfter [
      # --- TV idle auto-off (2hr, night mode only) ---
      {
        alias = "TV auto-off after 2 hours idle";
        id = "tv_idle_auto_off";
        trigger = {
          platform = "state";
          entity_id = "media_player.tv";
          to = "idle";
          "for".hours = 2;
        };
        condition = {
          condition = "state";
          entity_id = "input_boolean.goodnight";
          state = "on";
        };
        action = [ tvOff ];
      }

      # --- TV sleep timer ---
      {
        alias = "TV sleep timer - start";
        id = "tv_sleep_timer_start";
        trigger = {
          platform = "state";
          entity_id = "input_number.tv_sleep_timer";
        };
        condition = {
          condition = "template";
          value_template = "{{ states('input_number.tv_sleep_timer') | int > 0 }}";
        };
        action = [
          {
            action = "timer.start";
            target.entity_id = "timer.sleep";
            data.duration = "{{ states('input_number.tv_sleep_timer') | int * 60 }}";
          }
        ];
      }
      {
        alias = "TV sleep timer - expired";
        id = "tv_sleep_timer_expired";
        trigger = {
          platform = "event";
          event_type = "timer.finished";
          event_data.entity_id = "timer.sleep";
        };
        action = [
          tvOff
          {
            action = "input_number.set_value";
            target.entity_id = "input_number.tv_sleep_timer";
            data.value = 0;
          }
        ];
      }

      # --- TV session counter ---
      {
        alias = "Reset TV counter daily";
        id = "reset_tv_counter_daily";
        trigger = {
          platform = "time";
          at = "00:00:00";
        };
        action = [
          {
            action = "counter.reset";
            target.entity_id = "counter.tv_on_today";
          }
        ];
      }
      {
        alias = "Count TV sessions";
        id = "count_tv_sessions";
        trigger = {
          platform = "state";
          entity_id = "media_player.tv";
          to = "playing";
        };
        action = [
          {
            action = "counter.increment";
            target.entity_id = "counter.tv_on_today";
          }
        ];
      }
    ];
  };
}
