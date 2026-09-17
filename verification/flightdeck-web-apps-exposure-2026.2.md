# FlightDeck's own web applications: what is reachable without authentication (IRIS 2026.2), 2026-09-17

Checked before feature 002 tasks. A FlightDeck API reachable without authentication would have been
a defect blocking feature 002. It is not.

**Target**: install `iris-flightdeck-iris-1` (IRIS CE 2026.2, Build 221U), fresh install with demo
data. All requests were anonymous (no `Authorization`, no cookie) unless stated.

## `/api/flightdeck` requires authentication: confirmed

Configuration read through the official API: `AutheEnabled` 32 (Password only),
`DispatchClass` `FlightDeck.API.Router`, `MatchRoles` `FlightDeck_Runtime`.

| Anonymous request | Status |
|---|---|
| `GET /v1/session` | 401 |
| `POST /v1/session` (no credentials) | 401 |
| `GET /v1/openapi.json` | 401 |
| `GET /v1/session/capabilities` | 401 |
| `GET /v1/vitals` | 401 |
| `GET /v1/palette/entities` | 401 |
| `GET /v1/nope` (unknown route) | 401 |

IRIS refuses every request before FlightDeck code runs. That includes the OpenAPI document and
routes that do not exist.

## `/flightdeck` serves only the built static files: confirmed

Configuration: `AutheEnabled` 64 (unauthenticated), `DispatchClass` `FlightDeck.UI.Static`.

The dispatch class has a single route, `GET /(.*)`, and serves files from
`<mgr>/flightdeck/web`:
- it refuses paths containing `..`, a backslash or NUL (404);
- it falls back to `index.html` for deep links.

| Anonymous request | Result |
|---|---|
| `GET /flightdeck/` | 200 `text/html`, 471 B (`index.html`) |
| `GET /flightdeck/web-apps/web-applications` (deep link) | 200, `index.html` |
| `GET /flightdeck/assets/nope.js` (missing file) | 200, `index.html` |
| `GET /flightdeck/../api/flightdeck/v1/vitals` (`--path-as-is`) | 401 (resolved to the API, which requires authentication) |
| `GET /flightdeck/%2e%2e/api/admin/v2/security/users` | 401 |
| `POST`, `PUT`, `DELETE`, `PATCH /flightdeck/x` | 405 each |

Web root contents: exactly the 13 files of the committed `frontend/dist`: `index.html`, one JS
bundle, one CSS bundle and 10 font files. No data, configuration or credential is served.
`index.html` references only its own assets. Everything the SPA shows after sign-in comes from
`/api/flightdeck`, which requires authentication.

## Consequence for feature 002 (spec FR-019, research R10 revised)

The two applications are different exposures, and the list must say so without opening the
inspector:
- `/api/flightdeck` carries **no** unauthenticated marker (Password only);
- `/flightdeck` is marked **"No authentication · static files only"**, not with the stronger marker
  used for an open API.

The distinction is derived from facts, not from FlightDeck's name (Constitution IX, no name
patterns):
- the authentication methods come from the official API;
- the dispatch class declares that it serves static files only;
- the check at list time confirms that the class's compiled `UrlMap` exposes only `GET`/`HEAD`
  routes.

A dispatch class that makes the declaration but exposes other methods is marked as an open API.
