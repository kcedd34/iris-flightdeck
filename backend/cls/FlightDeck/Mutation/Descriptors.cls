/// Mutation descriptors (feature 002 data-model §1.2), keyed by official operationId. Declared once
/// per operation and consumed only by FlightDeck.Mutation.Service. No privilege is ever stated here.
/// <p>Grades follow research R5; self-protection follows research R7. Predicates see:
/// current, proposed (fields the user changed, or the full object on create), changedFields, kind,
/// isSystem, isFlightDeck, and facts (requiredAuthBits, runtimeRole for FlightDeck's applications).
Class FlightDeck.Mutation.Descriptors [ Abstract ]
{

XData Mutations [ MimeType = application/json ]
{
{
 "PUT /v2/web-app": {
  "kind": "upsert",
  "entityType": "web-apps/web-application",
  "readOperation": "GET /v2/web-app",
  "schema": "Application",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   { "when": {"op": "equals", "path": "isFlightDeck", "value": true}, "grade": "reinforced" },
   { "when": {"op": "and", "all": [
      {"op": "equals", "path": "kind", "value": "edit"},
      {"op": "or", "any": [
        {"op": "equals", "path": "proposed.Enabled", "value": false},
        {"op": "changed", "fields": ["AutheEnabled", "Resource", "MatchRoles", "NameSpace", "DispatchClass"]}
      ]}
     ]}, "grade": "reinforced" }
  ],
  "selfProtection": [
   { "when": {"op": "and", "all": [ {"op": "equals", "path": "isFlightDeck", "value": true}, {"op": "equals", "path": "proposed.Enabled", "value": false} ]} },
   { "when": {"op": "and", "all": [ {"op": "equals", "path": "isFlightDeck", "value": true}, {"op": "changed", "fields": ["NameSpace", "DispatchClass"]} ]} },
   { "when": {"op": "and", "all": [ {"op": "equals", "path": "isFlightDeck", "value": true}, {"op": "bitsCleared", "path": "proposed.AutheEnabled", "bitsPath": "facts.requiredAuthBits"} ]} },
   { "when": {"op": "and", "all": [ {"op": "equals", "path": "isFlightDeck", "value": true}, {"op": "lacksTargetRole", "path": "proposed.MatchRoles", "rolePath": "facts.runtimeRole"} ]} }
  ],
  "impact": "webapp-impact",
  "impactWhen": {"op": "and", "all": [
   {"op": "equals", "path": "kind", "value": "edit"},
   {"op": "or", "any": [
     {"op": "equals", "path": "proposed.Enabled", "value": false},
     {"op": "changed", "fields": ["AutheEnabled", "Resource", "MatchRoles", "NameSpace", "DispatchClass"]}
   ]}
  ]}
 },
 "DELETE /v2/web-app": {
  "kind": "delete",
  "entityType": "web-apps/web-application",
  "readOperation": "GET /v2/web-app",
  "schema": "Application",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   { "when": {"op": "equals", "path": "isSystem", "value": true}, "grade": "maximum", "consequence": "This is a system application. The platform or its tools may stop working." },
   { "when": {"op": "true"}, "grade": "reinforced" }
  ],
  "selfProtection": [
   { "when": {"op": "equals", "path": "isFlightDeck", "value": true} }
  ],
  "impact": "webapp-impact",
  "impactWhen": {"op": "true"}
 },
 "PUT /v2/web-app/pct-access": {
  "kind": "upsert",
  "entityType": "web-apps/pct-access",
  "readOperation": "GET /v2/web-app/pct-access",
  "schema": "WebAppPctAccess",
  "target": "{class}",
  "secretFields": [],
  "grade": [
   { "when": {"op": "equals", "path": "isFlightDeck", "value": true}, "grade": "reinforced" }
  ]
 },
 "FLIGHTDECK REST execute": {
  "kind": "request",
  "target": "{path}",
  "secretFields": [],
  "grade": [
   { "when": {"op": "equals", "path": "request.method", "value": "DELETE"}, "grade": "reinforced" }
  ]
 },
 "DELETE /v2/web-app/pct-access": {
  "kind": "delete",
  "entityType": "web-apps/pct-access",
  "readOperation": "GET /v2/web-app/pct-access",
  "schema": "WebAppPctAccess",
  "target": "{class}",
  "secretFields": [],
  "grade": [
   { "when": {"op": "true"}, "grade": "reinforced" }
  ]
 }
}
}

}
