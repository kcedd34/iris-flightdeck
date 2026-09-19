import { expect, test } from "@playwright/test";

// Feature 007: what FlightDeck's own server does with the built assets.
//
// Every other project in this suite points at the Vite dev server, so `FlightDeck.UI.Static` — the
// class that serves every real install, Docker and IPM alike — was exercised by nothing at all. That
// gap hid a defect for as long as the class has existed: it set a response charset and then wrote
// files that were already UTF-8, so CSP encoded them a second time and every "—", "…", "×" and "→"
// in the interface reached users as mojibake. Nobody saw it because nobody had ever fetched a byte
// from this server under test.
//
// The encoding case is one test here, not the point of the file. The point is that the delivery
// layer — content types, charsets, cache directives, compression, the single-page fallback and the
// refusals — is covered at all.
//
// baseURL is the IRIS origin, not Vite.

const ORIGIN = `http://localhost:${process.env.FLIGHTDECK_PORT ?? "52780"}`;

/** The asset paths the shipped page actually references, read from the page rather than guessed. */
async function assets(request: import("@playwright/test").APIRequestContext) {
  const page = await request.get(`${ORIGIN}/flightdeck/`);
  expect(page.status(), "the portal must serve its page").toBe(200);
  const html = await page.text();
  const script = /src="([^"]*assets\/[^"]+\.js)"/.exec(html)?.[1];
  const style = /href="([^"]*assets\/[^"]+\.css)"/.exec(html)?.[1];
  expect(script, "the page must reference a script").toBeTruthy();
  expect(style, "the page must reference a stylesheet").toBeTruthy();
  return { html, script: script!, style: style! };
}

test("the page is served as HTML, declaring its charset, and is not cached", async ({ request }) => {
  const response = await request.get(`${ORIGIN}/flightdeck/`);
  expect(response.status()).toBe(200);
  expect(response.headers()["content-type"]).toMatch(/^text\/html/);
  expect(response.headers()["content-type"]).toMatch(/charset=utf-8/i);
  // index.html names the hashed assets, so a stale copy points at files that no longer exist.
  expect(response.headers()["cache-control"]).toMatch(/no-cache/i);
});

test("assets carry the content type their extension promises", async ({ request }) => {
  const { script, style } = await assets(request);
  const js = await request.get(`${ORIGIN}${script}`);
  expect(js.status()).toBe(200);
  expect(js.headers()["content-type"]).toMatch(/javascript/);

  const css = await request.get(`${ORIGIN}${style}`);
  expect(css.status()).toBe(200);
  expect(css.headers()["content-type"]).toMatch(/^text\/css/);
});

test("hashed assets are cached immutably, because their name changes when they do", async ({ request }) => {
  const { script } = await assets(request);
  const response = await request.get(`${ORIGIN}${script}`);
  expect(response.headers()["cache-control"]).toMatch(/immutable/);
  expect(response.headers()["cache-control"]).toMatch(/max-age=\d{6,}/);
});

test("the server delivers assets byte-for-byte, without encoding them a second time", async ({ request }) => {
  const { script } = await assets(request);
  const response = await request.get(`${ORIGIN}${script}`, { headers: { "Accept-Encoding": "identity" } });
  const bytes = await response.body();
  const text = bytes.toString("utf8");

  // The interface ships these characters. Read as UTF-8 they must come back as themselves.
  expect(text, "the em dash must survive the trip").toContain("—");
  // Double encoding turns one UTF-8 sequence into its own bytes re-encoded. For "—" (e2 80 94) that
  // is c3 a2 c2 80 c2 94, which is what this file existed to catch.
  expect(
    bytes.includes(Buffer.from([0xc3, 0xa2, 0xc2, 0x80, 0xc2, 0x94])),
    "asset was encoded twice on the way out",
  ).toBe(false);
  // The generic form: a lone 0xc3 followed by 0xa2/0xc2 is the signature of UTF-8 read as Latin-1.
  expect(/Ã[-¿]Â/.test(bytes.toString("latin1")) && text.includes("�"), "replacement characters in the bundle").toBe(false);
});

test("binary assets are not touched at all: the fonts keep their magic bytes", async ({ request }) => {
  const { style } = await assets(request);
  const css = await (await request.get(`${ORIGIN}${style}`)).text();
  const font = /url\(([^)]*\.woff2)\)/.exec(css)?.[1];
  test.skip(!font, "this build references no woff2 font");
  const response = await request.get(`${ORIGIN}${font!.replace(/^.*\/flightdeck/, "/flightdeck")}`, {
    headers: { "Accept-Encoding": "identity" },
  });
  expect(response.status()).toBe(200);
  expect(response.headers()["content-type"]).toMatch(/font\/woff2/);
  // wOF2 — if the server had translated these bytes the header would not survive.
  expect((await response.body()).subarray(0, 4).toString("latin1")).toBe("wOF2");
});

test("the server compresses when the client offers it, and the result decompresses to the same file", async ({ request }) => {
  const { script } = await assets(request);
  const plain = await request.get(`${ORIGIN}${script}`, { headers: { "Accept-Encoding": "identity" } });
  const compressed = await request.get(`${ORIGIN}${script}`, { headers: { "Accept-Encoding": "gzip" } });
  expect(compressed.status()).toBe(200);
  expect(compressed.headers()["content-encoding"], "a 500 KB bundle must not go out uncompressed").toMatch(/gzip/);
  // Playwright decodes the body, so equality here also proves the compressed stream is intact.
  expect((await compressed.body()).equals(await plain.body())).toBe(true);
});

test("a deep link returns the page, so a reload inside the application works", async ({ request }) => {
  const direct = await request.get(`${ORIGIN}/flightdeck/security/tls`);
  expect(direct.status()).toBe(200);
  expect(direct.headers()["content-type"]).toMatch(/^text\/html/);
  const { html } = await assets(request);
  expect(await direct.text(), "the fallback must be the same page").toBe(html);
});

test("a path that tries to leave the web root is refused", async ({ request }) => {
  for (const path of ["/flightdeck/../../../etc/passwd", "/flightdeck/..%2f..%2fetc%2fpasswd", "/flightdeck/..\\..\\windows"]) {
    const response = await request.get(`${ORIGIN}${path}`, { maxRedirects: 0 });
    expect([400, 404], `${path} must not be served`).toContain(response.status());
    expect(await response.text()).not.toContain("root:");
  }
});

test("a browser fetches only the woff2 fonts, so the woff fallbacks cost nothing at load", async ({ page }) => {
  const fonts: string[] = [];
  page.on("request", (request) => {
    if (/\.woff2?($|\?)/.test(request.url())) fonts.push(request.url());
  });
  await page.goto(`${ORIGIN}/flightdeck/`);
  await expect(page.locator("form.credentials")).toBeVisible();
  await page.waitForTimeout(1500);
  expect(fonts.length, "the page should load at least one font").toBeGreaterThan(0);
  expect(fonts.filter((url) => url.endsWith(".woff")), "woff is a fallback and must not be fetched").toEqual([]);
});
