import Base
import ./nuc-policy.bend as Policy
import ./repository-policy.bend as Repository

type NucTask is Data:
  AutoNuc{action: Policy.NucAction}
  LocalNuc{}
  DelegateWorktree{action: Policy.NucAction}
  RevisionNuc{revision: Repository.GitRevision, guard: RevisionGuard}
  InvalidNucArguments{}

# exact: the SHA must still be live main. published: continuous rollout may
# activate a green commit main has passed, but it must remain reachable from main.
type RevisionGuard is Data:
  ExactMain{}
  PublishedMain{}

def parse_guard(value: String) -> Maybe<&2, RevisionGuard>:
  match value:
    case "exact":
      Some{ExactMain{}}
    case "published":
      Some{PublishedMain{}}
    case value:
      None{}

def delegated_request(action: Maybe<&2, Policy.NucAction>) -> NucTask:
  match action:
    case Some{operation}:
      DelegateWorktree{operation}
    case None{}:
      InvalidNucArguments{}

def auto_request(action: Maybe<&2, Policy.NucAction>) -> NucTask:
  match action:
    case Some{operation}:
      AutoNuc{operation}
    case None{}:
      InvalidNucArguments{}

def revision_request(revision: String, valid: Bool, guard: Maybe<&2, RevisionGuard>) -> NucTask:
  match valid guard:
    case True{} Some{selected}:
      RevisionNuc{Repository.GitRevision{revision}, selected}
    case valid guard:
      InvalidNucArguments{}

def auto_arguments(args: List<&2, String>) -> NucTask:
  match args:
    case Nil{}:
      AutoNuc{Policy.Activate{Policy.SwitchGeneration{}}}
    case mode <> Nil{}:
      auto_request(Policy.parse_action(mode))
    case args:
      InvalidNucArguments{}

def delegated_arguments(args: List<&2, String>) -> NucTask:
  match args:
    case Nil{}:
      DelegateWorktree{Policy.Activate{Policy.SwitchGeneration{}}}
    case mode <> Nil{}:
      delegated_request(Policy.parse_action(mode))
    case args:
      InvalidNucArguments{}

def local_arguments(args: List<&2, String>) -> NucTask:
  match args:
    case Nil{}:
      LocalNuc{}
    case args:
      InvalidNucArguments{}

def revision_arguments(args: List<&2, String>) -> NucTask:
  match args:
    case +revision <> Nil{}:
      revision_request(revision, Repository.valid_revision(revision), Some{ExactMain{}})
    case +revision <> guard <> Nil{}:
      revision_request(revision, Repository.valid_revision(revision), parse_guard(guard))
    case args:
      InvalidNucArguments{}

def direct_arguments(action: Maybe<&2, Policy.NucAction>, args: List<&2, String>) -> NucTask:
  match action args:
    case Some{operation} Nil{}:
      DelegateWorktree{operation}
    case action args:
      InvalidNucArguments{}

def nuc_mode_request(mode: String, args: List<&2, String>) -> NucTask:
  match mode:
    case "auto":
      auto_arguments(args)
    case "local":
      local_arguments(args)
    case "wt":
      delegated_arguments(args)
    case "worktree":
      delegated_arguments(args)
    case "revision":
      revision_arguments(args)
    case mode:
      direct_arguments(Policy.parse_action(mode), args)

def nuc_arguments(args: List<&2, String>) -> NucTask:
  match args:
    case Nil{}:
      AutoNuc{Policy.Activate{Policy.SwitchGeneration{}}}
    case mode <> rest:
      nuc_mode_request(mode, rest)

def task_request(name: String, args: List<&2, String>) -> NucTask:
  match name:
    case "nuc":
      nuc_arguments(args)
    case name:
      InvalidNucArguments{}
