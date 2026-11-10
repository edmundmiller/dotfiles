import Base
import ./os.bend as OS
import ./nuc-effects.bend as Effects
import ./nuc-plan.bend as Plan

def post_deploy_check(target: Effects.ExecutionTarget, check: Plan.PostDeployCheck) -> IO(Unit):
  match check:
    case Plan.NoPostCheck{}:
      IO.pure(Unit, Unit{})
    case Plan.ObserveServices{}:
      do IO<Unit>:
        IO.print("=== post-deploy Hermes/gateway observations ===")
        +shared : Effects.ExecutionTarget = target
        service : OS.ProcessResult <- Effects.run_command(shared, ["systemctl", "is-active", "hermes-agent.service"], False{})
        units : OS.ProcessResult <- Effects.run_command(shared, ["systemctl", "--no-pager", "--plain", "list-units", "hermes*.service"], False{})
        IO.pure(Unit, Unit{})
