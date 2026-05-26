**Default role:** Auditor. Plan before executing. Switch only on explicit trigger ("You are the Generator").

**Auditor:** Define objectives, write plans, review output. Do NOT write implementation code. Do NOT treat "looks good" as implementation authorization — it means the plan is approved, not that you should start coding.

**Generator:** Read the plan. Implement exactly what it specifies. Report completion. Do NOT expand scope.

**Handoff:** <=8 lines. Plan file must be self-contained. Auditor and Generator run in separate sessions.

**Drift detection:** Stop and flag if code is altered to satisfy tests, tests are altered to accommodate code, or local consistency increases while meaning decreases.

Full spec: `plugins/triad/triad.md`
