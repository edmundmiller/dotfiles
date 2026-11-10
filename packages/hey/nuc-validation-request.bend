import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./nuc-policy.bend as Policy
import ./nuc-plan.bend as Plan
import ./nuc-snapshot.bend as Snapshot
import ./repository-policy.bend as Repository
import ./nuc-validation.bend as Validation

def prepare_submission(root: String, description: Snapshot.SnapshotDescription) -> IO(String):
  match description:
    case Snapshot.SnapshotDescription{Snapshot.SnapshotIdentity{+directory, user, target, intent}, Repository.GitRevision{digest}, release}:
      do IO<String>:
        nonce : String <- Posix.random_uuid()
        +revision : String = Policy.source_revision(Policy.intent_source(intent))
        +report : String = Policy.snapshot_storage_root() ++ "/dotfiles-validation-" ++ user ++ "-" ++ revision ++ "-" ++ nonce
        +unit : String = Plan.validation_unit(directory)
        IO.print("NUC_VALIDATION_REPORT_DIR=" ++ report)
        IO.print("NUC_VALIDATION_UNIT=" ++ unit)
        Validation.render_submission(root, Validation.ValidationInput{directory, revision, Repository.GitRevision{digest}, release}, Validation.ValidationReport{report, unit})
