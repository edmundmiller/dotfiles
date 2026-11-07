import Base
import ./common.bend as C

def digest(text: String) -> C.Task(String):
  do C.Task<String>:
    hash : String <- C.output("sha256sum", [], text)
    return C.first(String.split(hash, ' '))

def untracked(paths: List<&2, String>, +repo: String) -> C.Task(List<&2, String>):
  match paths:
    case Nil{}:
      C.Task.pure(List<&2, String>, [])
    case Con{+path, rest}:
      do C.Task<List<&2, String>>:
        hash : String <- C.output("bash", ["-o", "pipefail", "-c", "if [ -L \"$1\" ]; then readlink -n -- \"$1\" | sha256sum; elif [ -f \"$1\" ]; then sha256sum < \"$1\"; else printf '' | sha256sum; fi", "done", repo ++ "/" ++ path], "")
        tail : List<&2, String> <- untracked(rest, repo)
        return C.object([C.field("path", C.quote(path)), C.field("sha256", C.quote(C.first(String.split(hash, ' '))))]) <> tail

def diff_hashes(diffs: String & String) -> C.Task(String & String):
  (staged, unstaged) = diffs
  C.parallel(String, String, digest(staged), digest(unstaged))

def working_json(status: String, status_hash: String, hashes: String & String, entries: List<&2, String>) -> String:
  (staged, unstaged) = hashes
  C.object([C.field("clean", C.json_bool(String.is_empty(status))),
    C.field("statusSha256", C.quote(status_hash)), C.field("stagedSha256", C.quote(staged)),
    C.field("unstagedSha256", C.quote(unstaged)), C.field("untracked", C.array(entries))])

def working_copy(+repo: String) -> C.Task(String):
  do C.Task<String>:
    +status : String <- C.git_raw(repo, ["status", "--porcelain=v1", "--untracked-files=all", "-z"])
    diffs : String & String <- C.parallel(String, String,
      C.git_raw(repo, ["diff", "--cached", "--binary", "--no-ext-diff"]),
      C.git_raw(repo, ["diff", "--binary", "--no-ext-diff"]))
    files : String <- C.git_raw(repo, ["ls-files", "--others", "--exclude-standard", "-z"])
    entries : List<&2, String> <- untracked(List.filter(~String, ~C.nonempty, String.split(files, '\0')), repo)
    hashes : String & String <- diff_hashes(diffs)
    status_hash : String <- digest(status)
    return working_json(status, status_hash, hashes, entries)

def destination_json(remote: String, branch: String, ref: String, tip: String) -> String:
  C.object([C.field("remote", C.string_or_null(remote)), C.field("defaultBranch", C.string_or_null(branch)),
    C.field("remoteRef", C.string_or_null(ref)), C.field("remoteTip", C.string_or_null(tip))])

def destination_finish(+repo: String, +remote: String, +branch: String) -> C.Task(String):
  do C.Task<String>:
    C.require(String.is_empty(remote) || C.nonempty(branch), "cannot discover the default branch; set its symbolic HEAD")
    +ref : String = C.choose(String, C.nonempty(remote) && C.nonempty(branch), remote ++ "/" ++ branch, "")
    tip : String <- C.git_optional(repo, ["rev-parse", ref])
    return destination_json(remote, branch, ref, tip)

def destination_fallback(+repo: String, +remote: String, symbolic: String) -> C.Task(String):
  match symbolic:
    case SNil{}:
      do C.Task<String>:
        main_ref : String <- C.git_optional(repo, ["show-ref", "--verify", "refs/heads/main"])
        master_ref : String <- C.git_optional(repo, ["show-ref", "--verify", "refs/heads/master"])
        branch : String = C.choose(String, C.nonempty(main_ref), "main", C.choose(String, C.nonempty(master_ref), "master", ""))
        destination_finish(repo, remote, branch)
    case SCon{h, t}:
      destination_finish(repo, remote, String.drop(SCon{h, t}, String.length("refs/remotes/" ++ remote ++ "/")))

def destination_upstream(+repo: String, +upstream: String) -> C.Task(String):
  match upstream:
    case SNil{}:
      do C.Task<String>:
        names : String <- C.git_output(repo, ["remote"])
        +remote : String = C.first(C.lines(names))
        symbolic : String <- C.git_optional(repo, ["symbolic-ref", "refs/remotes/" ++ remote ++ "/HEAD"])
        destination_fallback(repo, remote, symbolic)
    case SCon{h, t}:
      +remote = C.first(String.split(upstream, '/'))
      destination_finish(repo, remote, String.drop(upstream, 1n+String.length(remote)))

def destination(+repo: String) -> C.Task(String):
  do C.Task<String>:
    upstream : String <- C.git_optional(repo, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"])
    destination_upstream(repo, upstream)

def receipt(+path: String) -> C.Task(String):
  match path:
    case SNil{}:
      C.Task.pure(String, "null")
    case SCon{h, t}:
      do C.Task<String>:
        +absolute : String <- C.output("realpath", ["-e", "--", path], "")
        C.output("jq", ["-ce", "select(type == \"object\" and (.schemaVersion == 1 or .schemaVersion == 2)) | {path:$path,schemaVersion,runId,status,closeoutStatus:.closeout.status}", "--arg", "path", absolute, absolute], "")

def git_snapshot(+repo: String, active: String, receipt_path: String) -> C.Task(String):
  do C.Task<String>:
    head : String <- C.git_output(repo, ["rev-parse", "HEAD"])
    branch : String <- C.git_optional(repo, ["branch", "--show-current"])
    git_dir : String <- C.git_output(repo, ["rev-parse", "--path-format=absolute", "--git-dir"])
    common_dir : String <- C.git_output(repo, ["rev-parse", "--path-format=absolute", "--git-common-dir"])
    dest : String <- destination(repo)
    work : String <- working_copy(repo)
    recorded : String <- receipt(receipt_path)
    return C.object([C.field("schemaVersion", "1"), C.field("backend", C.quote("git")),
      C.field("repositoryRoot", C.quote(repo)), C.field("workspaceRoot", C.quote(repo)), C.field("activeDirectory", C.quote(active)),
      C.field("vcs", C.object([C.field("head", C.quote(head)), C.field("branch", C.string_or_null(branch)), C.field("isWorktree", C.json_bool(Bool.not(String.eq(git_dir, common_dir))))])),
      C.field("destination", dest), C.field("workingCopy", work), C.field("receipt", recorded)])

def jj_output(repo: String, args: List<String>) -> C.Task(String):
  C.output("jj", "--repository" <> repo <> "--ignore-working-copy" <> args, "")

def jj_index_git(+repo: String, git_dir: String, index: String, args: List<String>) -> C.Task(String):
  do IO<Result<&1, &1, String, String>>:
    result : C.Command <- C.run("env", ("GIT_INDEX_FILE=" ++ index) <> "GIT_OPTIONAL_LOCKS=0" <> "git" <> "-C" <> repo <> ("--git-dir=" ++ git_dir) <> ("--work-tree=" ++ repo) <> args, "")
    return C.raw_result(result)

def jj_filesystem_fingerprint(reads: String & String, repo: String, +status: String) -> C.Task(String):
  (+diff, +files) = reads
  do C.Task<String>:
    entries : List<&2, String> <- untracked(List.filter(~String, ~C.nonempty, String.split(files, '\0')), repo)
    hash : String <- digest(C.array([C.quote(status), C.quote(diff), C.array(entries)]))
    return C.object([C.field("clean", C.json_bool(String.contains(status, "The working copy has no changes.") && String.is_empty(diff) && String.is_empty(files))), C.field("statusSha256", C.quote(hash))])

def jj_filesystem_read(+repo: String, +git_dir: String, +index: String, commit: String, status: String) -> C.Task(String):
  do C.Task<String>:
    seeded : String <- jj_index_git(repo, git_dir, index, ["read-tree", commit])
    reads : String & String <- C.parallel(String, String,
      jj_index_git(repo, git_dir, index, ["diff", "--binary", "--no-ext-diff", "--no-textconv"]),
      jj_index_git(repo, git_dir, index, ["ls-files", "--others", "--exclude-standard", "--exclude=.jj/", "-z"]))
    jj_filesystem_fingerprint(reads, repo, status)

def jj_filesystem_temporary(+temporary: String, repo: String, git_dir: String, commit: String, status: String) -> C.Task(String):
  do IO<Result<&1, &1, String, String>>:
    result : Result<&1, &1, String, String> <- jj_filesystem_read(repo, git_dir, temporary ++ "/index", commit, status)
    cleanup : C.Command <- C.run("rm", ["-rf", "--", temporary], "")
    return result

def jj_filesystem(+repo: String, commit: String, status: String) -> C.Task(String):
  do C.Task<String>:
    git_dir : String <- jj_output(repo, ["git", "root"])
    temporary : String <- C.output("mktemp", ["-d", "-t", "done-jj-index.XXXXXXXX"], "")
    jj_filesystem_temporary(temporary, repo, git_dir, commit, status)

def jj_snapshot(+repo: String, active: String, receipt_path: String) -> C.Task(String):
  do C.Task<String>:
    +workspace : String <- jj_output(repo, ["workspace", "root"])
    +status : String <- jj_output(repo, ["status", "--color", "never"])
    revision : String <- jj_output(repo, ["log", "-r", "@", "--no-graph", "-T", "change_id ++ \"\\n\" ++ commit_id ++ \"\\n\""])
    remotes : String <- jj_output(repo, ["git", "remote", "list"])
    trunk : String <- jj_output(repo, ["log", "-r", "trunk()", "--no-graph", "-T", "bookmarks ++ \"\\n\""])
    recorded : String <- receipt(receipt_path)
    +revisions : List<&2, String> = C.lines(revision)
    work : String <- jj_filesystem(workspace, C.first(List.tail(&2, String, revisions)), status)
    return C.object([C.field("schemaVersion", "1"), C.field("backend", C.quote("jj")), C.field("repositoryRoot", C.quote(repo)),
      C.field("workspaceRoot", C.quote(workspace)), C.field("activeDirectory", C.quote(active)),
      C.field("vcs", C.object([C.field("changeId", C.string_or_null(C.first(revisions))), C.field("commitId", C.string_or_null(C.first(List.tail(&2, String, revisions))))])),
      C.field("destination", C.object([C.field("remote", C.string_or_null(C.first(String.split(C.first(C.lines(remotes)), ' ')))), C.field("trunk", C.quote(trunk))])),
      C.field("workingCopy", work), C.field("receipt", recorded)])

def snapshot_backend(use_jj: Bool, +repo: String, active: String, receipt_path: String) -> C.Task(String):
  match use_jj:
    case True{}:
      jj_snapshot(repo, active, receipt_path)
    case False{}:
      do C.Task<String>:
        root : String <- C.git_output(repo, ["rev-parse", "--show-toplevel"])
        git_snapshot(root, active, receipt_path)

def detected(jj: C.Command, +repo: String, active: String, receipt_path: String) -> C.Task(String):
  match jj:
    case C.Command{code, out, err}:
      snapshot_backend(U32.is_zero(code) && C.nonempty(String.trim(out)), repo, active, receipt_path)

def snapshot_detect(+repo: String, active: String, receipt_path: String) -> C.Task(String):
  do IO<Result<&1, &1, String, String>>:
    jj : C.Command <- C.run("jj", ["--repository", repo, "root", "--ignore-working-copy"], "")
    detected(jj, repo, active, receipt_path)

def snapshot(+options: C.Options) -> C.Task(String):
  do C.Task<String>:
    +repo : String <- C.real_directory(C.option(options, "--repo", "."))
    active : String <- C.real_directory(C.option(options, "--active-directory", "."))
    snapshot_detect(repo, active, C.option(options, "--receipt", ""))

def read_snapshot(path: String) -> C.Task(String):
  do IO<Result<&1, &1, String, String>>:
    result : C.Command <- C.run("jq", ["-ce", "select(type == \"object\" and .schemaVersion == 1)", path], "")
    C.checked(result, "cannot read snapshot: validation")

def classify_parent(exact: Bool, repo: String, target: String, revision: String, parent: String) -> C.Task(String):
  match exact parent:
    case True{} _:
      C.Task.pure(String, "exact")
    case False{} SNil{}:
      C.Task.pure(String, "unlanded")
    case False{} SCon{h, t}:
      do C.Task<String>:
        cherry : String <- C.git_optional(repo, ["cherry", target, revision, SCon{h, t}])
        return C.choose(String, String.starts_with(cherry, "-"), "patch-equivalent", "unlanded")

def classify_ancestry(+repo: String, +target: String, +revision: String, parent: String) -> C.Task(String):
  do IO<Result<&1, &1, String, String>>:
    ancestor : C.Command <- C.git(repo, ["merge-base", "--is-ancestor", revision, target])
    classify_parent(C.succeeded(ancestor), repo, target, revision, parent)

def classify_one(+repo: String, +target: String, +revision: String) -> C.Task(String):
  do C.Task<String>:
    parent : String <- C.git_optional(repo, ["rev-parse", revision ++ "^"])
    classify_ancestry(repo, target, revision, parent)

def resolve(revisions: List<&2, String>, +repo: String) -> C.Task(List<&2, String>):
  match revisions:
    case Nil{}:
      C.Task.pure(List<&2, String>, [])
    case Con{revision, tail}:
      do C.Task<List<&2, String>>:
        commit : String <- C.git_output(repo, ["rev-parse", "--verify", revision ++ "^{commit}"])
        rest : List<&2, String> <- resolve(tail, repo)
        return commit <> rest

def classify_all(revisions: List<&2, String>, +repo: String, +target: String) -> C.Task(List<&2, C.Entry>):
  match revisions:
    case Nil{}:
      C.Task.pure(List<&2, C.Entry>, [])
    case Con{+revision, tail}:
      do C.Task<List<&2, C.Entry>>:
        evidence : String <- classify_one(repo, target, revision)
        rest : List<&2, C.Entry> <- classify_all(tail, repo, target)
        return C.Entry{revision, evidence} <> rest

def records(items: List<&2, C.Entry>) -> List<&2, String>:
  match items:
    case Nil{}:
      []
    case Con{C.Entry{revision, evidence}, tail}:
      C.object([C.field("revision", C.quote(revision)), C.field("evidence", C.quote(evidence))]) <> records(tail)

def missing(items: List<&2, C.Entry>) -> List<&2, String>:
  match items:
    case Nil{}:
      []
    case Con{C.Entry{+revision, evidence}, tail}:
      +rest = missing(tail)
      C.choose(List<&2, String>, String.eq(evidence, "unlanded"), revision <> rest, rest)

def unrelated(items: List<&2, String>, +allowed: List<&2, String>) -> List<&2, String>:
  match items:
    case Nil{}:
      []
    case Con{+revision, tail}:
      +rest = unrelated(tail, allowed)
      C.choose(List<&2, String>, C.has(allowed, revision), rest, revision <> rest)

def classification_json(backend: String, +authority: String, dest: String, base: String, task_records: List<&2, String>, +unlanded: List<&2, String>, +extra: List<&2, String>) -> String:
  +blockers = List.append(&2, String,
    C.choose(List<&2, String>, List.is_empty(&2, String, extra), [], ["local default contains commits without publication authority"]),
    C.choose(List<&2, String>, String.eq(authority, "verify") && Bool.not(List.is_empty(&2, String, unlanded)), ["task revisions are not landed"], []))
  C.object([C.field("schemaVersion", "1"), C.field("backend", C.quote(backend)),
    C.field("status", C.quote(C.choose(String, List.is_empty(&2, String, blockers), "ready", "blocked"))),
    C.field("authority", C.quote(authority)), C.field("destination", dest), C.field("taskBase", C.quote(base)),
    C.field("taskRevisions", C.array(task_records)), C.field("replayRevisions", "[" ++ C.strings_json(unlanded) ++ "]"),
    C.field("unrelatedLocalCommits", "[" ++ C.strings_json(extra) ++ "]"), C.field("blockers", "[" ++ C.strings_json(blockers) ++ "]")])

def range_patch_id(+repo: String, base: String, tip: String) -> C.Task(String):
  do C.Task<String>:
    diff : String <- C.git_output(repo, ["diff", "--binary", "--no-ext-diff", base, tip])
    patch : String <- C.output("git", ["-C", repo, "patch-id", "--stable"], diff ++ "\n")
    return C.first(String.split(patch, ' '))

def aggregate_records(items: List<&2, C.Entry>) -> List<&2, C.Entry>:
  match items:
    case Nil{}:
      []
    case Con{C.Entry{revision, +evidence}, tail}:
      C.Entry{revision, C.choose(String, String.eq(evidence, "unlanded"), "aggregate-patch-equivalent", evidence)} <> aggregate_records(tail)

def aggregate_compare(hashes: String & String, +items: List<&2, C.Entry>) -> List<&2, C.Entry>:
  (+a, b) = hashes
  C.choose(List<&2, C.Entry>, C.nonempty(a) && String.eq(a, b), aggregate_records(items), items)

def aggregate(+landed: String, +repo: String, +target: String, base: String, tip: String, items: List<&2, C.Entry>) -> C.Task(List<&2, C.Entry>):
  match landed:
    case SNil{}:
      C.Task.pure(List<&2, C.Entry>, items)
    case SCon{h, t}:
      do C.Task<List<&2, C.Entry>>:
        ancestor : String <- C.git_output(repo, ["merge-base", "--is-ancestor", landed, target])
        parent : String <- C.git_output(repo, ["rev-parse", landed ++ "^"])
        hashes : String & String <- C.parallel(String, String, range_patch_id(repo, base, tip), range_patch_id(repo, parent, landed))
        return aggregate_compare(hashes, items)

def classify_git(+options: C.Options, +before: String) -> C.Task(String):
  do C.Task<String>:
    +repo : String <- C.json_text(before, "repositoryRoot")
    +dest : String <- C.json_query(before, ".destination")
    +remote_ref : String <- C.json_text(dest, "remoteRef")
    local_ref : String <- C.json_text(dest, "defaultBranch")
    +authority : String = C.option(options, "--authority", "full")
    +target : String = C.choose(String, String.is_empty(remote_ref) && String.eq(authority, "local-only"), local_ref, remote_ref)
    C.require(C.nonempty(target), "snapshot has no authoritative remote default ref")
    checked : String <- C.git_output(repo, ["rev-parse", "--verify", target ++ "^{commit}"])
    +revisions : List<&2, String> <- resolve(C.values(options, "--task-revision"), repo)
    C.require(Bool.not(List.is_empty(&2, String, revisions)), "--task-revision is required")
    +base : String <- C.git_output(repo, ["rev-parse", C.option(options, "--task-base", C.first(revisions) ++ "^")])
    classified : List<&2, C.Entry> <- classify_all(revisions, repo, target)
    +final : List<&2, C.Entry> <- aggregate(C.option(options, "--landed-revision", ""), repo, target, base, C.first(List.reverse(&2, String, revisions)), classified)
    local_commits : String <- C.git_output(repo, ["rev-list", "--reverse", target ++ "..HEAD"])
    allowed : List<&2, String> <- resolve(C.values(options, "--allow-local-revision"), repo)
    +extra : List<&2, String> = unrelated(C.lines(local_commits), List.append(&2, String, revisions, allowed))
    return classification_json("git", authority, dest, base, records(final), missing(final), extra)

type JJRevision is Data:
  JJRevision{revision: String, commit: String, evidence: String}

def classify_jj_revisions(revisions: List<&2, String>, +repo: String) -> C.Task(List<&2, JJRevision>):
  match revisions:
    case Nil{}:
      C.Task.pure(List<&2, JJRevision>, [])
    case Con{+revision, tail}:
      do C.Task<List<&2, JJRevision>>:
        commit : String <- jj_output(repo, ["log", "-r", revision, "--no-graph", "-T", "commit_id ++ \"\\n\""])
        absent : String <- jj_output(repo, ["log", "-r", revision ++ " & ~::trunk()", "--no-graph", "-T", "commit_id ++ \"\\n\""])
        rest : List<&2, JJRevision> <- classify_jj_revisions(tail, repo)
        return JJRevision{revision, commit, C.choose(String, C.nonempty(absent), "unlanded", "exact")} <> rest

def jj_records(items: List<&2, JJRevision>) -> List<&2, String>:
  match items:
    case Nil{}:
      []
    case Con{JJRevision{revision, commit, evidence}, tail}:
      C.object([C.field("revision", C.quote(revision)), C.field("commitId", C.quote(commit)), C.field("evidence", C.quote(evidence))]) <> jj_records(tail)

def jj_missing(items: List<&2, JJRevision>) -> List<&2, String>:
  match items:
    case Nil{}:
      []
    case Con{JJRevision{revision, commit, evidence}, tail}:
      +rest = jj_missing(tail)
      C.choose(List<&2, String>, String.eq(evidence, "unlanded"), revision <> rest, rest)

def classify_backend(backend: String, +options: C.Options, +before: String) -> C.Task(String):
  match backend:
    case "git":
      classify_git(options, before)
    case "jj":
      do C.Task<String>:
        repo : String <- C.json_text(before, "repositoryRoot")
        dest : String <- C.json_query(before, ".destination")
        +items : List<&2, JJRevision> <- classify_jj_revisions(C.values(options, "--task-revision"), repo)
        return classification_json("jj", C.option(options, "--authority", "full"), dest, "", jj_records(items), jj_missing(items), [])
    case _:
      C.Task.fail(String, "unsupported backend in snapshot")

def preservation(+before: String) -> C.Task(String):
  do C.Task<String>:
    +repo : String <- C.json_text(before, "repositoryRoot")
    active : String <- C.json_text(before, "activeDirectory")
    receipt_path : String <- C.output("jq", ["-r", ".receipt.path // empty"], before)
    current : String <- snapshot_detect(repo, active, receipt_path)
    old_work : String <- C.json_query(before, ".workingCopy")
    new_work : String <- C.json_query(current, ".workingCopy")
    C.require(String.eq(old_work, new_work), "working-copy fingerprint changed; preserve the original task state and stop")
    return C.object([C.field("schemaVersion", "1"), C.field("status", C.quote("preserved")), C.field("repositoryRoot", C.quote(repo))])

def dispatch(command: String, +options: C.Options) -> C.Task(String):
  match command:
    case "snapshot":
      snapshot(options)
    case "classify":
      do C.Task<String>:
        C.require(C.has(["full", "commit-push", "publish-branch", "verify", "local-only"], C.option(options, "--authority", "full")), "invalid authority")
        C.require(Bool.not(List.is_empty(&2, String, C.values(options, "--task-revision"))), "--task-revision is required")
        +before : String <- read_snapshot(C.option(options, "--snapshot", ""))
        backend : String <- C.json_text(before, "backend")
        classify_backend(backend, options, before)
    case "verify-preservation":
      do C.Task<String>:
        before : String <- read_snapshot(C.option(options, "--snapshot", ""))
        preservation(before)
    case _:
      C.Task.fail(String, "usage: closeout.bend snapshot|classify|verify-preservation [options]")

def arguments(args: List<String>) -> C.Task(String):
  match args:
    case Con{command, tail}:
      do C.Task<String>:
        options : C.Options <- C.parse_options(tail, ["--repo", "--active-directory", "--receipt", "--snapshot", "--task-base", "--task-revision", "--landed-revision", "--allow-local-revision", "--authority"], [])
        dispatch(command, options)
    case Nil{}:
      C.Task.fail(String, "closeout requires a subcommand")

def finish_payload(status: Result<&1, &1, String, String>, payload: String) -> IO(Unit):
  match status:
    case Fail{message}:
      IO.die(Unit, 2, message)
    case Done{value}:
      do IO<Unit>:
        IO.print(payload)
        IO.exit(C.choose(U32, String.eq(value, "blocked"), 1, 0))

def finish(result: Result<&1, &1, String, String>) -> IO(Unit):
  match result:
    case Fail{+message}:
      IO.die(Unit, C.choose(U32, String.starts_with(message, "working-copy fingerprint"), 1, 2), message)
    case Done{+payload}:
      do IO<Unit>:
        status : Result<&1, &1, String, String> <- C.json_text(payload, "status")
        finish_payload(status, payload)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    result : Result<&1, &1, String, String> <- arguments(List.tail(&1, String, args))
    finish(result)
