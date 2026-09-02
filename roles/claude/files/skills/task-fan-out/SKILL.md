---
name: task-fan-out
description: Fan a multi-part task out to parallel Claude (sonnet) agents running in visible herdr panes, orchestrated from the quad-layout tab. Use whenever the user says "fan out", "task fan out", "spin up agents", "parallelize this with agents", or wants several independent subtasks executed at once in herdr panes they can watch. Requires HERDR_ENV=1 and the herdr quad-layout tab.
---

# Task Fan-Out

Orchestrate N worker agents in herdr panes from the quad-layout tab. The orchestrator (this session) sits in column 1; workers live in column 2 as stacked panes the user can watch. Each worker is an interactive `claude` session on the sonnet model. Tasks are fed one at a time so the pane label always shows true progress.

## Output style

All orchestrator prose - plan, progress lines, per-agent summaries, final summary - follows two rulesets together:

1. **i-have-adhd** (loaded in precondition 0): action first, numbered steps, restate state, no preamble or closers.
2. **Simplified Technical English** (ASD-STE100, per `~/Source/decisions/CLAUDE.md`): active voice, one instruction per sentence, maximum 20 words per instruction sentence and 25 per descriptive sentence, no contractions, no metaphors or idioms - name the mechanism. Prefer a table to paragraphs. Code, commands, and paths stay verbatim.

Tell each worker agent to write its summary file in the same style: short sentences, facts only, no filler.

## 1. Preconditions

Run these checks before anything else. Stop and report if one fails.

0. Load the `i-have-adhd:i-have-adhd` skill (Skill tool) unless it is already active in this session. Every orchestrator message in this workflow - plan, progress, summaries - follows its rules: action first, numbered steps, state restated each turn, no preamble.
1. `test "${HERDR_ENV:-}" = 1` - if not, say you are not inside herdr and stop.
2. Orchestrator model must be **fable[1m]**. Check the model named in your system prompt. If it is anything else, ask the user to confirm proceeding on the current model or to switch (`/model fable[1m]`) - do not silently continue.
3. **Capture the orchestrator's own identity - never use bare `--current` again after this step.** Run `herdr pane current` (no flags). Read `.result.pane.pane_id`, `.result.pane.workspace_id`, and `.result.pane.tab_id`. Store all three; every herdr command for the rest of this run targets them explicitly with `--pane <captured-pane-id>`. If the user has more than one herdr workspace open, `--current` on commands like `neighbor` can resolve against a different workspace's pane - pinning to the captured id is what prevents that.
4. Confirm the quad layout: `herdr pane layout --pane <captured-pane-id>` should show the caller pane as a full-height column with a full-height column to its right (column 2). If the layout does not match, tell the user to open the quad-layout tab (plugin command `edward.quad-layout.apply`) and stop.
5. Identify column 2: `herdr pane neighbor --direction right --pane <captured-pane-id>` → `.result.neighbor.neighbor_pane_id`. **Verify `.result.neighbor.layout.workspace_id` equals the captured `workspace_id` before doing anything else with this pane.** Read the workspace from `.layout.workspace_id`, not from `.result.neighbor.workspace_id` - that top-level field returns null. Note also that `herdr pane layout` nests its panes under `.result.layout.panes`, not `.result.panes`. If it does not match, the resolution went to the wrong workspace - re-run the neighbor lookup once; if it still mismatches, stop and tell the user rather than guessing. Once confirmed same-workspace, check the pane with `herdr pane process-info --pane <neighbor-pane-id>` - it must be an idle shell (it is only split, never occupied or closed). If something is running there, ask the user before splitting it. Never close a pane you did not create.

## 2. Intake

Collect, in order (AskUserQuestion where options are enumerable, free text otherwise):

1. **The task.** If the user already stated it, restate it in one line and confirm.
2. **Clarifying questions** - only if the split into subtasks is genuinely ambiguous. Do not ask questions the codebase or the task statement already answers.
3. **Auto-close panes?** yes = close each worker pane after its summary is delivered; no = leave the pane open and ask the user what they want done with it.

## 3. Plan of attack

Output this exact template and get approval before creating any pane:

```
## Plan of attack
Agents: <N>
Auto-close: <yes/no>

| Agent | Tasks | Does |
|---|---|---|
| <kebab-name> | <count> | <one line per agent> |

Task assignments:
- <agent>: 1. <task> 2. <task> ...

Definition of done: <one or two lines - the observable end state that ends the run>
```

Sizing guidance: one agent per independent workstream, not per file. 2-4 agents is the sweet spot; above 5 the panes become unreadably short (column 2 is ~84 rows tall). Agent names are short kebab-case nouns describing the workstream (`vpc-survey`, `iam-audit`), unique, matching `[a-z][a-z0-9_-]{0,31}`.

## 4. Pane setup

Create one **new** pane per agent by stacking column 2 downward. Never put an agent in the user's original column-2 shell: on auto-close that pane cannot be closed without collapsing the column, so agents only live in panes this skill created.

- For agent i (1..N), split downward from the previous pane (column-2 pane for i=1, agent i-1's pane after): `herdr pane split <pane-id> --direction down --ratio <r> --cwd <agent-workdir> --no-focus`, where `r = 1/(N-i+2)` (N=2 → 0.33 then 0.5) so the original shell and all agents get equal rows.
- Read each new pane id from `.result.pane.pane_id` - never predict ids.
- Label immediately: `herdr pane rename <pane-id> "<agent>: 0/<total> starting"`.

Keep focus in the orchestrator pane throughout (`--no-focus` everywhere).

## 5. Start and feed agents

Start every agent on sonnet:

```bash
herdr agent start <agent-name> --kind claude --pane <pane-id> -- --model sonnet
```

Wait for the returned success (herdr blocks until the agent is ready). If it returns `agent_not_ready`, check `herdr agent get <name>`: a startup banner (for example an MCP-auth warning) can trip the blocked detector while the agent is actually at its prompt. If `agent_status` is `idle` and `interactive_ready` is true, proceed; otherwise `herdr agent read <name>` to see the real blocker.

Feed **one task at a time**. To keep agents parallel, dispatch to every agent without `--wait`, then wait on each:

```bash
herdr agent prompt <name> "<task text>"        # per agent, returns immediately
herdr agent wait <name> --timeout 600000       # then wait per agent
```

Use `--wait` on the prompt itself only when nothing else runs in parallel (for example each agent's final summary task).

- Before each prompt, update the pane label: `herdr pane rename <pane-id> "<agent>: <k>/<total> <short task desc>"`. The label is the user's progress display - keep it current, including when tasks are added mid-run (recount and rename).
- Each agent's **final** task must end with: "Write your complete findings/summary as markdown to /tmp/task-fan-out/<run-ts>/<agent>.md and reply with only that path." Create the run directory up front. This is the reliable result channel; `agent read` is the fallback for mid-run peeking.
- Prompts to different agents are independent - dispatch them in parallel, then wait on each.

Handling waits:
- `--wait` returns on `idle`, `done`, or `blocked`. On `blocked`, run `herdr agent get` + `herdr agent read` to see the dialog, then ask the user before answering it - never auto-approve a worker's permission prompt.
- On `agent_prompt_stalled` or timeout, read the pane before assuming failure; long tool runs look stalled.

## 6. Agent completion

When an agent finishes its last task:

1. Read its summary file and relay a compact per-agent summary to the user (facts, not verdicts).
2. Rename the pane to `"<agent>: done"`.
3. Auto-close = yes → `herdr pane close <pane-id>`. Auto-close = no → ask the user what they want: keep open, close, or send follow-up work.

Agents finish at different times - handle each as it completes rather than waiting for all.

## 7. Final summary

When every agent is done, output:

- One paragraph per agent: what it did, key results, file path of its full output.
- Definition-of-done check: met or not, stated plainly.
- Anything a worker surfaced that needs the user's decision.

## 8. Spike follow-up

If this run was a spike/investigation and the results define real implementation work: propose the follow-up fan-out (new plan of attack, same template) and, on approval, run this same skill again from step 3. Do not silently morph the spike agents into implementation agents - implementation gets fresh panes, fresh names, and a fresh definition of done.
