import { test } from "@playwright/test";
import { adminVersion } from "./users";

/**
 * The functional-coverage tests run on the v2 dialect only, and this says so out loud (feature 008).
 *
 * Every test in the `functional` project proves an effect by reading the object back **through the
 * official SysAdmin API directly**, deliberately not through FlightDeck. On IRIS 2026.1 the official
 * API is v1, whose paths are not the v2 paths: FlightDeck reaches them through its translation table
 * (`FlightDeck.Admin.V1Routes`, 208 operations). For the read-back to reach the same object on 2026.1
 * the harness would have to use that table too — and a read-back that goes through the thing under
 * test is not an independent read. It would confirm the translation against itself.
 *
 * So on a v1 instance these tests skip with this reason rather than half-run. What IRIS 2026.1 does is
 * covered by the `limited` project, which asserts on the capability map's own answers; the effect
 * numbers published in `verification/functional-coverage.md` are v2 numbers and are labelled as such.
 *
 * This asks the install which official API it serves — not which release it is, and not what
 * FlightDeck offers. It is a question about where the read-back has to be addressed, which is the one
 * thing the capability map cannot answer: the map describes FlightDeck's operations, and this channel
 * exists precisely to stay outside FlightDeck.
 */

const REASON =
  "the effect tests read back through the official API directly, and on the v1 API (IRIS 2026.1) " +
  "that would require FlightDeck's own translation table, which is not an independent read; " +
  "IRIS 2026.1 is covered by the limited project";

let asked: Promise<number> | null = null;

/** Call once per functional spec file, inside `test.beforeEach`. */
export async function requireV2Dialect(): Promise<void> {
  asked ??= adminVersion().catch(() => 0);
  test.skip((await asked) < 2, REASON);
}
