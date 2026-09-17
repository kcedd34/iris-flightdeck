/// Entity-type descriptors (feature 002 data-model §1.1). Keyed by "domain/entityType".
/// <p>Each type names its official list and detail operations and how official fields identify one
/// object. Markers are predicates over the official object and server-computed facts
/// (FlightDeck.Domain.Facts); none reads an application's name. No privilege is ever stated here.
/// <p>Web application exposure markers follow research R10 and
/// verification/flightdeck-web-apps-exposure-2026.2.md: an unauthenticated REST API is marked more
/// strongly than an unauthenticated application that serves only verified static files.
Class FlightDeck.Domain.EntityTypes [ Abstract ]
{

XData EntityTypes [ MimeType = application/json ]
{
{
 "web-apps/web-application": {
  "domain": "web-apps",
  "entityType": "web-application",
  "label": "Web application",
  "section": "web-applications",
  "listOperation": "GET /v2/web-apps",
  "detailOperation": "GET /v2/web-app",
  "keys": [ {"param": "name", "field": "Name"} ],
  "displayName": "{name}",
  "schema": "Application",
  "listSchema": "WebApplicationListItem",
  "facts": "web-application",
  "markers": [
   {
    "id": "open-api", "tone": "warning", "text": "Open API · no authentication",
    "variants": [ {"when": {"op": "equals", "path": "facts.unauthenticatedOnly", "value": false}, "text": "Open API · unauthenticated access allowed"} ],
    "when": {"op": "and", "all": [
     {"op": "equals", "path": "facts.unauthenticated", "value": true},
     {"op": "equals", "path": "facts.restDispatcher", "value": true},
     {"op": "not", "expr": {"op": "equals", "path": "facts.staticFiles", "value": true}}
    ]}
   },
   {
    "id": "static-only", "tone": "caution", "text": "No authentication · static files only",
    "variants": [ {"when": {"op": "equals", "path": "facts.unauthenticatedOnly", "value": false}, "text": "Unauthenticated access allowed · static files only"} ],
    "when": {"op": "and", "all": [
     {"op": "equals", "path": "facts.unauthenticated", "value": true},
     {"op": "equals", "path": "facts.staticFiles", "value": true}
    ]}
   },
   {
    "id": "no-auth", "tone": "caution", "text": "No authentication",
    "variants": [ {"when": {"op": "equals", "path": "facts.unauthenticatedOnly", "value": false}, "text": "Unauthenticated access allowed"} ],
    "when": {"op": "and", "all": [
     {"op": "equals", "path": "facts.unauthenticated", "value": true},
     {"op": "not", "expr": {"op": "equals", "path": "facts.restDispatcher", "value": true}},
     {"op": "not", "expr": {"op": "equals", "path": "facts.staticFiles", "value": true}}
    ]}
   },
   { "id": "system", "tone": "neutral", "text": "System application", "when": {"op": "equals", "path": "facts.system", "value": true} },
   { "id": "flightdeck", "tone": "neutral", "text": "Serves FlightDeck", "when": {"op": "equals", "path": "facts.flightDeck", "value": true} },
   { "id": "disabled", "tone": "neutral", "text": "Disabled", "when": {"op": "equals", "path": "object.Enabled", "value": false} }
  ],
  "links": ["resource-roles", "role-owners", "resource-public", "rest-service"],
  "mutations": ["PUT /v2/web-app", "DELETE /v2/web-app"]
 },
 "web-apps/pct-access": {
  "domain": "web-apps",
  "entityType": "pct-access",
  "label": "Percent class access",
  "section": "percent-class-access",
  "listOperation": "GET /v2/web-app/pct-accesses",
  "detailOperation": "GET /v2/web-app/pct-access",
  "keys": [ {"param": "name", "field": "Name"}, {"param": "allowType", "field": "AllowType"}, {"param": "class", "field": "Class"} ],
  "displayName": "{class} ({allowType}) on {name}",
  "schema": "WebAppPctAccess",
  "listSchema": "PercentClassAccessListItem",
  "facts": "",
  "markers": [
   { "id": "system", "tone": "neutral", "text": "System", "when": {"op": "equals", "path": "object.System", "value": true} },
   { "id": "denied", "tone": "neutral", "text": "Access denied", "when": {"op": "equals", "path": "object.AllowAccess", "value": false} }
  ],
  "links": [],
  "mutations": ["PUT /v2/web-app/pct-access", "DELETE /v2/web-app/pct-access"]
 },
 "permissions/role": {
  "domain": "permissions",
  "entityType": "role",
  "label": "Role",
  "section": "roles",
  "detailOperation": "GET /v2/security/role",
  "keys": [ {"param": "name", "field": "Name"} ],
  "displayName": "{name}",
  "schema": "Role",
  "facts": "",
  "markers": [],
  "links": [],
  "readOnly": true,
  "mutations": []
 },
 "permissions/user": {
  "domain": "permissions",
  "entityType": "user",
  "label": "User",
  "section": "users",
  "detailOperation": "GET /v2/security/user",
  "keys": [ {"param": "name", "field": "Name"} ],
  "displayName": "{name}",
  "schema": "User",
  "facts": "",
  "markers": [],
  "links": [],
  "readOnly": true,
  "mutations": []
 }
}
}

}
