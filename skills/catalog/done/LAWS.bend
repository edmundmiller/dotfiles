import Base
import ./scripts/policy.bend as Policy

# These laws govern decisions, not Git, GitHub, filesystem, or process effects.
law retry_exactly_when_safe:
  for completed: Bool
  for bypass: Bool
  for non_fast_forward: Bool
  for remaining: Bool
  {Policy.retry(completed, bypass, non_fast_forward, remaining)
    == (Bool.not(completed) && Bool.not(bypass) && non_fast_forward && remaining) : Bool}

law completed_write_never_retries:
  for bypass: Bool
  for rejected: Bool
  for remaining: Bool
  {Policy.retry(True{}, bypass, rejected, remaining) == False{} : Bool}

law bypass_never_retries:
  for completed: Bool
  for rejected: Bool
  for remaining: Bool
  {Policy.retry(completed, True{}, rejected, remaining) == False{} : Bool}

law exhausted_retry_budget:
  for completed: Bool
  for bypass: Bool
  for rejected: Bool
  {Policy.retry(completed, bypass, rejected, False{}) == False{} : Bool}

law failing_status_blocks_check:
  for app_bound: Bool
  {Policy.gate(True{}, True{}, app_bound, True{}, False{}) == False{} : Bool}

law app_bound_status_is_insufficient:
  for checks_pass: Bool
  for status_present: Bool
  for status_pass: Bool
  {Policy.gate(False{}, checks_pass, True{}, status_present, status_pass) == False{} : Bool}

law acknowledged_write_stays_published:
  for completed: Bool
  {Policy.publication_status(completed, True{}) == "published" : String}

# Paths are already resolved by the caller. These cases partition the decision
# using Base's equality and slash-delimited prefix predicates.
law cleanup_root_is_unsafe:
  for active: String
  {Policy.cleanup_safe(active, "/") == False{} : Bool}

law cleanup_same_directory_is_unsafe:
  for active: String
  for candidate: String
  for nonroot: {String.eq(candidate, "/") == False{} : Bool}
  for same: {String.eq(active, candidate) == True{} : Bool}
  {Policy.cleanup_safe(active, candidate) == False{} : Bool}

law cleanup_ancestor_is_unsafe:
  for active: String
  for candidate: String
  for nonroot: {String.eq(candidate, "/") == False{} : Bool}
  for distinct: {String.eq(active, candidate) == False{} : Bool}
  for inside: {String.starts_with(active, candidate ++ "/") == True{} : Bool}
  {Policy.cleanup_safe(active, candidate) == False{} : Bool}

law cleanup_outside_active_path_is_safe:
  for active: String
  for candidate: String
  for nonroot: {String.eq(candidate, "/") == False{} : Bool}
  for distinct: {String.eq(active, candidate) == False{} : Bool}
  for outside: {String.starts_with(active, candidate ++ "/") == False{} : Bool}
  {Policy.cleanup_safe(active, candidate) == True{} : Bool}
