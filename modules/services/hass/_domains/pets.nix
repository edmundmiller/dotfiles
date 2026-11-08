{ lib, ... }:
let
  inherit (import ../_lib.nix) ensureEnabled notificationPalette;
  # Feeding plan is code-owned. Zero leaves the vet's calorie target unset.
  dailyCalorieGoal = 0;
  kibblePortion = 0.25;
  boneCalories = 0;
  feedingDay = "{{ (now() - timedelta(hours=6)).date().isoformat() }}";
  dailyLedger = ''
    {% set saved = states('input_text.phoebe_food_ledger') | from_json({}) %}
    {% set day = (now() - timedelta(hours=6)).date().isoformat() %}
    {% set ledger = saved if saved.get('day') == day else {} %}
  '';
  dentalToday = ''
    {% set stamp = as_datetime(states('input_text.phoebe_last_dental_treat'), none) %}
    {{ stamp is not none and (as_local(stamp) - timedelta(hours=6)).date().isoformat()
       == (now() - timedelta(hours=6)).date().isoformat() }}
  '';
in
{
  services.home-assistant.config = {
    input_datetime.phoebe_last_fed = {
      name = "Phoebe Last Fed";
      icon = "mdi:dog";
      has_date = true;
      has_time = true;
      # Restore the shared NFC cooldown across restarts.
    };

    input_text = {
      phoebe_last_dental_treat = {
        name = "Phoebe Last Dental Treat";
        icon = "mdi:tooth";
      };
      # One restored record avoids midnight reset races and missed resets when HA is off.
      phoebe_food_ledger = {
        name = "Phoebe Food Ledger";
        max = 255;
      };
    };

    template = lib.mkAfter [
      {
        sensor = [
          {
            name = "Phoebe Daily Calorie Goal";
            unique_id = "phoebe_daily_calorie_goal";
            unit_of_measurement = "kcal";
            icon = "mdi:target";
            state = toString dailyCalorieGoal;
            attributes = {
              meal_portion_cups = kibblePortion;
              bone_calories = boneCalories;
            };
          }
          {
            name = "Phoebe Daily Calories";
            unique_id = "phoebe_daily_calories";
            unit_of_measurement = "kcal";
            icon = "mdi:food-drumstick";
            state = dailyLedger + ''
              {% set cups = ledger.get('breakfast', 0) + ledger.get('lunch', 0) + ledger.get('dinner', 0) %}
              {% set stamp = as_datetime(states('input_text.phoebe_last_dental_treat'), none) %}
              {% set dental = stamp is not none and (as_local(stamp) - timedelta(hours=6)).date().isoformat() == day %}
              {{ (cups * 391 + (49 if dental else 0)
                  + ledger.get('bone', 0) * ${toString boneCalories}) | round(2) }}
            '';
            attributes = {
              tracking_day = feedingDay;
              breakfast_cups = dailyLedger + "{{ ledger.get('breakfast', 0) }}";
              lunch_cups = dailyLedger + "{{ ledger.get('lunch', 0) }}";
              dinner_cups = dailyLedger + "{{ ledger.get('dinner', 0) }}";
              bone_count = dailyLedger + "{{ ledger.get('bone', 0) }}";
              dental_treat = dentalToday;
            };
          }
          {
            name = "Phoebe Calorie Budget";
            unique_id = "phoebe_calorie_budget";
            icon = "mdi:target";
            state = ''
              {% set goal = states('sensor.phoebe_daily_calorie_goal') | float(0) %}
              {% set calories = states('sensor.phoebe_daily_calories') | float(0) %}
              {% if goal <= 0 %}Set calorie goal
              {% elif calories > goal %}Over goal
              {% elif state_attr('sensor.phoebe_daily_calories', 'bone_count') | int(0) > 0
                  and ${toString boneCalories} <= 0 %}Bone calories needed
              {% else %}Within goal{% endif %}
            '';
          }
        ];
      }
    ];

    # All writes, including dashboard taps, share one queue to prevent lost portions.
    script.phoebe_record_food = {
      alias = "Phoebe - Record Food";
      mode = "queued";
      max = 20;
      fields = {
        food = {
          required = true;
          selector.select.options = [
            "kibble"
            "breakfast"
            "lunch"
            "dinner"
            "dental"
            "bone"
          ];
        };
        cups = {
          description = "Kibble cups to add. NFC always records 0.25 cups.";
          selector.number = {
            min = 0.125;
            max = 2;
            step = 0.125;
          };
        };
        scanner = {
          description = "Mobile app device ID from the NFC event. Never broadcast.";
          selector.text = { };
        };
      };
      sequence = [
        {
          condition = "template";
          value_template = "{{ food in ['kibble', 'breakfast', 'lunch', 'dinner', 'dental', 'bone'] and (food in ['dental', 'bone'] or 0.125 <= cups | default(${toString kibblePortion}) | float(0) <= 2) }}";
        }
        {
          variables = {
            day = feedingDay;
            meal = "{{ ('breakfast' if 6 <= now().hour < 11 else 'lunch' if 11 <= now().hour < 16 else 'dinner') if food == 'kibble' else food }}";
            portion = "{{ cups | default(${toString kibblePortion}) | float }}";
            ledger = dailyLedger + "{{ ledger }}";
            had_dental = dentalToday;
          };
        }
        {
          variables.duplicate = "{{ (food == 'dental' and had_dental) or (food == 'kibble' and now().timestamp() - (state_attr('input_datetime.phoebe_last_fed', 'timestamp') | float(0)) < 120) }}";
        }
        {
          "if" = [
            {
              condition = "template";
              value_template = "{{ not duplicate }}";
            }
          ];
          "then" = [
            {
              choose = [
                {
                  conditions = "{{ food == 'dental' }}";
                  sequence = [
                    {
                      action = "input_text.set_value";
                      target.entity_id = "input_text.phoebe_last_dental_treat";
                      data.value = "{{ now().isoformat() }}";
                    }
                  ];
                }
              ];
              default = [
                {
                  action = "input_text.set_value";
                  target.entity_id = "input_text.phoebe_food_ledger";
                  data.value = "{{ dict(ledger, day=day, **{meal: (ledger.get(meal, 0) + (1 if food == 'bone' else portion)) | round(3)}) | to_json }}";
                }
                {
                  "if" = [
                    {
                      condition = "template";
                      value_template = "{{ food != 'bone' }}";
                    }
                  ];
                  "then" = [
                    {
                      action = "input_datetime.set_datetime";
                      target.entity_id = "input_datetime.phoebe_last_fed";
                      data.timestamp = "{{ now().timestamp() }}";
                    }
                  ];
                }
              ];
            }
          ];
        }
        {
          variables.feedback = ''
            {% if duplicate and food == 'dental' %}
              Dental treat already logged for this day. Don't give Phoebe another one. No calories added.
            {% elif duplicate %}
              Kibble scanned again within 2 minutes. Already recorded; no extra portion added.
            {% elif food == 'dental' %}
              Recorded Phoebe's dental treat: 1 small Yummy Comb, 49 kcal.
            {% elif food == 'bone' %}
              Recorded Phoebe's bone: ${toString boneCalories} kcal.{{ ' Bone calories are not configured; total is incomplete.' if ${toString boneCalories} <= 0 else "" }}
            {% else %}
              Recorded Phoebe's {{ meal }}: {{ portion }} cup kibble, {{ (portion * 391) | round(2) }} kcal.
            {% endif %}
          '';
        }
        {
          "if" = [
            {
              condition = "template";
              value_template = "{{ not duplicate }}";
            }
          ];
          "then" = [
            {
              action = "logbook.log";
              data = {
                name = "Phoebe Food";
                message = "{{ feedback | trim }}";
                entity_id = "sensor.phoebe_daily_calories";
              };
            }
          ];
        }
        {
          "if" = [
            {
              condition = "template";
              value_template = "{{ scanner | default('') != '' and device_attr(scanner | default(''), 'name') is not none }}";
            }
          ];
          "then" = [
            {
              # Use the original mobile app name even when its device is renamed.
              action = "{{ 'notify.mobile_app_' ~ (device_attr(scanner, 'name') | slugify) }}";
              data = {
                title = "{{ 'Phoebe: already recorded' if duplicate else 'Phoebe: food recorded' }}";
                message = "{{ feedback | trim }}";
                data = notificationPalette.pets // {
                  notification_icon = "mdi:dog";
                  url = "/nixos-lovelace/phoebe";
                  clickAction = "/nixos-lovelace/phoebe";
                };
              };
            }
          ];
        }
      ];
    };

    automation = lib.mkAfter (ensureEnabled [
      {
        alias = "Phoebe Kibble NFC - Record Feeding";
        id = "phoebe_kibble_nfc_record_feeding";
        mode = "queued";
        trigger = {
          platform = "tag";
          tag_id = [
            "729d23f5-3368-487e-bff0-3cf6a22cba29" # Under the food scooper.
            "2e0ad6b4-069c-445a-a23f-4af99eccb21d" # Front of the food container.
          ];
        };
        action = [
          {
            action = "script.phoebe_record_food";
            data = {
              food = "kibble";
              cups = 0.25;
              scanner = "{{ trigger.event.data.get('device_id', '') }}";
            };
          }
        ];
      }
      {
        alias = "Phoebe Dental Treat NFC - Record or Warn";
        id = "phoebe_dental_treat_nfc_record_or_warn";
        mode = "queued";
        trigger = {
          platform = "tag";
          tag_id = "32eb4a84-1dbb-477a-a775-6a344c3a7b25";
        };
        action = [
          {
            action = "script.phoebe_record_food";
            data = {
              food = "dental";
              scanner = "{{ trigger.event.data.get('device_id', '') }}";
            };
          }
        ];
      }
    ]);
  };
}
