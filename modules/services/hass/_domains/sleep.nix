# Sleep domain — bedtime progression, bed presence, wake routines
#
# Three-stage bedtime flow:
#   1. Winding Down  — get ready for bed (night light stays on for navigation)
#   2. In Bed        — settled in, audiobook time (whitenoise on, lights off)
#   3. Sleep         — done with audiobook, out cold (whitenoise stays)
#
# Triggers:
#   Winding Down  ← 10:00 PM daily
#   In Bed        ← bed presence (Monica, 2 min)
#   Sleep         ← manual or future: audiobook stops / sleep focus activates
{ lib, ... }:
{
  services.home-assistant.config = {
    scene = lib.mkAfter [
      # Stage 1: Get ready for bed
      {
        name = "Winding Down";
        icon = "mdi:weather-night";
        entities = {
          "input_boolean.goodnight" = "on";
          "input_select.house_mode" = "Night";
          "cover.smartwings_window_covering" = "closed";
          "media_player.tv" = "off";

          # Main lights off
          "light.essentials_a19_a60" = "off"; # Trashcan
          "light.essentials_a19_a60_2" = "off"; # Dishwasher
          "light.nanoleaf_multicolor_floor_lamp" = "off"; # Couch Lamp
          "light.nanoleaf_multicolor_hd_ls" = "off"; # Edmund Desk

          # Night light stays on — navigate to bed
          "light.smart_night_light_w" = "on";
        };
      }
      # Stage 2: In bed, audiobook time
      {
        name = "In Bed";
        icon = "mdi:bed";
        entities = {
          "switch.eve_energy_20ebu4101" = "on"; # Whitenoise
          "light.smart_night_light_w" = "off"; # No longer needed
        };
      }
      # Stage 3: Audiobook done, sleeping
      {
        name = "Sleep";
        icon = "mdi:sleep";
        entities = {
          # Confirm sealed state — whitenoise stays, everything else off
          "input_boolean.goodnight" = "on";
          "input_select.house_mode" = "Night";
          "switch.eve_energy_20ebu4101" = "on"; # Whitenoise stays
          "cover.smartwings_window_covering" = "closed";
          "media_player.tv" = "off";
          "light.essentials_a19_a60" = "off";
          "light.essentials_a19_a60_2" = "off";
          "light.nanoleaf_multicolor_floor_lamp" = "off";
          "light.nanoleaf_multicolor_hd_ls" = "off";
          "light.smart_night_light_w" = "off";
        };
      }
    ];

    script = lib.mkAfter {
      # Monica voice-activates this to nudge Edmund to come to bed
      bedtime_nudge = {
        alias = "Bedtime Nudge";
        icon = "mdi:bed-clock";
        sequence = [
          {
            action = "notify.mobile_app_edmunds_iphone";
            data = {
              title = "🛏️ Bedtime";
              message = "Monica's heading to bed — time to wrap up!";
            };
          }
        ];
      };
    };

    automation = lib.mkAfter [
      # Stage 1: 10 PM → Winding Down
      {
        alias = "Winding Down";
        id = "winding_down";
        description = "10 PM — lights off (night light stays), blinds closed, TV off";
        trigger = {
          platform = "time";
          at = "22:00:00";
        };
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.winding_down";
          }
        ];
      }

      # Stage 2: Bed presence → In Bed
      {
        alias = "In Bed";
        id = "bed_presence_in_bed";
        description = "Monica in bed 2 min → whitenoise on, night light off";
        trigger = {
          platform = "state";
          entity_id = "binary_sensor.monica_s_eight_sleep_side_bed_presence";
          to = "on";
          "for".minutes = 2;
        };
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.in_bed";
          }
        ];
      }

      # Bedtime nudge webhook (Monica: "Hey Siri, I'm getting into bed")
      {
        alias = "Bedtime nudge";
        id = "bedtime_nudge_webhook";
        trigger = {
          platform = "webhook";
          webhook_id = "bedtime-nudge-monica";
          allowed_methods = [ "POST" ];
          local_only = true;
        };
        action = [
          {
            action = "script.bedtime_nudge";
          }
        ];
      }

      # Good Morning — both out of bed for 2 min, after 7am
      {
        alias = "Good Morning - out of bed";
        id = "good_morning_bed_presence";
        trigger = [
          {
            platform = "state";
            entity_id = "binary_sensor.edmund_s_eight_sleep_side_bed_presence";
            to = "off";
            "for".minutes = 2;
          }
          {
            platform = "state";
            entity_id = "binary_sensor.monica_s_eight_sleep_side_bed_presence";
            to = "off";
            "for".minutes = 2;
          }
        ];
        condition = [
          {
            condition = "time";
            after = "07:00:00";
          }
          {
            condition = "state";
            entity_id = "binary_sensor.edmund_s_eight_sleep_side_bed_presence";
            state = "off";
          }
          {
            condition = "state";
            entity_id = "binary_sensor.monica_s_eight_sleep_side_bed_presence";
            state = "off";
          }
          {
            condition = "state";
            entity_id = "input_select.house_mode";
            state = "Night";
          }
          {
            condition = "state";
            entity_id = "binary_sensor.edmunds_iphone_focus";
            state = "off";
          }
          # TODO: Add Monica's focus condition once her phone is connected
        ];
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.good_morning";
          }
        ];
      }
    ];
  };
}
