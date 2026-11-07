import Base
import ./scripts/policy.bend as Policy

# These laws govern decisions, not Git, GitHub, filesystem, or process effects.
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
