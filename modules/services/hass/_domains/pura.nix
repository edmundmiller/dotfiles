# Pura domain — fragrance automation routines
{ lib, ... }:
let
  inherit (import ../_lib.nix) ensureEnabled;

  # Update these area IDs after confirming your Pura device areas in HA.
  # Examples: "living_room", "bedroom".
  puraAreaIds = [ "living_room" ];

  puraIntensity = 5; # Balanced (1-10)
  puraDuration = {
    hours = 0;
    minutes = 30;
    seconds = 0;
  };

  # Fragrance level sensors currently present in your HA instance.
  # Add more here if you add additional Pura devices.
  puraRemainingSensors = [
    "sensor.entryway_diffuser_slot_1_fragrance_remaining"
    "sensor.entryway_diffuser_slot_2_fragrance_remaining"
  ];
in
{
  services.home-assistant.config = {
    script = lib.mkAfter {
      pura_arrive_home_freshen = {
        alias = "Pura - Arrive Home Freshen";
        icon = "mdi:spray-bottle";
        sequence = [
          {
            action = "pura.start_timer";
            data = {
              area_id = puraAreaIds;
              intensity = puraIntensity;
              duration = puraDuration;
            };
          }
        ];
      };
    };

    automation = lib.mkAfter (ensureEnabled [
      {
        alias = "Pura - first person arrives home";
        id = "pura_first_person_arrives_freshen";
        description = "Start Pura timer when the first person arrives home";
        trigger = [
          {
            platform = "state";
            entity_id = "person.edmund_miller";
            to = "home";
          }
          {
            platform = "state";
            entity_id = "person.moni";
            to = "home";
          }
        ];
        condition = [
          {
            # First to arrive — triggering person already changed to home
            condition = "template";
            value_template = "{{ states.person | selectattr('state', 'eq', 'home') | list | length == 1 }}";
          }
          {
            # Skip while vacation mode owns home state changes
            condition = "state";
            entity_id = "input_boolean.vacation_mode";
            state = "off";
          }
        ];
        action = [
          {
            action = "script.pura_arrive_home_freshen";
          }
        ];
      }

      {
        alias = "Pura - slot empty notification";
        id = "pura_slot_empty_notification";
        description = "Notify Edmund when a Pura fragrance slot reaches 0% remaining";
        trigger = lib.map (entity: {
          platform = "numeric_state";
          entity_id = entity;
          below = 1;
        }) puraRemainingSensors;
        action = [
          {
            action = "notify.mobile_app_edmunds_iphone";
            data = {
              title = "🧴 Pura refill needed";
              message = "{{ state_attr(trigger.entity_id, 'friendly_name') | replace(' fragrance remaining', '') }} is empty{% set scent = states(trigger.entity_id | replace('_fragrance_remaining', '_fragrance')) %}{% if scent not in ['unknown', 'unavailable', 'none', ''] %} ({{ scent }}){% endif %}.";
            };
          }
        ];
      }
    ]);
  };
}
