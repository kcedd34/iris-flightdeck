import re, json

WPM = 150
SLACK = 0.15

SHOTS = [
 (1, "The instrument cluster", 45, None,
  """This is FlightDeck, driving an InterSystems IRIS instance. [pause] The panel on top is the
cluster. CPU and memory come from the host. Shared memory and disk come from the SysAdmin
API. [pause] Every reading refreshes each second, and each one draws its own history beneath it.
Watch the curves fill. That takes a few seconds, and the demo waits for it. [pause] The window lives
in this browser tab. Nothing here is written to the instance, and nothing carries over to another
tab. [pause] The figures beside the instance name are the same readings, kept in view wherever you
go."""),

 (2, "The command palette", 20, None,
  """Control K opens the command palette. [pause] I type F D underscore Demo. The palette searches the
instance itself and groups what it finds by domain. Roles, resources, tasks, a wallet collection.
[pause] Enter opens the highlighted one in place. Escape closes it."""),

 (3, "A deletion, rehearsed", 40, None,
  """Here is the role F D Demo Operator. [pause] Safe mode is on, so this tab is read only. I turn it
off, and that applies to this tab alone. [pause] Now Delete. [pause] Before anything is sent, the
portal shows the rehearsal. The fields that would change, current beside commanded. The impact:
which users lose which privilege, by name. And a confirmation that asks me to type the role's name.
[pause] I cancel. The role is untouched. Nothing reached the instance."""),

 (4, "Safe mode", 25, None,
  """Safe mode belongs to the browser tab. [pause] I open a second tab. It starts read only, while the
first one is still live. [pause] The server enforces this. A change sent from a read-only tab is
refused before it reaches IRIS, so the guarantee holds even when the interface is wrong."""),

 (5, "Web applications and the REST explorer", 35, None,
  """Every web application on the instance, each with an exposure marker. [pause] This one allows
unauthenticated access, and the marker says so. [pause] Now the REST services the instance publishes.
I open FlightDeck's own API, type a path, and send it. [pause] Two hundred, with the time it took.
The request ran inside the instance, and the executor opens no outbound connection. [pause] It runs
as me, with my roles, and extra roles an application grants real callers are not granted here."""),

 (6, "Permissions as a graph", 30, None,
  """The role again, with its effective privileges. [pause] Each one carries the chain of roles that
grants it, so you see where it came from. [pause] And the accounts on this instance, with the
disabled and expired ones marked. [pause] From here you follow the question. Role to the accounts
that hold it, account to what it reaches. A privilege is never shown without its
provenance."""),

 (7, "Self-protection", 40, None,
  """Three refusals. [pause] First, I have disabled the other administrators on this instance. That is
real, and they are restored at the end of this shot. One is left, and I clear its Enabled box. The
portal refuses. The change would leave no administrator, and it names what it counted. [pause]
Second, this process is running my session. Terminate is refused. [pause] Third, this one is a
platform daemon. The instance says it cannot be ended, and the control follows."""),

 (8, "Security and secrets", 25, None,
  """The wallet holds secrets by name. A value is set or replaced here, and never read back. [pause]
Encryption is read only in this portal. The writes are disabled, each with its reason and the path in
the native portal that performs it. [pause] That is a decision, recorded as declined."""),

 (9, "Tasks, and the jump to logs", 30, None,
  """The task list. Each row carries a band of its recent runs. [pause] This task failed. I open it,
and the run history shows the error the platform recorded. [pause] Open the logs of this period.
[pause] The stream arrives filtered on that task and that window, and it says so at the top. There
was no query to compose."""),

 (10, "The unified log stream", 45, None,
  """Five sources, merged into one stream. [pause] Audit and journal come from the official API. System
messages, alerts and the interoperability log are read by FlightDeck, because the API covers none of
them. [pause] Each source reports how much it read. [pause] This line's source stated no level, so
the severity reads unknown. Nothing is guessed. [pause] I open a line, and the original record sits
behind the normalised fields, unedited. [pause] Then follow, which keeps the stream live. This is the
one required area of the brief with no official API behind it."""),

 (11, "The session trail, exported", 25, None,
  """The session trail, opened from the palette by name. [pause] It holds what this session proposed:
the two refusals from a moment ago, each with its reason. [pause] I export it. Secret fields appear
as changed or unchanged, never as values. [pause] The trail lives in this tab. It never reaches the
instance."""),

 (12, "The light theme", 20, None,
  """The same portal in light. [pause] The state colours carry the same meaning in both themes. [pause]
And colour is never the only signal. A state that matters also changes its label or its glyph.
[pause] The choice is remembered for this IRIS account alone."""),
]

ALTERNATES = {
 7: ("The refusal for the process running this session did not land — replaces the middle beat only, between the first refusal and the daemon",
  """Second, I asked to end the process the instance reported as my session, and the confirmation opened
instead of a refusal. [pause] The reason is in the platform. This instance reports no session on the
process, so the rule matches on the process id, and IRIS moves a session between processes between
requests. The refusal is real. It fires on the request that meets it. This click did not meet it."""),
 9: ("The failing task has no recorded run yet — replaces the whole block",
  """The task list. Each row carries a band of its recent runs, so a failure shows without opening
anything. [pause] The demonstration task that fails on purpose has not been run by the scheduler yet,
so there is no failed run to open. [pause] From a failed run, the portal opens the logs of that
period filtered on the task. This instance has not given it one yet."""),
}

def words(text):
    clean = re.sub(r"\[pause\]", " ", text)
    return len([w for w in re.split(r"\s+", clean.strip()) if w])

def budget(seconds):
    return round(seconds / 60 * WPM * (1 - SLACK))

def speak(n):
    return n / WPM * 60

out = ["# FlightDeck demo: narration",
"",
"Read over the recording the driver produces. One block per shot, in the order",
"[`demo-script.md`](demo-script.md) and `frontend/e2e/demo.spec.ts` run them.",
"",
f"Each block is sized to its shot's **minimum** at **{WPM} words per minute**, with about **{int(SLACK*100)}% left over** so the",
"reading is not rushed and can sit inside the shot rather than run to its edge. A 40-second shot",
"takes about 85 words.",
"",
"`[pause]` marks a place to stop and let the screen carry itself. They are where the driver is moving",
"between things, so the reading and the picture stay together.",
"",
"Two shots depend on something the instance may not deliver, and both have a second version below.",
"Check the timed script the run wrote (`verification/demo-run.md`) to see which one happened before",
"recording the voice.",
"",
"For shot 7, the middle beat has three possible outcomes and the main version covers two of them:",
"the control can already be disabled with its reason on it, or the confirmation can open and be",
"refused. Both are the portal refusing, and the line reads the same. The alternative is only for the",
"third, where an ordinary confirmation opens and nothing is refused.",
"",
"---",
""]

total_words = 0
for n, name, minimum, _, text in SHOTS:
    w = words(text)
    total_words += w
    b = budget(minimum)
    out.append(f"## Shot {n} — {name}")
    out.append("")
    out.append(f"**{minimum} s minimum · {w} words · about {speak(w):.0f} s spoken · budget {b} words**")
    out.append("")
    out.append(" ".join(line.strip() for line in text.strip().split("\n")))
    out.append("")
    if n in ALTERNATES:
        alt_title, alt_text = ALTERNATES[n]
        aw = words(alt_text)
        out.append(f"### Alternative — {alt_title}")
        out.append("")
        out.append(f"**{aw} words · about {speak(aw):.0f} s spoken**")
        out.append("")
        out.append(" ".join(line.strip() for line in alt_text.strip().split("\n")))
        out.append("")

out.append("---")
out.append("")
out.append("## Totals")
out.append("")
out.append("| # | Shot | Minimum | Words | Spoken | Budget |")
out.append("|---|---|---|---|---|---|")
for n, name, minimum, _, text in SHOTS:
    w = words(text)
    out.append(f"| {n} | {name} | {minimum} s | {w} | {speak(w):.0f} s | {budget(minimum)} |")
out.append(f"| | **Total** | **{sum(s[2] for s in SHOTS)} s** | **{total_words}** | **{speak(total_words):.0f} s** | **{sum(budget(s[2]) for s in SHOTS)}** |")
out.append("")
out.append("The alternatives are not in the total: only one version of each of shots 7 and 9 is read.")

open("docs/demo-narration.md", "w", encoding="utf-8").write("\n".join(out) + "\n")

print(f"{'#':>3} {'min':>5} {'words':>6} {'budget':>7} {'delta':>6}")
for n, name, minimum, _, text in SHOTS:
    w, b = words(text), budget(minimum)
    print(f"{n:>3} {minimum:>5} {w:>6} {b:>7} {w-b:>+6}")
