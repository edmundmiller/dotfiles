import Base
import ./common.bend as C
import ./closeout.bend as Closeout
import ./github-policy.bend as GitHub
import ./policy.bend as Policy

type Publication is Data:
  Publication{source: String, remote: String, url: String, branch: String, clone: String, revisions: List<&2, String>}

type Step is Data:
  Finished{payload: String}
  Retry{initial: List<&2, C.Entry>}

def redact_words(words: List<&2, String>) -> List<&2, String>:
  match words:
    case Nil{}:
      []
    case Con{+word, tail}:
      C.choose(String, String.contains(word, "://"), "<redacted-url>", word) <> redact_words(tail)

def redact(text: String) -> String:
  String.join(redact_words(String.split(text, ' ')), " ")

def diagnostics(result: C.Command) -> String:
  C.Command{code, out, err} = result
  redact(String.trim(out ++ "\n" ++ err))

def bypass(+text: String) -> Bool:
  +lower = String.to_lower(text)
  String.contains(lower, "bypass") || String.contains(lower, "rule violations")
    || (String.contains(lower, "protected branch") && (String.contains(lower, "hook declined") || String.contains(lower, "failed")))

def non_fast_forward(text: String) -> Bool:
  +lower = String.to_lower(text)
  String.contains(lower, "non-fast-forward") || String.contains(lower, "fetch first")

def unique(revisions: List<&2, String>, +seen: List<&2, String>) -> Bool:
  match revisions:
    case Nil{}:
      True{}
    case Con{+revision, tail}:
      Bool.not(C.has(seen, revision)) && unique(tail, revision <> seen)

def remote_candidates(names: List<&2, String>, +source: String) -> C.Task(List<&2, String>):
  match names:
    case Nil{}:
      C.Task.pure(List<&2, String>, [])
    case Con{+name, tail}:
      do C.Task<List<&2, String>>:
        head : String <- C.git_optional(source, ["symbolic-ref", "refs/remotes/" ++ name ++ "/HEAD"])
        +rest : List<&2, String> <- remote_candidates(tail, source)
        return C.choose(List<&2, String>, C.nonempty(head), name <> rest, rest)

def select_remote(+requested: String, +upstream: String, +names: List<&2, String>, +candidates: List<&2, String>) -> C.Task(String):
  do C.Task<String>:
    C.require(String.is_empty(requested) || C.has(names, requested), "requested remote is not configured")
    +upstream_name : String = C.first(String.split(upstream, '/'))
    +remote : String = C.choose(String, C.nonempty(requested), requested,
      C.choose(String, C.has(names, upstream_name), upstream_name,
        C.choose(String, Nat.is_eq(List.length(&2, String, candidates), 1n), C.first(candidates),
          C.choose(String, Nat.is_eq(List.length(&2, String, names), 1n), C.first(names), ""))))
    C.require(C.nonempty(remote), "cannot discover a unique remote; pass --remote")
    return remote

def discover_remote(+source: String, requested: String) -> C.Task(String):
  do C.Task<String>:
    names_text : String <- C.git_output(source, ["remote"])
    +names : List<&2, String> = C.lines(names_text)
    upstream : String <- C.git_optional(source, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"])
    candidates : List<&2, String> <- remote_candidates(names, source)
    select_remote(requested, upstream, names, candidates)

def branch_from_lines(lines: List<&2, String>) -> String:
  match lines:
    case Nil{}:
      ""
    case Con{+line, tail}:
      C.choose(String, String.starts_with(line, "ref: refs/heads/") && String.ends_with(line, "\tHEAD"),
        String.drop(C.first(String.split(line, '\t')), String.length("ref: refs/heads/")), branch_from_lines(tail))

def discover_branch(+requested: String, url: String) -> C.Task(String):
  match requested:
    case SNil{}:
      do C.Task<String>:
        text : String <- C.git_output(".", ["ls-remote", "--symref", url, "HEAD"])
        +branch : String = branch_from_lines(C.lines(text))
        C.require(C.nonempty(branch), "cannot discover default branch; pass --default-branch")
        return branch
    case SCon{h, t}:
      C.Task.pure(String, requested)

def fetch_revisions(revisions: List<&2, String>, +clone: String, +source: String) -> C.Task(Unit):
  match revisions:
    case Nil{}:
      C.Task.pure(Unit, Unit{})
    case Con{revision, tail}:
      do C.Task<Unit>:
        fetched : String <- C.git_output(clone, ["fetch", "--no-tags", source, revision])
        fetch_revisions(tail, clone, source)

def replay_one(unlanded: Bool, clone: String, revision: String) -> C.Task(Unit):
  match unlanded:
    case False{}:
      C.Task.pure(Unit, Unit{})
    case True{}:
      do C.Task<Unit>:
        picked : String <- C.git_output(clone, ["cherry-pick", "--no-edit", revision])
        return Unit{}

def replay(items: List<&2, C.Entry>, +clone: String) -> C.Task(Unit):
  match items:
    case Nil{}:
      C.Task.pure(Unit, Unit{})
    case Con{C.Entry{revision, evidence}, tail}:
      do C.Task<Unit>:
        replay_one(String.eq(evidence, "unlanded"), clone, revision)
        replay(tail, clone)

def authoritative_tip(url: String, branch: String) -> C.Task(String):
  do C.Task<String>:
    text : String <- C.git_output(".", ["ls-remote", "--exit-code", url, "refs/heads/" ++ branch])
    +tip : String = C.first(String.split(C.first(C.lines(text)), '\t'))
    C.require(C.nonempty(tip), "authoritative remote has no destination branch")
    return tip

def final_records(items: List<&2, C.Entry>, +initial: List<&2, C.Entry>) -> List<&2, String>:
  match items:
    case Nil{}:
      []
    case Con{C.Entry{+revision, evidence}, tail}:
      C.object([C.field("revision", C.quote(revision)), C.field("evidence", C.quote(evidence)),
        C.field("initialEvidence", C.quote(C.first(C.option_values(initial, revision))))]) <> final_records(tail, initial)

def verify(+publication: Publication, initial: List<&2, C.Entry>) -> C.Task(String):
  Publication{source, remote, url, branch, clone, revisions} = publication
  do C.Task<String>:
    fetched : String <- C.git_output(clone, ["fetch", "--no-tags", "origin", branch])
    +local_tip : String <- C.git_output(clone, ["rev-parse", branch])
    +remote_tip : String <- authoritative_tip(url, branch)
    C.require(String.eq(local_tip, remote_tip), "publication verification mismatch: local and authoritative remote tips differ")
    +items : List<&2, C.Entry> <- Closeout.classify_all(revisions, clone, "origin/" ++ branch)
    C.require(List.is_empty(&2, String, Closeout.missing(items)), "published tip does not contain task revisions")
    return C.object([C.field("remote", C.quote(remote)), C.field("defaultBranch", C.quote(branch)), C.field("sourceRepository", C.quote(source)),
      C.field("taskRevisions", C.array(final_records(items, initial))), C.field("integratedTip", C.quote(local_tip)), C.field("remoteTip", C.quote(remote_tip))])

def merge_json(+left: String, right: String) -> String:
  String.take(left, Nat.sub(String.length(left), 1n)) ++ "," ++ String.drop(right, 1n)

def verified_result(result: Result<&1, &1, String, String>, metadata: String) -> Step:
  match result:
    case Done{proof}:
      Finished{merge_json(metadata, proof)}
    case Fail{error}:
      Finished{merge_json(metadata, C.object([C.field("error", C.quote(error))]))}

def verified(+publication: Publication, initial: List<&2, C.Entry>, metadata: String) -> C.Task(Step):
  do IO<Result<&1, &1, String, Step>>:
    result : Result<&1, &1, String, String> <- verify(publication, initial)
    C.Task.pure(Step, verified_result(result, metadata))

def contains_ancestor(clone: String, candidate: String, target: String) -> C.Task(Bool):
  do IO<Result<&1, &1, String, Bool>>:
    result : C.Command <- C.git(clone, ["merge-base", "--is-ancestor", candidate, target])
    C.Task.pure(Bool, C.succeeded(result))

def contains_after_fetch(+publication: Publication, candidate: String) -> C.Task(Bool):
  Publication{source, remote, url, branch, clone, revisions} = publication
  do C.Task<Bool>:
    fetched : String <- C.git_output(clone, ["fetch", "--no-tags", "origin", branch])
    contains_ancestor(clone, candidate, "origin/" ++ branch)

def reconcile_tip(equal: Bool, acknowledged: Bool, publication: Publication, candidate: String) -> C.Task(Bool):
  match equal acknowledged:
    case True{} _:
      C.Task.pure(Bool, True{})
    case False{} True{}:
      C.Task.pure(Bool, True{})
    case False{} False{}:
      contains_after_fetch(publication, candidate)

def reconcile(+publication: Publication, +candidate: String, acknowledged: Bool) -> C.Task(Bool):
  Publication{source, remote, url, branch, clone, revisions} = publication
  do C.Task<Bool>:
    tip : String <- authoritative_tip(url, branch)
    reconcile_tip(String.eq(tip, candidate), acknowledged, publication, candidate)

def after_reconcile(completed: Bool, retry: Bool, publication: Publication, initial: List<&2, C.Entry>, diag: String, metadata: String) -> C.Task(Step):
  match completed retry:
    case True{} _:
      verified(publication, initial, merge_json(metadata, "{\"status\":\"published\",\"published\":true}"))
    case False{} True{}:
      C.Task.pure(Step, Retry{initial})
    case False{} False{}:
      C.Task.fail(Step, "normal push rejected: " ++ diag)

def reconciled(result: Result<&1, &1, String, Bool>, publication: Publication, initial: List<&2, C.Entry>, +acknowledged: Bool, +violated: Bool, +diag: String, +metadata: String, remaining: Bool) -> C.Task(Step):
  match result:
    case Fail{error}:
      C.Task.pure(Step, Finished{merge_json(metadata, C.object([C.field("status", C.quote(Policy.publication_status(False{}, acknowledged))),
        C.field("published", C.choose(String, acknowledged, "true", "null")), C.field("error", C.quote(error))]))})
    case Done{+completed}:
      after_reconcile(completed || acknowledged, Policy.retry(completed || acknowledged, violated, non_fast_forward(diag), remaining), publication, initial, diag, metadata)

def pushed(+result: C.Command, +publication: Publication, initial: List<&2, C.Entry>, candidate: String, policy: String, attempts: Nat, remaining: Bool) -> C.Task(Step):
  C.Command{code, out, err} = result
  +diag = diagnostics(result)
  +violated = bypass(diag)
  +acknowledged = U32.is_zero(code)
  metadata = C.object([C.field("policy", C.choose(String, violated, "{\"compliant\":false,\"reason\":\"push reported a policy bypass\"}", policy)),
    C.field("pushDiagnostics", C.quote(diag)), C.field("pushExitCode", U32.show(code)), C.field("attempts", Nat.show(attempts))])
  do IO<Result<&1, &1, String, Step>>:
    reconciled_state : Result<&1, &1, String, Bool> <- reconcile(publication, candidate, acknowledged)
    reconciled(reconciled_state, publication, initial, acknowledged, violated, diag, metadata, remaining)

def push(+publication: Publication, initial: List<&2, C.Entry>, +candidate: String, policy: String, attempts: Nat, remaining: Bool) -> C.Task(Step):
  Publication{source, remote, url, branch, clone, revisions} = publication
  do IO<Result<&1, &1, String, Step>>:
    result : C.Command <- C.git(clone, ["push", "origin", "HEAD:refs/heads/" ++ branch])
    pushed(result, publication, initial, candidate, policy, attempts, remaining)

def publish_missing(has_unlanded: Bool, +publication: Publication, initial: List<&2, C.Entry>, attempts: Nat, remaining: Bool) -> C.Task(Step):
  match has_unlanded:
    case False{}:
      verified(publication, initial, C.object([C.field("status", C.quote("already-landed")), C.field("published", "true"),
        C.field("policy", "{\"compliant\":null,\"reason\":\"historical publication policy not verified\"}"), C.field("attempts", Nat.show(attempts))]))
    case True{}:
      Publication{source, remote, url, branch, clone, revisions} = publication
      do C.Task<Step>:
        +candidate : String <- C.git_output(clone, ["rev-parse", "HEAD"])
        policy : String <- GitHub.preflight(clone, url, branch, candidate)
        push(publication, initial, candidate, policy, attempts, remaining)

def prepare_attempt(retry: Bool, +clone: String, +branch: String) -> C.Task(Unit):
  match retry:
    case False{}:
      C.Task.pure(Unit, Unit{})
    case True{}:
      do C.Task<Unit>:
        fetched : String <- C.git_output(clone, ["fetch", "--no-tags", "origin", branch])
        reset : String <- C.git_output(clone, ["reset", "--hard", "origin/" ++ branch])
        return Unit{}

def attempt_step(+publication: Publication, +initial: List<&2, C.Entry>, +attempts: Nat, remaining: Bool) -> C.Task(Step):
  Publication{source, remote, url, branch, clone, revisions} = publication
  do C.Task<Step>:
    prepare_attempt(Nat.is_gt(attempts, 1n), clone, branch)
    +items : List<&2, C.Entry> <- Closeout.classify_all(revisions, clone, "origin/" ++ branch)
    +first : List<&2, C.Entry> = C.choose(List<&2, C.Entry>, List.is_empty(&2, C.Entry, initial), items, initial)
    replay(items, clone)
    publish_missing(Bool.not(List.is_empty(&2, String, Closeout.missing(items))), publication, first, attempts, remaining)

def continue_attempt(step: Step, again: List<&2, C.Entry> -> C.Task(String)) -> C.Task(String):
  match step:
    case Finished{payload}:
      C.Task.pure(String, payload)
    case Retry{initial}:
      again(initial)

def attempts(remaining: Nat, +publication: Publication, initial: List<&2, C.Entry>, +number: Nat) -> C.Task(String):
  match remaining:
    case 0n:
      C.Task.fail(String, "remote kept advancing after one retry")
    case 1n+ +rest:
      do C.Task<String>:
        step : Step <- attempt_step(publication, initial, number, Nat.is_gt(rest, 0n))
        continue_attempt(step, next => attempts(rest, publication, next, 1n+number))

def clone_publish(+publication: Publication) -> C.Task(String):
  Publication{source, remote, url, branch, clone, revisions} = publication
  do C.Task<String>:
    cloned : String <- C.git_output(".", ["clone", "--no-tags", "--single-branch", "--branch", branch, url, clone])
    fetch_revisions(revisions, clone, source)
    attempts(2n, publication, [], 1n)

def with_temporary(+temporary: String, source: String, remote: String, url: String, branch: String, revisions: List<&2, String>) -> C.Task(String):
  do IO<Result<&1, &1, String, String>>:
    result : Result<&1, &1, String, String> <- clone_publish(Publication{source, remote, url, branch, temporary ++ "/repository", revisions})
    cleanup : C.Command <- C.run("rm", ["-rf", "--", temporary], "")
    return result

def publish(+options: C.Options) -> C.Task(String):
  do C.Task<String>:
    C.require(C.nonempty(C.option(options, "--source-repo", "")), "--source-repo is required")
    +source : String <- C.git_output(C.option(options, "--source-repo", ""), ["rev-parse", "--show-toplevel"])
    +remote : String <- discover_remote(source, C.option(options, "--remote", ""))
    +url : String <- C.git_output(source, ["remote", "get-url", remote])
    branch : String <- discover_branch(C.option(options, "--default-branch", ""), url)
    +revisions : List<&2, String> <- Closeout.resolve(C.values(options, "--task-revision"), source)
    C.require(Bool.not(List.is_empty(&2, String, revisions)) && unique(revisions, []), "explicit, non-repeated task revisions are required")
    temporary : String <- C.output("mktemp", ["-d", "-t", "done-publish.XXXXXXXX"], "")
    with_temporary(temporary, source, remote, url, branch, revisions)

def arguments(args: List<String>) -> C.Task(String):
  do C.Task<String>:
    options : C.Options <- C.parse_options(args, ["--source-repo", "--task-revision", "--remote", "--default-branch"], [])
    publish(options)

def finish(result: Result<&1, &1, String, String>) -> IO(Unit):
  match result:
    case Fail{message}:
      do IO<Unit>:
        IO.print(C.object([C.field("status", C.quote("blocked")), C.field("error", C.quote(message))]))
        IO.exit(1)
    case Done{+payload}:
      do IO<Unit>:
        IO.print(payload)
        IO.exit(C.choose(U32, String.contains(payload, "\"error\":") || String.contains(payload, "\"compliant\":false") || String.contains(payload, "publication-unknown"), 1, 0))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    result : Result<&1, &1, String, String> <- arguments(List.tail(&1, String, args))
    finish(result)
