import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./repository-policy.bend as Repository
import ./nuc-policy.bend as Policy
import ./nuc-identity.bend as Identity

def snapshot_user() -> IO(String):
  Identity.snapshot_user()

def observed_source(head: Repository.GitRevision, base: Repository.GitRevision, owner: String, clean: Bool) -> Policy.SnapshotSource:
  match clean:
    case True{}:
      Policy.CommittedSource{Policy.CleanSource{head, base, owner}}
    case False{}:
      Policy.WorktreeSource{head, base, owner}

def source_status(head: Repository.GitRevision, base: Repository.GitRevision, owner: String, result: OS.ProcessResult) -> IO(Policy.SnapshotSource):
  match result:
    case OS.ProcessResult{0, out, error}:
      IO.pure(Policy.SnapshotSource, observed_source(head, base, owner, String.is_empty(String.trim(out))))
    case OS.ProcessResult{status, out, error}:
      IO.die(Policy.SnapshotSource, status, "Could not inspect NUC source cleanliness")

def source_owner_value(user: String, hostname: String, override: String) -> String:
  match override:
    case SNil{}:
      user ++ "@" ++ hostname
    case host:
      user ++ "@" ++ host

def source_owner(user: String, hostname: String) -> IO(String):
  do IO<String>:
    override : String <- OS.env("HOSTNAME")
    return source_owner_value(user, hostname, String.trim(override))

def observe_source(+root: String, hostname: String, user: String) -> IO(Policy.SnapshotSource):
  do IO<Policy.SnapshotSource>:
    head_text : String <- OS.output(["git", "-C", root, "rev-parse", "HEAD"])
    head : Repository.GitRevision <- Repository.require_revision(head_text)
    base_text : String <- OS.output(["git", "-C", root, "merge-base", "HEAD", "origin/main"])
    base : Repository.GitRevision <- Repository.require_revision(base_text)
    owner : String <- source_owner(user, hostname)
    status : OS.ProcessResult <- OS.run(["git", "-C", root, "status", "--porcelain=v1", "--untracked-files=normal"], True{})
    source_status(head, base, owner, status)
