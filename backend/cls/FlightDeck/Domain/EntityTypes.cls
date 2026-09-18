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
 "permissions/user": {
  "domain": "permissions",
  "entityType": "user",
  "label": "User",
  "section": "users",
  "listOperation": "GET /v2/security/users",
  "detailOperation": "GET /v2/security/user",
  "keys": [ {"param": "name", "field": "Name"} ],
  "displayName": "{name}",
  "schema": "User",
  "listSchema": "UserListItem",
  "facts": "user",
  "markers": [
   { "id": "disabled", "tone": "caution", "text": "Disabled", "when": {"op": "equals", "path": "facts.enabled", "value": false} },
   { "id": "expired", "tone": "caution", "text": "Account expired", "when": {"op": "equals", "path": "facts.expired", "value": true} },
   { "id": "external-authentication", "tone": "neutral", "text": "Authenticated elsewhere", "when": {"op": "equals", "path": "facts.externalAuthentication", "value": true} }
  ],
  "links": ["user-roles", "effective-privileges", "sql-privileges"],
  "mutations": ["POST /v2/security/user", "PUT /v2/security/user", "DELETE /v2/security/user", "POST /v2/security/user/password"]
 },
 "permissions/role": {
  "domain": "permissions",
  "entityType": "role",
  "label": "Role",
  "section": "roles",
  "listOperation": "GET /v2/security/roles",
  "detailOperation": "GET /v2/security/role",
  "keys": [ {"param": "name", "field": "Name"} ],
  "displayName": "{name}",
  "schema": "Role",
  "listSchema": "RoleListItem",
  "facts": "",
  "markers": [
   { "id": "escalation-only", "tone": "neutral", "text": "Escalation only", "when": {"op": "equals", "path": "object.EscalationOnly", "value": true} },
   { "id": "system", "tone": "neutral", "text": "System role", "when": {"op": "equals", "path": "object.CreatedBy", "value": "System"} }
  ],
  "links": ["role-resources", "role-holders", "effective-privileges", "sql-privileges"],
  "mutations": ["PUT /v2/security/role", "DELETE /v2/security/role"]
 },
 "permissions/resource": {
  "domain": "permissions",
  "entityType": "resource",
  "label": "Resource",
  "section": "resources",
  "listOperation": "GET /v2/security/resources",
  "detailOperation": "GET /v2/security/resource",
  "keys": [ {"param": "name", "field": "Name"} ],
  "displayName": "{name}",
  "schema": "Resource",
  "listSchema": "ResourceListItem",
  "facts": "",
  "markers": [
   { "id": "public", "tone": "caution", "text": "Public: {object.PublicPermission} for everyone", "when": {"op": "not", "expr": {"op": "empty", "path": "object.PublicPermission"}} },
   { "id": "protected", "tone": "neutral", "text": "The platform does not allow deleting it", "when": {"op": "equals", "path": "object.AllowDelete", "value": false} }
  ],
  "links": ["resource-roles", "resource-objects"],
  "mutations": ["PUT /v2/security/resource", "DELETE /v2/security/resource"]
 },
 "permissions/service": {
  "domain": "permissions",
  "entityType": "service",
  "label": "Service",
  "section": "services",
  "listOperation": "GET /v2/security/services",
  "detailOperation": "GET /v2/security/service",
  "keys": [ {"param": "name", "field": "Name"} ],
  "displayName": "{name}",
  "schema": "Service",
  "listSchema": "ServiceListItem",
  "facts": "",
  "markers": [
   { "id": "disabled", "tone": "neutral", "text": "Disabled", "when": {"op": "equals", "path": "object.Enabled", "value": false} },
   { "id": "public", "tone": "caution", "text": "Public", "when": {"op": "equals", "path": "object.Public", "value": true} }
  ],
  "links": ["resource-roles"],
  "mutations": ["PUT /v2/security/service"]
 },
 "permissions/privileged-routine": {
  "domain": "permissions",
  "entityType": "privileged-routine",
  "label": "Privileged routine application",
  "section": "privileged-routines",
  "listOperation": "GET /v2/security/privileged-routines",
  "detailOperation": "GET /v2/security/privileged-routine",
  "keys": [ {"param": "name", "field": "Name"} ],
  "displayName": "{name}",
  "schema": "PrivilegedRoutineApplication",
  "listSchema": "PrivilegedRoutineApplicationListItem",
  "facts": "",
  "markers": [
   { "id": "disabled", "tone": "neutral", "text": "Disabled", "when": {"op": "equals", "path": "object.Enabled", "value": false} },
   { "id": "system", "tone": "neutral", "text": "System application", "when": {"op": "equals", "path": "object.IsSystemApp", "value": true} }
  ],
  "links": ["resource-roles"],
  "mutations": ["PUT /v2/security/privileged-routine", "DELETE /v2/security/privileged-routine"]
 },
 "security/tls-configuration": {
  "domain": "security",
  "entityType": "tls-configuration",
  "label": "TLS configuration",
  "section": "tls",
  "listOperation": "GET /v2/security/ssl-configurations",
  "detailOperation": "GET /v2/security/ssl-configuration",
  "keys": [ {"param": "name", "field": "Name"} ],
  "displayName": "{name}",
  "schema": "SSLConfig",
  "listSchema": "SSLConfigurationListItem",
  "facts": "",
  "markers": [
   { "id": "disabled", "tone": "neutral", "text": "Disabled", "when": {"op": "equals", "path": "object.Enabled", "value": false} },
   { "id": "server", "tone": "neutral", "text": "Server", "when": {"op": "equals", "path": "object.Type", "value": "Server"} },
   { "id": "validity-unknown", "tone": "neutral", "text": "Validity not reported by the platform", "when": {"op": "true"} }
  ],
  "links": ["tls-consumers"],
  "mutations": ["PUT /v2/security/ssl-configuration", "DELETE /v2/security/ssl-configuration", "POST /v2/security/ssl-configuration/test"]
 },
 "security/x509-credential": {
  "domain": "security",
  "entityType": "x509-credential",
  "label": "X.509 credential",
  "section": "x509",
  "listOperation": "GET /v2/security/x509-credentials",
  "detailOperation": "GET /v2/security/x509-credential",
  "keys": [ {"param": "alias", "field": "Alias"} ],
  "displayName": "{alias}",
  "schema": "X509Credential",
  "listSchema": "X509CredentialsListItem",
  "facts": "x509-credential",
  "markers": [
   { "id": "expired", "tone": "warning", "text": "Expired {facts.daysRemaining} days ago", "when": {"op": "equals", "path": "facts.validityBand", "value": "expired"} },
   { "id": "expiring", "tone": "caution", "text": "Expires in {facts.daysRemaining} days", "when": {"op": "equals", "path": "facts.validityBand", "value": "expiring"} },
   { "id": "validity-not-read", "tone": "neutral", "text": "Validity not read", "when": {"op": "equals", "path": "facts.validityBand", "value": "not-read"} },
   { "id": "validity-unknown", "tone": "neutral", "text": "Validity not reported by the platform", "when": {"op": "equals", "path": "facts.validityBand", "value": "unknown"} },
   { "id": "private-key", "tone": "neutral", "text": "Holds a private key", "when": {"op": "equals", "path": "facts.hasPrivateKey", "value": true} }
  ],
  "links": ["certificate"],
  "mutations": ["POST /v2/security/x509-credential", "PUT /v2/security/x509-credential", "DELETE /v2/security/x509-credential"]
 },
 "security/wallet-collection": {
  "domain": "security",
  "entityType": "wallet-collection",
  "label": "Wallet collection",
  "section": "wallet",
  "listOperation": "GET /v2/wallet/collections",
  "detailOperation": "GET /v2/wallet/collection",
  "keys": [ {"param": "name", "field": "Name"} ],
  "displayName": "{name}",
  "schema": "WalletCollection",
  "listSchema": "WalletCollectionListItem",
  "facts": "wallet-collection",
  "markers": [
   { "id": "secrets", "tone": "neutral", "text": "{facts.secretCount} secrets",
     "variants": [ {"when": {"op": "equals", "path": "facts.secretCount", "value": 1}, "text": "1 secret"} ],
     "when": {"op": "defined", "path": "facts.secretCount"} }
  ],
  "links": ["wallet-secrets", "wallet-users"],
  "mutations": ["PUT /v2/wallet/collection", "DELETE /v2/wallet/collection", "PUT /v2/wallet/secret", "DELETE /v2/wallet/secret"]
 },
 "security/ldap-configuration": {
  "domain": "security",
  "entityType": "ldap-configuration",
  "label": "LDAP configuration",
  "section": "ldap",
  "listOperation": "GET /v2/security/ldap/configurations",
  "detailOperation": "GET /v2/security/ldap/configuration",
  "keys": [ {"param": "name", "field": "Name"} ],
  "displayName": "{name}",
  "schema": "LDAPConfig",
  "listSchema": "LDAPConfigurationListItem",
  "facts": "",
  "markers": [
   { "id": "disabled", "tone": "neutral", "text": "Disabled", "when": {"op": "equals", "path": "object.Enabled", "value": false} }
  ],
  "links": [],
  "mutations": ["PUT /v2/security/ldap/configuration", "DELETE /v2/security/ldap/configuration", "POST /v2/security/ldap/configuration/search-password"]
 },
 "security/mft-connection": {
  "domain": "security",
  "entityType": "mft-connection",
  "label": "MFT connection",
  "section": "mft",
  "listOperation": "GET /v2/security/mft/connections",
  "detailOperation": "GET /v2/security/mft/connection",
  "keys": [ {"param": "connection", "field": "Name"} ],
  "displayName": "{connection}",
  "schema": "MFTConnection",
  "listSchema": "MFTConnectionListItem",
  "facts": "",
  "markers": [
   { "id": "authorized", "tone": "neutral", "text": "Authorized", "when": {"op": "equals", "path": "object.IsAuthorized", "value": true} }
  ],
  "links": [],
  "mutations": ["PUT /v2/security/mft/connection", "DELETE /v2/security/mft/connection", "DELETE /v2/security/mft/connection/token"]
 },
 "security/superserver": {
  "domain": "security",
  "entityType": "superserver",
  "label": "Superserver",
  "section": "superservers",
  "listOperation": "GET /v2/security/superservers",
  "detailOperation": "GET /v2/security/superserver",
  "keys": [ {"param": "port", "field": "Port"} ],
  "displayName": "{port}",
  "schema": "Superserver",
  "listSchema": "SuperserverListItem",
  "facts": "",
  "markers": [
   { "id": "disabled", "tone": "neutral", "text": "Disabled", "when": {"op": "equals", "path": "object.Enabled", "value": false} },
   { "id": "system-default", "tone": "neutral", "text": "System default", "when": {"op": "equals", "path": "object.SystemDefault", "value": true} }
  ],
  "links": ["tls-consumers"],
  "mutations": ["PUT /v2/security/superserver", "DELETE /v2/security/superserver"]
 },
 "security/oauth2-server-definition": {
  "domain": "security",
  "entityType": "oauth2-server-definition",
  "label": "OAuth 2.0 server definition",
  "section": "oauth2",
  "listOperation": "GET /v2/security/oauth2/client/server-definitions",
  "detailOperation": "GET /v2/security/oauth2/client/server-definition",
  "keys": [ {"param": "serverId", "field": "ServerId"} ],
  "displayName": "{serverId}",
  "schema": "OAuth2ServerDefinition",
  "listSchema": "OAuth2AuthorizationServerListItem",
  "facts": "",
  "markers": [],
  "links": ["oauth2-clients"],
  "mutations": ["PUT /v2/security/oauth2/client/server-definition", "DELETE /v2/security/oauth2/client/server-definition", "POST /v2/security/oauth2/client/server-definition/initial-access-token"]
 },
 "security/oauth2-server-client": {
  "domain": "security",
  "entityType": "oauth2-server-client",
  "label": "OAuth 2.0 client of this server",
  "section": "oauth2",
  "listOperation": "GET /v2/security/oauth2/server/clients",
  "detailOperation": "GET /v2/security/oauth2/server/client",
  "keys": [ {"param": "clientId", "field": "ClientId"} ],
  "displayName": "{clientId}",
  "schema": "OAuth2ServerClient",
  "listSchema": "OAuth2ServerClientListItem",
  "facts": "",
  "markers": [],
  "links": [],
  "mutations": ["PUT /v2/security/oauth2/server/client", "DELETE /v2/security/oauth2/server/client", "POST /v2/security/oauth2/server/client/secret"]
 },
 "security/oauth2-resource-server": {
  "domain": "security",
  "entityType": "oauth2-resource-server",
  "label": "OAuth 2.0 resource server",
  "section": "oauth2",
  "listOperation": "GET /v2/security/oauth2/resource-servers",
  "detailOperation": "GET /v2/security/oauth2/resource-server",
  "keys": [ {"param": "name", "field": "Name"} ],
  "displayName": "{name}",
  "schema": "OAuth2ResourceServer",
  "listSchema": "OAuth2ResourceServerListItem",
  "facts": "",
  "markers": [
   { "id": "disabled", "tone": "neutral", "text": "Disabled", "when": {"op": "equals", "path": "object.Enabled", "value": false} }
  ],
  "links": [],
  "mutations": ["PUT /v2/security/oauth2/resource-server", "DELETE /v2/security/oauth2/resource-server", "POST /v2/security/oauth2/resource-server/secret"]
 },
 "security/oauth2-client": {
  "domain": "security",
  "entityType": "oauth2-client",
  "label": "OAuth 2.0 client configuration",
  "section": "oauth2",
  "detailOperation": "GET /v2/security/oauth2/client/client-configuration",
  "keys": [ {"param": "applicationName", "field": "ApplicationName"} ],
  "displayName": "{applicationName}",
  "schema": "OAuth2Client",
  "facts": "",
  "markers": [
   { "id": "disabled", "tone": "neutral", "text": "Disabled", "when": {"op": "equals", "path": "object.Enabled", "value": false} }
  ],
  "links": [],
  "mutations": ["PUT /v2/security/oauth2/client/client-configuration", "DELETE /v2/security/oauth2/client/client-configuration", "POST /v2/security/oauth2/client/client-configuration/secrets", "POST /v2/security/oauth2/client/client-configuration/register-client", "POST /v2/security/oauth2/client/client-configuration/rotate-keys"]
 },
 "security/audit-settings": {
  "domain": "security",
  "entityType": "audit-settings",
  "label": "Auditing",
  "section": "auditing",
  "detailOperation": "GET /v2/security/audit/enabled",
  "keys": [],
  "displayName": "Auditing",
  "schema": "AuditingEnabled",
  "facts": "",
  "markers": [
   { "id": "audit-off", "tone": "warning", "text": "Auditing is off", "when": {"op": "equals", "path": "object.Enabled", "value": false} }
  ],
  "links": [],
  "singleton": true,
  "mutations": ["PUT /v2/security/audit/enabled", "POST /v2/security/audit/record/copy", "POST /v2/security/audit/record/purge"]
 },
 "security/encryption-settings": {
  "domain": "security",
  "entityType": "encryption-settings",
  "label": "Encryption",
  "section": "encryption",
  "detailOperation": "GET /v2/security/encryption/settings",
  "keys": [],
  "displayName": "Encryption settings",
  "schema": "EncryptionSettings",
  "facts": "",
  "markers": [],
  "links": [],
  "singleton": true,
  "readOnly": true,
  "mutations": ["PUT /v2/security/encryption/settings", "POST /v2/security/encryption/file", "POST /v2/security/encryption/file/activate", "POST /v2/security/encryption/key/deactivate"]
 },
 "security/web-authentication": {
  "domain": "security",
  "entityType": "web-authentication",
  "label": "Web authentication",
  "section": "web-authentication",
  "detailOperation": "GET /v2/security/web-auth",
  "keys": [],
  "displayName": "Web authentication",
  "schema": "WebAuthenticationSettings",
  "facts": "",
  "markers": [],
  "links": [],
  "singleton": true,
  "mutations": ["PUT /v2/security/web-auth", "POST /v2/security/web-auth/smtp-password"]
 },
 "security/oauth2-server": {
  "domain": "security",
  "entityType": "oauth2-server",
  "label": "OAuth 2.0 authorization server",
  "section": "oauth2",
  "detailOperation": "GET /v2/security/oauth2/server",
  "keys": [],
  "displayName": "Authorization server",
  "schema": "OAuth2ServerConfiguration",
  "facts": "",
  "markers": [],
  "links": [],
  "singleton": true,
  "mutations": ["PUT /v2/security/oauth2/server", "DELETE /v2/security/oauth2/server", "POST /v2/security/oauth2/server/password"]
 }
}
}

}
