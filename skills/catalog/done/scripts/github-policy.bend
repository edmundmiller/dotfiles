import Base
import ./common.bend as C
import ./policy.bend as Policy

def api_status(success: Bool, absent: Bool, out: String) -> C.Task(String):
  match success absent:
    case True{} _:
      C.json_query(out, "if type == \"array\" and length > 0 then . else error(\"invalid policy response\") end")
    case False{} True{}:
      C.Task.pure(String, "[{}]")
    case _ _:
      C.Task.fail(String, "cannot resolve GitHub policy; gh authentication and policy read access are required")

def api_result(result: C.Command, absent_ok: Bool) -> C.Task(String):
  match result:
    case C.Command{code, +out, err}:
      api_status(U32.is_zero(code), absent_ok && String.contains(err, "(HTTP 404)") && String.contains(out, "Branch not protected"), out)

def api(endpoint: String, absent_ok: Bool) -> C.Task(String):
  do IO<Result<&1, &1, String, String>>:
    result : C.Command <- C.run("gh", ["api", "--hostname", "github.com", "--paginate", "--slurp", endpoint], "")
    api_result(result, absent_ok)

def query_bool(json: String, query: String) -> C.Task(Bool):
  do C.Task<Bool>:
    result : String <- C.output("jq", ["-c", query], json)
    return String.eq(result, "true")

def required_gate(+required: String, +runs: String, +statuses: String, +head: String) -> C.Task(Unit):
  do C.Task<Unit>:
    +context : String <- C.json_text(required, "context")
    +app : String <- C.json_query(required, ".integration_id // .app_id // -1")
    C.require(C.nonempty(context), "invalid required gate context")
    +checks : String <- C.json_query(runs, "[.[] | select(.name == " ++ C.quote(context) ++ " and .head_sha == " ++ C.quote(head) ++ " and (" ++ app ++ " == -1 or .app.id == " ++ app ++ "))]")
    +states : String <- C.json_query(statuses, "[.[] | select(.context == " ++ C.quote(context) ++ " and (.sha // " ++ C.quote(head) ++ ") == " ++ C.quote(head) ++ ")] | sort_by(.id) | reverse | .[:1]")
    check_present : Bool <- query_bool(checks, "length > 0")
    checks_pass : Bool <- query_bool(checks, "all(.status == \"completed\" and (.conclusion == \"success\" or .conclusion == \"neutral\" or .conclusion == \"skipped\"))")
    status_present : Bool <- query_bool(states, "length > 0")
    status_pass : Bool <- query_bool(states, "all(.state == \"success\")")
    C.require(Policy.gate(check_present, checks_pass, Bool.not(String.eq(app, "-1")), status_present, status_pass), "required gate " ++ context ++ " is missing or not successful on " ++ head ++ "; use the GitHub PR path")

def gates(requirements: List<&2, String>, +runs: String, +statuses: String, +head: String) -> C.Task(Unit):
  match requirements:
    case Nil{}:
      C.Task.pure(Unit, Unit{})
    case Con{required, tail}:
      do C.Task<Unit>:
        required_gate(required, runs, statuses, head)
        gates(tail, runs, statuses, head)

def gate_pages(pages: String & String, requirements: List<&2, String>, head: String) -> C.Task(Unit):
  (checks, statuses) = pages
  do C.Task<Unit>:
    runs : String <- C.json_query(checks, "[.[] | .check_runs[]]")
    states : String <- C.json_query(statuses, "[.[][]]")
    gates(requirements, runs, states, head)

def check_gates(requirements: List<&2, String>, +prefix: String, +head: String) -> C.Task(Unit):
  match requirements:
    case Nil{}:
      C.Task.pure(Unit, Unit{})
    case Con{h, t}:
      do C.Task<Unit>:
        pages : String & String <- C.parallel(String, String,
          api(prefix ++ "/commits/" ++ head ++ "/check-runs?per_page=100", False{}),
          api(prefix ++ "/commits/" ++ head ++ "/statuses?per_page=100", False{}))
        gate_pages(pages, h <> t, head)

def check_rules(rules: List<&2, String>) -> C.Task(Unit):
  match rules:
    case Nil{}:
      C.Task.pure(Unit, Unit{})
    case Con{rule, tail}:
      do C.Task<Unit>:
        +kind : String <- C.json_text(rule, "type")
        C.require(C.has(["required_status_checks", "non_fast_forward", "deletion", "creation", "required_linear_history"], kind), "branch rule " ++ kind ++ " requires the GitHub PR path")
        check_rules(tail)

def check_linear(required: Bool, clone: String, branch: String, head: String) -> C.Task(Unit):
  match required:
    case False{}:
      C.Task.pure(Unit, Unit{})
    case True{}:
      do C.Task<Unit>:
        merges : String <- C.git_output(clone, ["rev-list", "--min-parents=2", "origin/" ++ branch ++ ".." ++ head])
        C.require(String.is_empty(merges), "linear-history policy forbids introducing merge commits")

def preflight_pages(pages: String & String, clone: String, prefix: String, branch: String, +head: String) -> C.Task(String):
  (rules_pages, protection_pages) = pages
  do C.Task<String>:
    +rules : String <- C.json_query(rules_pages, "[.[][]] | if all(type == \"object\" and (.type | type == \"string\")) then . else error(\"invalid rules\") end")
    +protection : String <- C.json_query(protection_pages, ".[0] | if type == \"object\" then . else error(\"invalid protection\") end")
    reviews : Bool <- query_bool(protection, ".required_pull_request_reviews != null")
    C.require(Bool.not(reviews), "required reviews prevent direct publication; use the GitHub PR path")
    restrictions : Bool <- query_bool(protection, ".restrictions != null or .required_signatures.enabled == true or .required_conversation_resolution.enabled == true or .lock_branch.enabled == true")
    C.require(Bool.not(restrictions), "protected publication requires the GitHub PR path")
    rule_items : List<&2, String> <- C.json_items(rules)
    check_rules(rule_items)
    linear_classic : Bool <- query_bool(protection, ".required_linear_history.enabled == true")
    linear_rules : Bool <- query_bool(rules, "any(.type == \"required_linear_history\")")
    check_linear(linear_classic || linear_rules, clone, branch, head)
    classic : String <- C.json_query(protection, "(.required_status_checks.checks // []) as $checks | $checks + [(.required_status_checks.contexts // [])[] | . as $context | select(all($checks[]; .context != $context)) | {context:$context}]")
    from_rules : String <- C.json_query(rules, "[.[] | select(.type == \"required_status_checks\") | .parameters.required_status_checks[]]")
    +requirements : String <- C.json_query("[" ++ classic ++ "," ++ from_rules ++ "]", "add")
    items : List<&2, String> <- C.json_items(requirements)
    check_gates(items, prefix, head)
    contexts : String <- C.json_query(requirements, "map(.context) | unique | sort")
    return C.object([C.field("compliant", "true"), C.field("provider", C.quote("github")), C.field("head", C.quote(head)), C.field("requiredContexts", contexts)])

def github_repository(+url: String) -> String:
  C.choose(String, String.starts_with(url, "git@github.com:"), String.drop(url, 15n),
    C.choose(String, String.starts_with(url, "https://github.com/"), String.drop(url, 19n),
      C.choose(String, String.starts_with(url, "ssh://git@github.com/"), String.drop(url, 21n), "")))

def github(clone: String, url: String, +branch: String, head: String) -> C.Task(String):
  do C.Task<String>:
    +path : String = github_repository(url)
    +repository : String = C.choose(String, String.ends_with(path, ".git"), String.take(path, Nat.sub(String.length(path), 4n)), path)
    C.require(Nat.is_eq(List.length(&2, String, String.split(repository, '/')), 2n) && Bool.not(String.contains(repository, "?") || String.contains(repository, "#")), "unsupported remote policy provider; use the repository PR path")
    +prefix : String = "repos/" ++ repository
    +escaped : String <- C.output("jq", ["-Rr", "@uri"], branch)
    pages : String & String <- C.parallel(String, String, api(prefix ++ "/rules/branches/" ++ escaped, False{}), api(prefix ++ "/branches/" ++ escaped ++ "/protection", True{}))
    preflight_pages(pages, clone, prefix, branch, head)

def preflight_local(local: Bool, clone: String, url: String, branch: String, head: String) -> C.Task(String):
  match local:
    case True{}:
      C.Task.pure(String, "{\"compliant\":true,\"provider\":\"local\"}")
    case False{}:
      github(clone, url, branch, head)

def preflight(clone: String, +url: String, branch: String, head: String) -> C.Task(String):
  preflight_local(String.starts_with(url, "/") || String.starts_with(url, "./") || String.starts_with(url, "../") || String.starts_with(url, "file://"), clone, url, branch, head)
