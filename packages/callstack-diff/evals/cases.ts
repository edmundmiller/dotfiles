import type { ComplaintRequirements } from "./complaint.ts";

export interface ComplaintCase {
  readonly id: string;
  readonly name: string;
  readonly task: string;
  readonly fixture: string;
  readonly command: readonly string[];
  readonly requirements: ComplaintRequirements;
}

export const COMPLAINT_CASES: readonly ComplaintCase[] = [
  {
    id: "imported-helper-ambiguity",
    name: "documents an imported helper resolving to the wrong same-named function",
    task: `Determine whether csd follows the explicit helper import in app.ts.
Inspect all three source files, run the command, and compare the rendered leaf with the imported implementation.`,
    fixture: "imported-helper-ambiguity",
    command: ["csd", "main", "app.ts", "distractor.ts", "intended.ts", "--theme", "none"],
    requirements: {
      caseId: "imported-helper-ambiguity",
      commandIncludes: ["csd", "main", "app.ts", "distractor.ts", "intended.ts"],
      expectedIncludes: ["intendedLeaf"],
      actualIncludes: ["distractorLeaf"],
      regressionIncludes: ["import", "intendedLeaf"],
    },
  },
];
