import Base

# A completed write is never retryable, including a lost acknowledgement.
def retry(completed: Bool, bypass: Bool, non_fast_forward: Bool, remaining: Bool) -> Bool:
  match completed bypass non_fast_forward remaining:
    case False{} False{} True{} True{}:
      True{}
    case _ _ _ _:
      False{}

def gate(check_present: Bool, checks_pass: Bool, app_bound: Bool, status_present: Bool, status_pass: Bool) -> Bool:
  match check_present checks_pass app_bound status_present status_pass:
    case True{} True{} _ False{} _:
      True{}
    case True{} True{} _ True{} True{}:
      True{}
    case False{} _ False{} True{} True{}:
      True{}
    case _ _ _ _ _:
      False{}

def cleanup_safe(+active: String, +candidate: String) -> Bool:
  Bool.not(String.eq(candidate, "/") || String.eq(active, candidate)
    || String.starts_with(active, candidate ++ "/"))

def publication_status(completed: Bool, acknowledged: Bool) -> String:
  match completed acknowledged:
    case True{} _:
      "published"
    case _ True{}:
      "published"
    case _ _:
      "publication-unknown"
