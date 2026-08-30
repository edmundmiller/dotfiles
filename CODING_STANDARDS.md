---
purpose: Define review-time coding standards without adding startup context.
applies_to: Source, tests, and configuration changed in this repository.
entrypoint: The /code-review skill reads this file as the repository standard.
verification: Review each changed test for independent failure evidence.
update_when: A recurring review concern becomes a durable project convention.
---

# Coding standards

## Tests

Tautological tests are considered harmful. Every test must be able to fail when
the implementation is wrong; do not merely restate the implementation, assert
a value copied from the setup, or verify that a mock returns what the test
configured it to return.

Prefer assertions at public behavior boundaries. Use implementation-detail or
source-shape assertions only when that detail is itself an explicit contract.
