import { appendFileSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

/**
 * The timed script the demo driver writes while it runs (feature 006, extended).
 *
 * The author records the screen and starts the driver; this writes down what was on screen and when,
 * so the narration or the subtitles can be laid over the recording afterwards without guessing at
 * timings.
 *
 * Two properties it is built for:
 *
 * - **It is written as it happens, not assembled at the end.** Every line is appended and flushed, so
 *   a run that dies halfway still leaves the part that already played. A buffer that only reaches
 *   disk on success would lose exactly the run the author most needs to look at.
 * - **The clock starts at the first visible frame of the application**, not at process start, because
 *   the timestamps have to line up with a screen recording that began before the browser opened.
 *   Whatever the driver did before that — asking the instance to run the failing task, and waiting
 *   for the failure — is reported separately as pre-roll, not folded into the timeline.
 */

export type LineKind = "screen" | "action" | "api" | "setup" | "note";

export interface ShotResult {
  number: number;
  name: string;
  worked: number;
  onScreen: number;
  minimum: number;
  /** Requests the shot made while it was working. */
  requests: number;
  /** Requests the screen went on making while the shot was held for the viewer. */
  held: number;
}

export class Narration {
  private readonly path: string;
  private t0: number | null = null;
  private prerollSeconds = 0;
  private readonly shots: ShotResult[] = [];
  private current: { number: number; name: string } | null = null;

  constructor(path: string) {
    this.path = resolve(path);
    mkdirSync(dirname(this.path), { recursive: true });
    writeFileSync(
      this.path,
      [
        "# FlightDeck demo: timed script",
        "",
        `Written while the driver ran, line by line, on ${new Date().toISOString()}.`,
        "",
        "Timestamps are `mm:ss` from **the first visible frame of the application**, so they line up",
        "with a screen recording started before the command. The pre-roll below is the work the driver",
        "did before the browser showed anything, and is not on the clock.",
        "",
        "Nothing in this run was accelerated, stubbed, skipped or simulated: the driver intercepts no",
        "request and fakes no response. Every wait recorded here is the instance's own.",
        "",
        "`api` lines carry each request the shot made to the portal's API and the status that came",
        "back. Polled endpoints — the instrument cluster at one-second resolution, and the log stream",
        "while following — would bury the rest of the file, so they are counted per shot and reported",
        "at the end of the shot instead of line by line.",
        "",
        "---",
        "",
      ].join("\n"),
      "utf8",
    );
  }

  /** Time the driver spent before the application was on screen. */
  recordPreroll(seconds: number) {
    this.prerollSeconds = seconds;
    this.append(`**Pre-roll: ${seconds.toFixed(1)}s** before the first visible frame — the instance was asked to run the demonstration task that fails on purpose, and the failure was waited for.\n`);
  }

  /** The first visible frame of the application. Everything after this is on the clock. */
  start() {
    this.t0 = Date.now();
    this.append(`\`00:00\` **The recording starts here.** The sign-in form is on screen.\n`);
  }

  private stamp(): string {
    const elapsed = this.t0 === null ? 0 : (Date.now() - this.t0) / 1000;
    const minutes = Math.floor(elapsed / 60);
    const seconds = Math.floor(elapsed % 60);
    return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
  }

  private append(text: string) {
    appendFileSync(this.path, text + "\n", "utf8");
  }

  /** One line of the timeline, stamped at the moment it is written. */
  line(kind: LineKind, text: string) {
    this.append(`\`${this.stamp()}\` &nbsp;&nbsp; \`${kind.padEnd(6)}\` ${text}`);
  }

  shotStart(number: number, name: string) {
    this.current = { number, name };
    this.append("");
    this.append(`## \`${this.stamp()}\` Shot ${number} — ${name}`);
    this.append("");
  }

  shotEnd(result: Omit<ShotResult, "number" | "name">) {
    const shot = this.current!;
    const over = result.worked > result.minimum;
    this.shots.push({ ...shot, ...result });
    this.append("");
    this.append(
      `\`${this.stamp()}\` **Shot ${shot.number} ends.** Work ${result.worked.toFixed(1)}s · on screen ` +
        `${result.onScreen.toFixed(1)}s · minimum ${result.minimum}s · ` +
        (over
          ? `**over by ${(result.worked - result.minimum).toFixed(1)}s** — the instance took longer than the shot allows for, and the shot ran long rather than cutting the wait short.`
          : `held ${(result.onScreen - result.worked).toFixed(1)}s to let the viewer read it.`) +
        ` ${result.requests} request${result.requests === 1 ? "" : "s"} to the instance while working` +
        (result.held > 0 ? `, and ${result.held} more while the screen was held: the portal keeps reading.` : "."),
    );
    this.current = null;
  }

  /** The closing summary: the real total, every shot, and every overrun. */
  finish() {
    const total = this.t0 === null ? 0 : (Date.now() - this.t0) / 1000;
    const minutes = Math.floor(total / 60);
    const seconds = Math.round(total % 60);
    const declared = this.shots.reduce((sum, shot) => sum + shot.minimum, 0);
    const over = this.shots.filter((shot) => shot.worked > shot.minimum);
    this.append("");
    this.append("---");
    this.append("");
    this.append("## Summary");
    this.append("");
    this.append(`**Real total on screen: ${minutes}m ${String(seconds).padStart(2, "0")}s** (${total.toFixed(1)}s), from the first visible frame to the last.`);
    this.append("");
    this.append(`Pre-roll before the clock started: ${this.prerollSeconds.toFixed(1)}s. Sum of the declared minimums: ${declared}s.`);
    this.append("");
    this.append("| # | Shot | Work | On screen | Minimum | Requests (working + held) |");
    this.append("|---|---|---|---|---|---|");
    for (const shot of this.shots) {
      this.append(
        `| ${shot.number} | ${shot.name} | ${shot.worked.toFixed(1)}s | ${shot.onScreen.toFixed(1)}s | ${shot.minimum}s | ${shot.requests} + ${shot.held} |`,
      );
    }
    this.append("");
    if (over.length === 0) {
      this.append("No shot overran its minimum: on this run the portal was ready before the viewer would be.");
    } else {
      this.append("**Shots that overran their minimum**, which means the instance took longer than the shot allows for and the shot ran long rather than cutting the wait short:");
      this.append("");
      for (const shot of over) {
        this.append(`- Shot ${shot.number}, ${shot.name}: over by ${(shot.worked - shot.minimum).toFixed(1)}s (work ${shot.worked.toFixed(1)}s against a ${shot.minimum}s minimum).`);
      }
    }
  }
}
