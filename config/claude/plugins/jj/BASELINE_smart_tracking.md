# Baseline: Current /jj:commit File Tracking Behavior

**Date:** 2025-11-16
**Purpose:** Document current behavior before implementing smart file tracking

## Current Implementation

Location: `config/claude/plugins/jj/commands/commit.md:33`

```bash
jj file track . 2>/dev/null || true
```

## Behavior Summary

**Current behavior: Tracks ALL files indiscriminately**

The current implementation runs `jj file track .` which tracks every untracked file in the working directory, including:

- ✅ Source code (intended)
- ✅ Configuration files (intended)
- ✅ Documentation (intended)
- ❌ Claude output files like `FINDINGS_SUMMARY.txt` (unintended)
- ❌ Scratch files like `notes.txt`, `scratch.md` (unintended)
- ❌ Temporary files (unintended)
- ❌ Build artifacts (unintended)

## Problem Cases

### 1. Claude-Generated Output Files

When Claude creates output files during analysis, they get tracked:

```
❌ FINDINGS_SUMMARY.txt
❌ ANALYSIS.md
❌ INVESTIGATION_NOTES.md
❌ ERROR_ANALYSIS.txt
❌ REPORT.txt
```

**User quote:** "not random markdown and txt files it spits out like ? FINDINGS_SUMMARY.txt🤮"

### 2. Generic Scratch Files

Generic .txt/.md files in root directory:

```
❌ notes.txt
❌ scratch.md
❌ output.txt
❌ results.md
❌ temp.txt
```

### 3. Temporary/System Files

System and build artifacts:

```
❌ .DS_Store
❌ __pycache__/
❌ *.tmp
❌ *.bak
❌ dist/
❌ node_modules/
```

## What Works Well

The current approach successfully tracks:

```
✅ src/main.py
✅ package.json
✅ requirements.txt
✅ README.md
✅ docs/guide.md
```

## Impact

**User workflow:** Users must manually un-track or split unwanted files after commit

**Current workaround:** Use `/jj:split` after committing to separate unwanted files

**Desired behavior:** Intelligently filter files during tracking so only intentional project files are tracked

## Success Criteria

After implementing smart tracking, `/jj:commit` should:

1. ✅ Track source code files (`.py`, `.ts`, `.rs`, etc.)
2. ✅ Track configuration files (`package.json`, `*.toml`, etc.)
3. ✅ Track intentional documentation (`README.md`, `docs/*.md`)
4. ❌ Skip Claude output files (pattern-based detection)
5. ❌ Skip generic .txt/.md files in root
6. ❌ Skip temporary and system files
7. ⚙️ Use context for ambiguous cases (location, naming patterns)
8. 🔇 Operate silently (no user-facing changes to workflow)
9. 🔓 Allow manual override via direct `jj file track` commands

## Evaluation Tests

See: `config/claude/plugins/jj/test_smart_tracking.py`

- **Baseline tests:** Document current "track everything" behavior
- **Spec tests:** Define expected smart tracking behavior
- **Edge cases:** Mixed files, empty directories, manual overrides
- **Integration tests:** Silent operation, workflow compatibility

## Next Steps

1. ✅ Create evaluation tests (completed)
2. ✅ Document baseline behavior (this file)
3. ⏳ Run baseline measurements
4. ⏳ Implement smart tracking logic
5. ⏳ Verify against evaluation tests
6. ⏳ Validate with real-world usage

---

**Reference:** See `test_smart_tracking.py` for detailed test cases and expected behaviors.
