import { afterEach, describe, expect, it } from "vitest";
import { readDemoNotice } from "../src/session/demoNotice";

// Feature 007: the published demo prints its credentials under the sign-in form. The property that
// matters is the negative one — a normal install must print nothing — so both sides are asserted
// here, and the e2e suite asserts the absent case against a real install.

function setMeta(content: string | null) {
  document.head.querySelectorAll('meta[name="fd-demo-notice"]').forEach((node) => node.remove());
  if (content === null) return;
  const meta = document.createElement("meta");
  meta.setAttribute("name", "fd-demo-notice");
  meta.setAttribute("content", content);
  document.head.appendChild(meta);
}

afterEach(() => setMeta(null));

describe("readDemoNotice", () => {
  it("answers null when the server injected no notice, which is every normal install", () => {
    setMeta(null);
    expect(readDemoNotice()).toBeNull();
  });

  it("reads the user, the password and the reset cadence the deployment declared", () => {
    setMeta("demo\tS0me-Str0ng-Pass\tevery hour");
    expect(readDemoNotice()).toEqual({ username: "demo", password: "S0me-Str0ng-Pass", reset: "every hour" });
  });

  it("falls back to a neutral cadence when the deployment did not state one", () => {
    setMeta("demo\tS0me-Str0ng-Pass\t");
    expect(readDemoNotice()?.reset).toBe("regularly");
  });

  it("answers null on a half-filled notice rather than printing an incomplete credential", () => {
    setMeta("demo\t\tevery hour");
    expect(readDemoNotice()).toBeNull();
    setMeta("");
    expect(readDemoNotice()).toBeNull();
  });
});
