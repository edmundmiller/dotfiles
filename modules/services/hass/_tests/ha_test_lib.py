"""HA test helpers for NixOS VM tests.

Provides a high-level API for testing HA automations inside NixOS VM tests.
Import this module in the testScript of a nixosTest.

Usage in testScript:
    import ha_test_lib as ha

    ha.wait_ready(machine)
    ha.set_state(machine, "input_boolean.goodnight", "on")
    ha.assert_state(machine, "input_boolean.goodnight", "on")

Clock manipulation:
    ha.set_clock(machine, "07:30:00")   # Set VM system time
    ha.set_clock(machine, "04:47:00")   # Before time guard

Scenario runner:
    ha.run_scenario(machine,
        preconditions={"input_boolean.goodnight": "on", "input_boolean.edmund_awake": "off"},
        trigger=("input_boolean.edmund_awake", "on"),  # entity, new_state
        assertions={"input_boolean.edmund_awake": "on"},
    )
"""

import json
import time
import urllib.request
import urllib.error

HA_PORT = 8123
HA_BASE = f"http://localhost:{HA_PORT}"

# Long-lived access token — generated during onboarding in the VM test setup
_token = None


def _headers():
    h = {"Content-Type": "application/json"}
    if _token:
        h["Authorization"] = f"Bearer {_token}"
    return h


def _api(machine, method, path, data=None):
    """Make an HA API call from inside the VM."""
    headers_json = json.dumps(_headers())
    data_arg = ""
    if data is not None:
        payload = json.dumps(data).replace("'", "'\\''")
        data_arg = f"-d '{payload}'"
    cmd = f"curl -sf -X {method} {data_arg} -H 'Content-Type: application/json'"
    if _token:
        cmd += f" -H 'Authorization: Bearer {_token}'"
    cmd += f" {HA_BASE}/api/{path}"
    exit_code, output = machine.execute(cmd)
    if exit_code != 0:
        raise RuntimeError(f"HA API {method} /api/{path} failed (exit {exit_code}): {output}")
    if output.strip():
        return json.loads(output)
    return None


def wait_ready(machine, timeout=120):
    """Wait for HA to be fully initialized and API ready."""
    machine.wait_for_unit("home-assistant.service")
    machine.wait_for_open_port(HA_PORT)
    machine.wait_until_succeeds(
        f"journalctl -u home-assistant.service | grep -q 'Home Assistant initialized in'",
        timeout=timeout,
    )


def create_token(machine):
    """Create a long-lived access token via HA's auth system.

    Must be called after HA is ready. Uses the onboarding API to create
    the initial user, then generates a long-lived token.
    """
    global _token

    # Check if onboarding is needed
    exit_code, output = machine.execute(
        f"curl -sf {HA_BASE}/api/onboarding"
    )
    if exit_code == 0:
        steps = json.loads(output)
        needs_user = any(s["step"] == "user" and not s["done"] for s in steps)
        if needs_user:
            # Create initial user via onboarding
            exit_code, output = machine.execute(
                f"curl -sf -X POST -H 'Content-Type: application/json' "
                f"-d '{{\"client_id\": \"http://localhost:{HA_PORT}/\", "
                f"\"name\": \"Test\", \"username\": \"test\", \"password\": \"test1234\", "
                f"\"language\": \"en\"}}' "
                f"{HA_BASE}/api/onboarding/users"
            )
            if exit_code != 0:
                raise RuntimeError(f"Onboarding failed: {output}")
            result = json.loads(output)
            _token = result.get("auth_code")

            # Complete remaining onboarding steps
            for step in ["core_config", "analytics", "integration"]:
                machine.execute(
                    f"curl -sf -X POST -H 'Content-Type: application/json' "
                    f"-H 'Authorization: Bearer {_token}' "
                    f"-d '{{\"client_id\": \"http://localhost:{HA_PORT}/\"}}' "
                    f"{HA_BASE}/api/onboarding/{step}"
                )

    if not _token:
        # Onboarding already done — use auth flow
        # Get auth token via Resource Owner Password grant
        exit_code, output = machine.execute(
            f"curl -sf -X POST "
            f"-d 'grant_type=password&client_id=http://localhost:{HA_PORT}/&username=test&password=test1234' "
            f"{HA_BASE}/auth/token"
        )
        if exit_code == 0:
            result = json.loads(output)
            _token = result.get("access_token")

    if not _token:
        raise RuntimeError("Failed to obtain HA auth token")

    return _token


def get_state(machine, entity_id):
    """Get the current state of an entity."""
    result = _api(machine, "GET", f"states/{entity_id}")
    return result["state"]


def set_state(machine, entity_id, state, attributes=None):
    """Set the state of an entity via the API."""
    data = {"state": state}
    if attributes:
        data["attributes"] = attributes
    _api(machine, "POST", f"states/{entity_id}", data)


def fire_event(machine, event_type, event_data=None):
    """Fire a HA event."""
    _api(machine, "POST", f"events/{event_type}", event_data or {})


def call_service(machine, domain, service, data=None):
    """Call a HA service."""
    _api(machine, "POST", f"services/{domain}/{service}", data or {})


def trigger_automation(machine, automation_id):
    """Trigger an automation by entity_id."""
    entity_id = automation_id if automation_id.startswith("automation.") else f"automation.{automation_id}"
    call_service(machine, "automation", "trigger", {"entity_id": entity_id})


def set_clock(machine, time_str, date_str=None):
    """Set the VM system clock.

    Args:
        time_str: Time in HH:MM:SS format
        date_str: Optional date in YYYY-MM-DD format (default: today)
    """
    if date_str:
        machine.succeed(f"date -s '{date_str} {time_str}'")
    else:
        machine.succeed(f"date -s '{time_str}'")
    # Give HA a moment to notice the time change
    time.sleep(1)


def assert_state(machine, entity_id, expected, timeout=10, interval=0.5):
    """Assert entity reaches expected state within timeout."""
    deadline = time.time() + timeout
    last_state = None
    while time.time() < deadline:
        try:
            last_state = get_state(machine, entity_id)
            if last_state == expected:
                return
        except Exception:
            pass
        time.sleep(interval)
    raise AssertionError(
        f"{entity_id}: expected '{expected}', got '{last_state}' after {timeout}s"
    )


def assert_state_not(machine, entity_id, unexpected, hold=3, interval=0.5):
    """Assert entity does NOT reach a state within hold period."""
    deadline = time.time() + hold
    while time.time() < deadline:
        try:
            state = get_state(machine, entity_id)
            if state == unexpected:
                raise AssertionError(
                    f"{entity_id}: unexpectedly reached '{unexpected}'"
                )
        except RuntimeError:
            pass  # API error = entity doesn't exist yet, that's fine
        time.sleep(interval)


def run_scenario(machine, preconditions=None, trigger=None, assertions=None, negative_assertions=None):
    """Run a full test scenario.

    Args:
        preconditions: dict of {entity_id: state} to set before trigger
        trigger: tuple of (entity_id, new_state) to fire
        assertions: dict of {entity_id: expected_state} to verify after
        negative_assertions: dict of {entity_id: unexpected_state} to verify NOT reached
    """
    # Set preconditions
    if preconditions:
        for entity_id, state in preconditions.items():
            set_state(machine, entity_id, state)
        time.sleep(0.5)  # Let HA process state changes

    # Fire trigger
    if trigger:
        entity_id, new_state = trigger
        set_state(machine, entity_id, new_state)
        time.sleep(1)  # Let automations fire

    # Check positive assertions
    if assertions:
        for entity_id, expected in assertions.items():
            assert_state(machine, entity_id, expected)

    # Check negative assertions
    if negative_assertions:
        for entity_id, unexpected in negative_assertions.items():
            assert_state_not(machine, entity_id, unexpected)
