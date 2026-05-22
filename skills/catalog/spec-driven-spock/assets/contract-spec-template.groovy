/*
 * Copyright YYYY, <org>
 *
 * <license header — keep your project's standard one>
 */

package <your.package.path>

import spock.lang.Narrative
import spock.lang.PendingFeature
import spock.lang.See
import spock.lang.Specification
import spock.lang.Title
import spock.lang.Unroll

/**
 * ADR conformance contract for <feature name>.
 *
 * Every method here is a pin against a numbered decision in
 * adr/YYYYMMDD-<title>.md. Replacing a stub with a real spec is how a
 * decision graduates from "documented" to "shipped". Spock fails the
 * build on an unexpected pass, so the contract cannot quietly drift
 * out of sync with the implementation.
 */
@Title("<feature name> — <concern> contract")
@Narrative('''
Audience: <pipeline authors / reviewers / plugin authors / tooling integrators>.
Pins decisions <D-list> from adr/YYYYMMDD-<title>.md. When a decision
ships, replace the matching @PendingFeature stub here with a real
Given/When/Then and remove the marker.
''')
@See([
    "https://github.com/<org>/<repo>/blob/master/adr/YYYYMMDD-<title>.md",
    "https://github.com/<org>/<repo>/pull/<adr-pr>",
    "https://spockframework.org/spock/docs/2.4/all_in_one.html#_pendingfeature"
])
class <DomainName><Concern>Spec extends Specification {

    // ───── D1 — <decision short title> ───────────────────────────────────

    @PendingFeature
    @See("https://github.com/<org>/<repo>/blob/master/adr/YYYYMMDD-<title>.md#d1--<slug>")
    def '<behaviour described in present tense, one short sentence>'() {
        expect: false
    }

    // ───── D2 — <decision short title> ───────────────────────────────────

    @PendingFeature
    @See("https://github.com/<org>/<repo>/blob/master/adr/YYYYMMDD-<title>.md#d2--<slug>")
    def '<behaviour described in present tense>'() {
        expect: false
    }

    // Example of a table-driven pin (one @Unroll covers a documented matrix):

    @Unroll
    @PendingFeature
    @See("https://github.com/<org>/<repo>/blob/master/adr/YYYYMMDD-<title>.md#d3--<slug>")
    def '<result> is #expected when #scenario'() {
        expect: false
        where:
        expected | scenario
        'A'      | 'condition one'
        'B'      | 'condition two'
        'C'      | 'condition three'
    }
}
