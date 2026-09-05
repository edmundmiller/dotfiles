# Audiobookshelf

NUC libraries are `/audiobooks/main` and `/audiobooks/private`, declared by
`libraryDirs`. Preserve directory owner/group `emiller:audiobookshelf` and
mode 2775 so SSH uploads inherit the service group. Book files use group
`audiobookshelf` and mode 660; organize by author/book directory.

After an authorized upload, `stat` and
`sudo -u audiobookshelf test -r <book>` establish that the service can read it.
Use UI/API rescans if scheduled discovery is insufficient, not direct DB writes.

State lives under `/var/lib/audiobookshelf`; SQLite is
`config/absdatabase.sqlite`. API automation needs valid auth (otherwise 401).
Service checks on NUC: `systemctl is-active audiobookshelf.service` and
`curl -fsS -I http://localhost:13378/` (expected active and HTTP 200).
