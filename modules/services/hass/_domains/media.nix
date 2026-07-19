{ lib, ... }:

{
  services.home-assistant.config.script = lib.mkAfter {
    book_player_start = {
      alias = "Book Player - Start or Resume";
      icon = "mdi:book-play";
      fields = {
        book_uri = {
          name = "Book URI";
          required = true;
          selector.text = { };
        };
        player_entity_id = {
          name = "Music Assistant Player";
          required = true;
          selector.entity = {
            domain = "media_player";
            integration = "music_assistant";
          };
        };
      };
      sequence = [
        {
          action = "music_assistant.play_media";
          target.entity_id = "{{ player_entity_id }}";
          data = {
            media_id = "{{ book_uri }}";
            media_type = "audiobook";
            enqueue = "replace";
          };
        }
      ];
    };

    book_player_pause = {
      alias = "Book Player - Pause";
      icon = "mdi:pause";
      fields.player_entity_id = {
        name = "Music Assistant Player";
        required = true;
        selector.entity = {
          domain = "media_player";
          integration = "music_assistant";
        };
      };
      sequence = [
        {
          action = "media_player.media_pause";
          target.entity_id = "{{ player_entity_id }}";
        }
      ];
    };

    book_player_resume = {
      alias = "Book Player - Resume";
      icon = "mdi:play";
      fields.player_entity_id = {
        name = "Music Assistant Player";
        required = true;
        selector.entity = {
          domain = "media_player";
          integration = "music_assistant";
        };
      };
      sequence = [
        {
          action = "media_player.media_play";
          target.entity_id = "{{ player_entity_id }}";
        }
      ];
    };
  };
}
