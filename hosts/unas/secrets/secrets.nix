let
  key =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINrCDUEOwi4dVfqQweD4a6roNi9hWtZQ2lB2trKet5dS edmund.a.miller@gmail.com";
in {
  "minio-rootCredentials.age".publicKeys = [ key ];
  "qb.age".publicKeys = [ key ];
  "paperless-adminCredentials.age".publicKeys = [ key ];
}
