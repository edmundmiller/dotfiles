import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./resources.bend as Resources
import ./repository-policy.bend as Repository
import ./nuc-policy.bend as Policy
import ./nuc-effects.bend as Effects

type SnapshotIdentity is Data:
  SnapshotIdentity{directory: String, user: String, target: Effects.ExecutionTarget, intent: Policy.DeploymentIntent}

type SnapshotLease is Type:
  SnapshotLease{cleanup: U32}

type AcquiredSnapshot is Type:
  AcquiredSnapshot{release: String, lease: SnapshotLease}

type SnapshotDescription is Data:
  SnapshotDescription{identity: SnapshotIdentity, digest: Repository.GitRevision, release: String}

type PreparedSnapshot is Type:
  PreparedSnapshot{description: SnapshotDescription, lease: SnapshotLease}

def snapshot_directory(head: Repository.GitRevision, user: String, phase: String, nonce: String) -> String:
  match head:
    case Repository.GitRevision{revision}:
      Policy.snapshot_storage_root() ++ "/dotfiles-worktree-" ++ user ++ "-" ++ revision ++ "-" ++ phase ++ "-" ++ nonce

def snapshot_identity(+user: String, target: Effects.ExecutionTarget, +intent: Policy.DeploymentIntent) -> IO(SnapshotIdentity):
  do IO<SnapshotIdentity>:
    nonce : String <- Posix.random_uuid()
    +source : Policy.SnapshotSource = Policy.intent_source(intent)
    directory : String = snapshot_directory(Policy.source_head(source), user, Policy.source_phase(source), nonce)
    return SnapshotIdentity{directory, user, target, intent}

def release_command(+root: String, identity: SnapshotIdentity) -> IO(String):
  match identity:
    case SnapshotIdentity{directory, user, target, intent}:
      do IO<String>:
        pruner : String <- Posix.read_text(root ++ "/bin/prune-nuc-deploy-snapshots")
        Effects.worker_command(root, "nuc-release.sh", [directory, user, Policy.snapshot_storage_root(), "5", pruner])

def acquire_snapshot_lease(+root: String, +identity: SnapshotIdentity) -> IO(AcquiredSnapshot):
  match identity:
    case SnapshotIdentity{+directory, user, +target, intent}:
      do IO<AcquiredSnapshot>:
        Effects.checked_input(target, ["bash", "-s", "--", Policy.snapshot_storage_root(), user, "4"], root ++ "/bin/prune-nuc-deploy-snapshots")
        Effects.checked_command(target, ["mkdir", "--", directory])
        +command : String <- release_command(root, identity)
        cleanup : U32 <- Resources.defer_command(Effects.shell_argv(target, command))
        Effects.checked_command(target, ["touch", directory ++ "/.nuc-deploy-active"])
        return AcquiredSnapshot{command, SnapshotLease{cleanup}}

def checked_git_environment(root: String, args: List<&2, String>, index: String) -> IO(Unit):
  do IO<Unit>:
    result : OS.ProcessResult <- OS.run_with_environment(OS.linear_arguments("git" <> "-C" <> root <> args), False{}, "GIT_INDEX_FILE", index)
    OS.check(result)

def capture_dirty_tree(+root: String, revision: Repository.GitRevision, +index: String) -> IO(Repository.GitRevision):
  match revision:
    case Repository.GitRevision{head}:
      do IO<Repository.GitRevision>:
        checked_git_environment(root, ["read-tree", head], index)
        checked_git_environment(root, ["add", "-A", "--", "."], index)
        result : OS.ProcessResult <- OS.run_with_environment(["git", "-C", root, "write-tree"], True{}, "GIT_INDEX_FILE", index)
        value : String <- OS.output_value(result)
        Repository.require_revision(value)

def source_digest(root: String, source: Policy.SnapshotSource, index: String) -> IO(Repository.GitRevision):
  match source:
    case Policy.CommittedSource{Policy.CleanSource{Repository.GitRevision{head}, base, owner}}:
      do IO<Repository.GitRevision>:
        value : String <- OS.output(["git", "-C", root, "rev-parse", head ++ "^{tree}"])
        Repository.require_revision(value)
    case Policy.WorktreeSource{head, base, owner}:
      capture_dirty_tree(root, head, index)

def archive_revision(source: Policy.SnapshotSource, digest: Repository.GitRevision) -> String:
  match source digest:
    case Policy.CommittedSource{Policy.CleanSource{Repository.GitRevision{head}, base, owner}} digest:
      head
    case source Repository.GitRevision{tree}:
      tree

def unchanged_value(equal: Bool) -> IO(Unit):
  match equal:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "NUC snapshot source changed while it was being transferred; retry from a stable worktree")

def require_unchanged(expected: Repository.GitRevision, observed: Repository.GitRevision) -> IO(Unit):
  match expected observed:
    case Repository.GitRevision{left} Repository.GitRevision{right}:
      unchanged_value(String.eq(left, right))

def verify_source_after_transfer(root: String, source: Policy.SnapshotSource, digest: Repository.GitRevision, index: String) -> IO(Unit):
  match source:
    case Policy.CommittedSource{clean}:
      IO.pure(Unit, Unit{})
    case Policy.WorktreeSource{head, base, owner}:
      do IO<Unit>:
        observed : Repository.GitRevision <- capture_dirty_tree(root, head, index)
        require_unchanged(digest, observed)

def transfer_snapshot(+root: String, identity: SnapshotIdentity) -> IO(Repository.GitRevision):
  match identity:
    case SnapshotIdentity{directory, user, target, intent}:
      do IO<Repository.GitRevision>:
        +temporary : String <- Posix.temporary_directory()
        +index : String = temporary ++ "/index"
        +archive : String = temporary ++ "/snapshot.tar"
        +source : Policy.SnapshotSource = Policy.intent_source(intent)
        +digest : Repository.GitRevision <- source_digest(root, source, index)
        revision : String = archive_revision(source, digest)
        OS.checked(["git", "-C", root, "archive", "--format=tar", "--output", archive, revision])
        Effects.checked_input(target, ["tar", "--exclude=.nuc-deploy-active", "-xf", "-", "-C", directory], archive)
        verify_source_after_transfer(root, source, digest, index)
        return digest

def write_revision_marker(identity: SnapshotIdentity) -> IO(Unit):
  match identity:
    case SnapshotIdentity{+directory, user, +target, intent}:
      Effects.checked_command(target, ["bash", directory ++ "/bin/write-nuc-deploy-revision", directory, Policy.source_revision(Policy.intent_source(intent))])

def finish_preparation(+root: String, +identity: SnapshotIdentity, acquired: AcquiredSnapshot) -> IO(PreparedSnapshot):
  match acquired:
    case AcquiredSnapshot{release, lease}:
      do IO<PreparedSnapshot>:
        digest : Repository.GitRevision <- transfer_snapshot(root, identity)
        write_revision_marker(identity)
        return PreparedSnapshot{SnapshotDescription{identity, digest, release}, lease}

def prepare_snapshot(+root: String, +identity: SnapshotIdentity) -> IO(PreparedSnapshot):
  do IO<PreparedSnapshot>:
    acquired : AcquiredSnapshot <- acquire_snapshot_lease(root, identity)
    finish_preparation(root, identity, acquired)

def handoff_lease(lease: SnapshotLease) -> IO(Unit):
  match lease:
    case SnapshotLease{cleanup}:
      Resources.cancel_cleanup(cleanup)
