# Audiobookshelf Service

Audiobookshelf runs on the NUC as the self-hosted audiobook and podcast server.
The module is `modules/services/audiobookshelf/default.nix` and is enabled from
`hosts/nuc/default.nix`.

## Library Paths

The NUC Audiobookshelf libraries are:

- `/audiobooks/main` — primary shared audiobook library.
- `/audiobooks/private` — private audiobook library.

The module declares these as `modules.services.audiobookshelf.libraryDirs` and
uses tmpfiles rules to keep both directories owned for SSH writes and readable
by the service.

Expected directory mode and ownership:

```bash
drwxrwsr-x emiller:audiobookshelf /audiobooks/main
drwxrwsr-x emiller:audiobookshelf /audiobooks/private
```

The setgid bit is intentional so files and folders copied in over SSH inherit
the `audiobookshelf` group.

## SSH Copy Convention

For a single-book `.m4b`, copy into an author/book folder under the appropriate
library. Example:

```bash
SRC="$HOME/path/to/Book Title.m4b"
DEST_DIR="/audiobooks/main/Author Name/Book Title"
ssh nuc "mkdir -p '$DEST_DIR' && chmod 2775 '$DEST_DIR' && chgrp audiobookshelf '$DEST_DIR'"
rsync -avh --progress "$SRC" "nuc:$DEST_DIR/"
ssh nuc "chmod 660 '$DEST_DIR/Book Title.m4b' && chgrp audiobookshelf '$DEST_DIR/Book Title.m4b'"
```

For multi-file books, copy the whole book directory with `rsync -avh --progress`
and then fix group/modes recursively:

```bash
ssh nuc "chgrp -R audiobookshelf '$DEST_DIR' && find '$DEST_DIR' -type d -exec chmod 2775 {} + && find '$DEST_DIR' -type f -exec chmod 660 {} +"
```

Before handing off, verify the copied artifact:

```bash
ssh nuc "stat -c '%A %U:%G %s %n' '$DEST_DIR/Book Title.m4b'"
ssh nuc "sudo -u audiobookshelf test -r '$DEST_DIR/Book Title.m4b' && echo audiobookshelf_can_read=yes"
```

## Scan and Rescan Notes

Audiobookshelf scans its configured library folders (`/audiobooks/main` and
`/audiobooks/private`) on its own schedule and from the web UI. After copying a
book, use the Audiobookshelf UI to rescan the affected library if it does not
appear promptly.

If automating scans later, prefer the Audiobookshelf API over direct database
writes. Confirm the current API endpoint and authentication method against the
installed Audiobookshelf version before scripting it.

## Service Checks

Check the service and local HTTP endpoint on the NUC:

```bash
ssh nuc 'systemctl status audiobookshelf.service --no-pager -l'
ssh nuc 'systemctl is-active audiobookshelf.service'
ssh nuc 'curl -fsS -I http://localhost:13378/ | sed -n "1,10p"'
```

Expected smoke-check result: `systemctl is-active` prints `active`, and the curl
request returns `HTTP/1.1 200 OK`.

## DB/API Notes

Audiobookshelf state lives under `/var/lib/audiobookshelf` on the NUC. The
SQLite database is currently at:

```bash
/var/lib/audiobookshelf/config/absdatabase.sqlite
```

Useful read-only inspection commands:

```bash
ssh nuc "sqlite3 /var/lib/audiobookshelf/config/absdatabase.sqlite '.tables'"
ssh nuc "sqlite3 -header -column /var/lib/audiobookshelf/config/absdatabase.sqlite 'select id,name,mediaType,lastScan from libraries; select libraryId,path from libraryFolders;'"
```

Do not mutate the database directly for scan automation unless there is no
supported API path and the migration risk has been reviewed. API calls without a
valid token return `401`; if automation becomes necessary, create or locate a
proper Audiobookshelf API token and document the endpoint, token storage, and
failure behavior here.
