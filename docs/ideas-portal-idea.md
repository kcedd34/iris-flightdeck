# Ideas Portal submission: FlightDeck

**Status**: draft, not yet published. The author publishes it on https://ideas.intersystems.com
under their own account, then replaces the URL line below and the link in `README.md`.

**Published URL**: _pending author publication (2026-09-16)_

---

**Title**: A keyboard-first, safe-by-default management portal built on the SysAdmin API

**Category**: InterSystems IRIS › System Management / Management Portal

**Description**

The Management Portal is complete, but it is organized as a deep tree of pages. Finding a screen
requires knowing where it lives, related objects are not linked to each other, and changes are
applied without a preview of their effect.

With the SysAdmin API (`/api/admin/v2`) available from IRIS 2026.2, a portal can be built entirely
on the official API. This idea proposes one with:

1. **A command palette (Ctrl/Cmd+K)** as the primary entry point. Any administrable object or action
   is one keystroke away.
2. **Safe mode by default.** Every browser tab starts read-only and must be explicitly disarmed.
   The server enforces it too.
3. **A field-by-field diff before every change**, plus impact analysis before security changes
   (which users and objects lose access).
4. **Capabilities derived from the API specification.** Actions a user cannot perform are shown
   disabled with the privilege they need, never hidden.
5. **A unified log stream** covering audit, journal, `messages.log`, alerts and the
   interoperability event log under one normalized schema, with the original record preserved.
6. **Identity fully delegated to IRIS.** The portal stores no credential anywhere.

**Why it matters**: administrators work faster and with fewer mistakes, and the SysAdmin API gets a
reference client that exercises all of its operations.

**Implementation**: FlightDeck for InterSystems IRIS (Open Exchange, MIT license), submitted to
InterSystems Programming Contest #48.
