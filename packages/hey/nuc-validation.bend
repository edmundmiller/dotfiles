import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./task-text.bend as Text
import ./remote-arguments.bend as Remote
import ./nuc-policy.bend as Policy
import ./nuc-plan.bend as Plan
import ./nuc-effects.bend as Effects
import ./repository-policy.bend as Repository

type ValidationInput is Data:
  ValidationInput{directory: String, revision: String, digest: Repository.GitRevision, release: String}

type ValidationReport is Data:
  ValidationReport{directory: String, unit: String}

def runner_command(root: String, description: ValidationInput, report: ValidationReport, +resources: Plan.ValidationResources) -> IO(String):
  match description report:
    case ValidationInput{directory, revision, Repository.GitRevision{digest}, release} ValidationReport{report_dir, unit}:
      Effects.worker_command(root, "nuc-validation.sh", List.append(&2, String, [directory, digest, report_dir, Plan.validation_meminfo(), Plan.validation_minimum_kib(resources), Plan.validation_nix_config(resources), Policy.snapshot_storage_root() ++ "/dotfiles-nuc-validation.lock"], Plan.validation_gates()))

def finalizer_command(root: String, description: ValidationInput, report_dir: String) -> IO(String):
  match description:
    case ValidationInput{directory, revision, digest, release}:
      Effects.worker_command(root, "nuc-validation-finalizer.sh", [report_dir, release])

def service_command(+root: String, +description: ValidationInput, +report: ValidationReport, +resources: Plan.ValidationResources) -> IO(String):
  match report:
    case ValidationReport{directory, unit}:
      do IO<String>:
        finalizer : String <- finalizer_command(root, description, directory)
        encoded : String <- Effects.encode_program(finalizer)
        runner : String <- runner_command(root, description, report, resources)
        stop_post : String = "--property=ExecStopPost=/bin/sh -c \"printf '%s' '" ++ encoded ++ "' | base64 --decode | bash\""
        argv : List<&2, String> = List.concat(&2, String, [["systemd-run", "--user", "--wait", "--collect", "--unit=" ++ unit], Plan.validation_properties(resources), [stop_post, "bash", "-c", runner]])
        return Text.concat_task_text(["uid=\"$(id -u)\"; export XDG_RUNTIME_DIR=\"${XDG_RUNTIME_DIR:-/run/user/$uid}\"; export DBUS_SESSION_BUS_ADDRESS=\"${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}\"; ", Remote.quote_command(argv)])

def submission_command(root: String, description: ValidationInput, report: ValidationReport, resources: Plan.ValidationResources, service: String) -> IO(String):
  match description report:
    case ValidationInput{directory, revision, Repository.GitRevision{digest}, release} ValidationReport{report_dir, unit}:
      Effects.worker_command(root, "nuc-validation-submission.sh", [directory, revision, digest, report_dir, unit, service, release, Plan.validation_memory_description(resources)])

def render_submission(+root: String, +description: ValidationInput, +report: ValidationReport) -> IO(String):
  do IO<String>:
    +resources : Plan.ValidationResources = Plan.validation_resources()
    service : String <- service_command(root, description, report, resources)
    encoded : String <- Effects.encode_program(service)
    submission_command(root, description, report, resources, encoded)
