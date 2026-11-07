import Base
import ./LAWS.bend as Laws

def Laws.retry_exactly_when_safe(completed, bypass, non_fast_forward, remaining):
  match completed bypass non_fast_forward remaining:
    case True{} _ _ _:
      {==}
    case False{} True{} _ _:
      {==}
    case False{} False{} False{} _:
      {==}
    case False{} False{} True{} False{}:
      {==}
    case False{} False{} True{} True{}:
      {==}

def Laws.completed_write_never_retries(bypass, rejected, remaining):
  {==}

def Laws.bypass_never_retries(completed, rejected, remaining):
  match completed:
    case False{}:
      {==}
    case True{}:
      {==}

def Laws.exhausted_retry_budget(completed, bypass, rejected):
  match completed bypass rejected:
    case False{} False{} False{}:
      {==}
    case False{} False{} True{}:
      {==}
    case False{} True{} _:
      {==}
    case True{} _ _:
      {==}

def Laws.failing_status_blocks_check(app_bound):
  {==}

def Laws.app_bound_status_is_insufficient(checks_pass, status_present, status_pass):
  {==}

def Laws.acknowledged_write_stays_published(completed):
  match completed:
    case False{}:
      {==}
    case True{}:
      {==}

def Laws.cleanup_root_is_unsafe(active):
  {==}

def Laws.cleanup_same_directory_is_unsafe(active, candidate, nonroot, same):
  %Equal.sym(Bool, String.eq(candidate, "/"), False{}, nonroot) : {Bool.not(_ || String.eq(active, candidate) || String.starts_with(active, candidate ++ "/")) == False{} : Bool}
  %Equal.sym(Bool, String.eq(active, candidate), True{}, same) : {Bool.not(_ || String.starts_with(active, candidate ++ "/")) == False{} : Bool}
  {==}

def Laws.cleanup_ancestor_is_unsafe(active, candidate, nonroot, distinct, inside):
  %Equal.sym(Bool, String.eq(candidate, "/"), False{}, nonroot) : {Bool.not(_ || String.eq(active, candidate) || String.starts_with(active, candidate ++ "/")) == False{} : Bool}
  %Equal.sym(Bool, String.eq(active, candidate), False{}, distinct) : {Bool.not(_ || String.starts_with(active, candidate ++ "/")) == False{} : Bool}
  %Equal.sym(Bool, String.starts_with(active, candidate ++ "/"), True{}, inside) : {Bool.not(_) == False{} : Bool}
  {==}

def Laws.cleanup_outside_active_path_is_safe(active, candidate, nonroot, distinct, outside):
  %Equal.sym(Bool, String.eq(candidate, "/"), False{}, nonroot) : {Bool.not(_ || String.eq(active, candidate) || String.starts_with(active, candidate ++ "/")) == True{} : Bool}
  %Equal.sym(Bool, String.eq(active, candidate), False{}, distinct) : {Bool.not(_ || String.starts_with(active, candidate ++ "/")) == True{} : Bool}
  %Equal.sym(Bool, String.starts_with(active, candidate ++ "/"), False{}, outside) : {Bool.not(_) == True{} : Bool}
  {==}
