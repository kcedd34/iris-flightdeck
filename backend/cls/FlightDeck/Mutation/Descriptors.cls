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
 "POST /v2/security/user": {
  "kind": "upsert",
  "entityType": "permissions/user",
  "readOperation": "GET /v2/security/user",
  "schema": "User",
  "target": "{name}",
  "secretFields": ["Password"],
  "bodyShape": "user-create",
  "grade": [ { "when": {"op": "true"}, "grade": "simple" } ]
 },
 "PUT /v2/security/user": {
  "kind": "upsert",
  "entityType": "permissions/user",
  "readOperation": "GET /v2/security/user",
  "schema": "User",
  "target": "{name}",
  "secretFields": ["Password"],
  "grade": [
   { "when": {"op": "checkIncomplete"}, "grade": "reinforced" },
   { "when": {"op": "and", "all": [ {"op": "equals", "path": "facts.selfTarget", "value": true}, {"op": "changed", "fields": ["Roles", "EscalationRoles", "Enabled", "ExpirationDate"]} ]}, "grade": "reinforced", "consequence": "This is your own account. The change takes effect in this session immediately." },
   { "when": {"op": "or", "any": [ {"op": "equals", "path": "proposed.Enabled", "value": false}, {"op": "changed", "fields": ["Roles", "EscalationRoles", "ExpirationDate"]} ]}, "grade": "reinforced" }
  ],
  "selfProtection": [
   { "when": {"op": "lastAdministrator"}, "message": "last-administrator" }
  ],

  "impact": "role-impact",
  "impactWhen": {"op": "changed", "fields": ["Roles", "EscalationRoles", "Enabled"]}
 },
 "DELETE /v2/security/user": {
  "kind": "delete",
  "entityType": "permissions/user",
  "readOperation": "GET /v2/security/user",
  "schema": "User",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   { "when": {"op": "checkIncomplete"}, "grade": "reinforced" },
   { "when": {"op": "equals", "path": "facts.selfTarget", "value": true}, "grade": "maximum", "consequence": "This is your own account. Deleting it ends your access immediately." },
   { "when": {"op": "true"}, "grade": "reinforced" }
  ],
  "selfProtection": [
   { "when": {"op": "lastAdministrator"}, "message": "last-administrator" }
  ],

  "impact": "role-impact",
  "impactWhen": {"op": "true"}
 },
 "POST /v2/security/user/password": {
  "kind": "action",
  "entityType": "permissions/user",
  "params": ["name"],
  "localParams": ["newPassword"],
  "target": "the password of {name}",
  "secretFields": ["NewPassword", "newPassword"],
  "body": {"NewPassword": "{newPassword}"},
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "PUT /v2/security/role": {
  "kind": "upsert",
  "entityType": "permissions/role",
  "readOperation": "GET /v2/security/role",
  "schema": "Role",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   { "when": {"op": "checkIncomplete"}, "grade": "reinforced" },
   { "when": {"op": "changed", "fields": ["Resources", "GrantedRoles"]}, "grade": "reinforced" }
  ],
  "selfProtection": [
   { "when": {"op": "lastAdministrator"}, "message": "last-administrator" }
  ],

  "impact": "role-impact",
  "impactWhen": {"op": "changed", "fields": ["Resources", "GrantedRoles"]}
 },
 "DELETE /v2/security/role": {
  "kind": "delete",
  "entityType": "permissions/role",
  "readOperation": "GET /v2/security/role",
  "schema": "Role",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   { "when": {"op": "checkIncomplete"}, "grade": "reinforced" },
   { "when": {"op": "equals", "path": "isSystem", "value": true}, "grade": "maximum", "consequence": "This is a system role. What depends on it stops working." },
   { "when": {"op": "true"}, "grade": "reinforced" }
  ],
  "selfProtection": [
   { "when": {"op": "lastAdministrator"}, "message": "last-administrator" }
  ],

  "impact": "role-impact",
  "impactWhen": {"op": "true"}
 },
 "PUT /v2/security/resource": {
  "kind": "upsert",
  "entityType": "permissions/resource",
  "readOperation": "GET /v2/security/resource",
  "schema": "Resource",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   { "when": {"op": "changed", "fields": ["PublicPermission"]}, "grade": "reinforced" }
  ],
  "impact": "resource-impact",
  "impactWhen": {"op": "changed", "fields": ["PublicPermission"]}
 },
 "DELETE /v2/security/resource": {
  "kind": "delete",
  "entityType": "permissions/resource",
  "readOperation": "GET /v2/security/resource",
  "schema": "Resource",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   { "when": {"op": "checkIncomplete"}, "grade": "reinforced" },
   { "when": {"op": "true"}, "grade": "reinforced" } ],
  "selfProtection": [
   { "when": {"op": "lastAdministrator"}, "message": "last-administrator" }
  ],

  "impact": "resource-impact",
  "impactWhen": {"op": "true"}
 },
 "PUT /v2/security/service": {
  "kind": "upsert",
  "entityType": "permissions/service",
  "readOperation": "GET /v2/security/service",
  "schema": "Service",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   { "when": {"op": "equals", "path": "proposed.Enabled", "value": false}, "grade": "reinforced" }
  ]
 },
 "PUT /v2/security/privileged-routine": {
  "kind": "upsert",
  "entityType": "permissions/privileged-routine",
  "readOperation": "GET /v2/security/privileged-routine",
  "schema": "PrivilegedRoutineApplication",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   { "when": {"op": "changed", "fields": ["MatchRoles", "Resource", "Routines"]}, "grade": "reinforced" }
  ]
 },
 "DELETE /v2/security/privileged-routine": {
  "kind": "delete",
  "entityType": "permissions/privileged-routine",
  "readOperation": "GET /v2/security/privileged-routine",
  "schema": "PrivilegedRoutineApplication",
  "target": "{name}",
  "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "POST /v2/security/sql-privilege/grant": {
  "kind": "action",
  "entityType": "permissions/user",
  "params": ["namespace", "grantee", "type", "object", "action"],
  "options": ["withGrant"],
  "readOperation": "GET /v2/security/sql-privileges",
  "readParams": {"grantee": "{grantee}", "namespace": "{namespace}", "maxRows": "1000"},
  "rowKey": [ {"field": "Type", "value": "{type}"}, {"field": "Object|Name", "value": "{object}"}, {"field": "Action|Privilege", "value": "{action}"} ],
  "rowLabel": "{action} on {object}",
  "effect": "add",
  "target": "{action} on {object} for {grantee}",
  "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "simple" } ]
 },
 "POST /v2/security/sql-privilege/revoke": {
  "kind": "action",
  "entityType": "permissions/user",
  "params": ["namespace", "grantee", "type", "object", "action"],
  "options": ["withGrant", "cascade", "asGrantor"],
  "readOperation": "GET /v2/security/sql-privileges",
  "readParams": {"grantee": "{grantee}", "namespace": "{namespace}", "maxRows": "1000"},
  "rowKey": [ {"field": "Type", "value": "{type}"}, {"field": "Object|Name", "value": "{object}"}, {"field": "Action|Privilege", "value": "{action}"} ],
  "rowLabel": "{action} on {object}",
  "effect": "remove",
  "target": "{action} on {object} for {grantee}",
  "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ],
  "impact": "sql-privilege-impact",
  "impactWhen": {"op": "true"}
 },
 "POST /v2/security/sql-admin-privilege/grant": {
  "kind": "action",
  "entityType": "permissions/user",
  "params": ["privilege", "grantee", "namespace"],
  "options": ["withGrant"],
  "readOperation": "GET /v2/security/sql-admin-privileges",
  "readParams": {"grantee": "{grantee}", "namespace": "{namespace}", "maxRows": "1000"},
  "rowKey": [ {"field": "Privilege", "value": "{privilege}"} ],
  "rowLabel": "{privilege} in {namespace}",
  "effect": "add",
  "target": "{privilege} for {grantee}",
  "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "simple" } ]
 },
 "POST /v2/security/sql-admin-privilege/revoke": {
  "kind": "action",
  "entityType": "permissions/user",
  "params": ["privilege", "grantee", "namespace"],
  "options": [],
  "readOperation": "GET /v2/security/sql-admin-privileges",
  "readParams": {"grantee": "{grantee}", "namespace": "{namespace}", "maxRows": "1000"},
  "rowKey": [ {"field": "Privilege", "value": "{privilege}"} ],
  "rowLabel": "{privilege} in {namespace}",
  "effect": "remove",
  "target": "{privilege} for {grantee}",
  "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "POST /v2/security/sql-column-privilege/grant": {
  "kind": "action",
  "entityType": "permissions/user",
  "params": ["action", "grantee", "namespace", "object", "column", "type"],
  "options": ["withGrant"],
  "readOperation": "GET /v2/security/sql-column-privileges",
  "readParams": {"grantee": "{grantee}", "namespace": "{namespace}", "object": "{object}", "maxRows": "1000"},
  "rowKey": [ {"field": "Column", "value": "{column}"}, {"field": "Action|Privilege", "value": "{action}"} ],
  "rowLabel": "{action} on {object}.{column}",
  "effect": "add",
  "target": "{action} on {object}.{column} for {grantee}",
  "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "simple" } ]
 },
 "POST /v2/security/sql-column-privilege/revoke": {
  "kind": "action",
  "entityType": "permissions/user",
  "params": ["action", "grantee", "namespace", "object", "column", "type"],
  "options": ["withGrant", "asGrantor"],
  "readOperation": "GET /v2/security/sql-column-privileges",
  "readParams": {"grantee": "{grantee}", "namespace": "{namespace}", "object": "{object}", "maxRows": "1000"},
  "rowKey": [ {"field": "Column", "value": "{column}"}, {"field": "Action|Privilege", "value": "{action}"} ],
  "rowLabel": "{action} on {object}.{column}",
  "effect": "remove",
  "target": "{action} on {object}.{column} for {grantee}",
  "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "PUT /v2/security/ssl-configuration": {
  "kind": "upsert", "entityType": "security/tls-configuration", "readOperation": "GET /v2/security/ssl-configuration",
  "schema": "SSLConfig", "target": "{name}", "secretFields": ["PrivateKeyPassword"],
  "grade": [ { "when": {"op": "or", "any": [ {"op": "equals", "path": "proposed.Enabled", "value": false}, {"op": "changed", "fields": ["CertificateFile", "PrivateKeyFile", "CAFile", "VerifyPeer", "Type"]} ]}, "grade": "reinforced" } ],
  "impact": "tls-impact", "impactWhen": {"op": "true"}
 },
 "DELETE /v2/security/ssl-configuration": {
  "kind": "delete", "entityType": "security/tls-configuration", "readOperation": "GET /v2/security/ssl-configuration",
  "schema": "SSLConfig", "target": "{name}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ],
  "impact": "tls-impact", "impactWhen": {"op": "true"}
 },
 "POST /v2/security/ssl-configuration/test": {
  "kind": "action", "entityType": "security/tls-configuration",
  "params": ["name"], "localParams": ["host", "port"],
  "body": {"Host": "{host}", "Port": "{port}"},
  "target": "a test connection from {name} to {host}:{port}", "secretFields": [],
  "applyNotice": "The platform runs this test itself and takes up to ten seconds to answer a connection it cannot make.",
  "grade": [ { "when": {"op": "true"}, "grade": "simple" } ]
 },
 "POST /v2/security/x509-credential": {
  "kind": "upsert", "entityType": "security/x509-credential", "readOperation": "GET /v2/security/x509-credential",
  "schema": "X509Credential", "target": "{alias}", "secretFields": ["PrivateKeyPassword"],
  "grade": [ { "when": {"op": "true"}, "grade": "simple" } ]
 },
 "PUT /v2/security/x509-credential": {
  "kind": "upsert", "entityType": "security/x509-credential", "readOperation": "GET /v2/security/x509-credential",
  "schema": "X509Credential", "target": "{alias}", "secretFields": ["PrivateKeyPassword"],
  "grade": [ { "when": {"op": "changed", "fields": ["OwnerList", "CAFile", "PeerNames"]}, "grade": "reinforced" } ]
 },
 "DELETE /v2/security/x509-credential": {
  "kind": "delete", "entityType": "security/x509-credential", "readOperation": "GET /v2/security/x509-credential",
  "schema": "X509Credential", "target": "{alias}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "PUT /v2/wallet/collection": {
  "kind": "upsert", "entityType": "security/wallet-collection", "readOperation": "GET /v2/wallet/collection",
  "schema": "WalletCollection", "target": "{name}", "secretFields": [],
  "grade": [ { "when": {"op": "changed", "fields": ["UseResource", "EditResource"]}, "grade": "reinforced" } ],
  "impact": "wallet-impact", "impactWhen": {"op": "true"}
 },
 "DELETE /v2/wallet/collection": {
  "kind": "delete", "entityType": "security/wallet-collection", "readOperation": "GET /v2/wallet/collection",
  "schema": "WalletCollection", "target": "{name}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ],
  "impact": "wallet-impact", "impactWhen": {"op": "true"}
 },
 "PUT /v2/wallet/secret": {
  "kind": "action", "entityType": "security/wallet-collection",
  "params": ["name"], "localParams": ["collection", "type", "secret"],
  "readOperation": "GET /v2/wallet/secrets", "readParams": {"collection": "{collection}", "maxRows": "1000"},
  "rowKey": [ {"field": "Name", "value": "{name}"} ], "rowLabel": "{name}", "effect": "add",
  "body": {"Type": "{type}", "WalletSecretConfig": {"Secret": "{secret}"}},
  "target": "{name}", "secretFields": ["WalletSecretConfig", "Secret", "secret"],
  "grade": [ { "when": {"op": "true"}, "grade": "simple" } ]
 },
 "DELETE /v2/wallet/secret": {
  "kind": "action", "entityType": "security/wallet-collection",
  "params": ["name"], "localParams": ["collection"],
  "readOperation": "GET /v2/wallet/secrets", "readParams": {"collection": "{collection}", "maxRows": "1000"},
  "rowKey": [ {"field": "Name", "value": "{name}"} ], "rowLabel": "{name}", "effect": "remove",
  "target": "{name}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "PUT /v2/security/ldap/configuration": {
  "kind": "upsert", "entityType": "security/ldap-configuration", "readOperation": "GET /v2/security/ldap/configuration",
  "schema": "LDAPConfig", "target": "{name}", "secretFields": ["LDAPSearchPassword"],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "DELETE /v2/security/ldap/configuration": {
  "kind": "delete", "entityType": "security/ldap-configuration", "readOperation": "GET /v2/security/ldap/configuration",
  "schema": "LDAPConfig", "target": "{name}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "POST /v2/security/ldap/configuration/search-password": {
  "kind": "action", "entityType": "security/ldap-configuration",
  "params": ["name"], "localParams": ["searchPassword"],
  "body": {"LDAPSearchPassword": "{searchPassword}"},
  "target": "the search password of {name}", "secretFields": ["LDAPSearchPassword", "searchPassword"],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "PUT /v2/security/mft/connection": {
  "kind": "upsert", "entityType": "security/mft-connection", "readOperation": "GET /v2/security/mft/connection",
  "schema": "MFTConnection", "target": "{connection}", "secretFields": [],
  "grade": [ { "when": {"op": "changed", "fields": ["URL", "SSLConfiguration", "Username", "Service"]}, "grade": "reinforced" } ]
 },
 "DELETE /v2/security/mft/connection": {
  "kind": "delete", "entityType": "security/mft-connection", "readOperation": "GET /v2/security/mft/connection",
  "schema": "MFTConnection", "target": "{connection}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "DELETE /v2/security/mft/connection/token": {
  "kind": "action", "entityType": "security/mft-connection",
  "params": ["connection"],
  "target": "the stored token of {connection}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "PUT /v2/security/superserver": {
  "kind": "upsert", "entityType": "security/superserver", "readOperation": "GET /v2/security/superserver",
  "schema": "Superserver", "target": "{port}", "secretFields": [],
  "grade": [ { "when": {"op": "or", "any": [ {"op": "equals", "path": "proposed.Enabled", "value": false}, {"op": "changed", "fields": ["SSLConfig", "SSLSupportLevel", "EnableECP", "EnableMirror"]} ]}, "grade": "reinforced" } ]
 },
 "DELETE /v2/security/superserver": {
  "kind": "delete", "entityType": "security/superserver", "readOperation": "GET /v2/security/superserver",
  "schema": "Superserver", "target": "{port}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "PUT /v2/security/oauth2/client/server-definition": {
  "kind": "upsert", "entityType": "security/oauth2-server-definition", "readOperation": "GET /v2/security/oauth2/client/server-definition",
  "schema": "OAuth2ServerDefinition", "target": "{serverId}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "DELETE /v2/security/oauth2/client/server-definition": {
  "kind": "delete", "entityType": "security/oauth2-server-definition", "readOperation": "GET /v2/security/oauth2/client/server-definition",
  "schema": "OAuth2ServerDefinition", "target": "{serverId}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "POST /v2/security/oauth2/client/server-definition/initial-access-token": {
  "kind": "action", "entityType": "security/oauth2-server-definition",
  "params": ["serverId"], "localParams": ["initialAccessToken"],
  "body": {"InitialAccessToken": "{initialAccessToken}"},
  "target": "the initial access token of {serverId}", "secretFields": ["InitialAccessToken", "initialAccessToken"],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "PUT /v2/security/oauth2/client/client-configuration": {
  "kind": "upsert", "entityType": "security/oauth2-client", "readOperation": "GET /v2/security/oauth2/client/client-configuration",
  "schema": "OAuth2Client", "target": "{applicationName}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "DELETE /v2/security/oauth2/client/client-configuration": {
  "kind": "delete", "entityType": "security/oauth2-client", "readOperation": "GET /v2/security/oauth2/client/client-configuration",
  "schema": "OAuth2Client", "target": "{applicationName}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "POST /v2/security/oauth2/client/client-configuration/secrets": {
  "kind": "action", "entityType": "security/oauth2-client",
  "params": ["applicationName"], "localParams": ["clientSecret"],
  "body": {"ClientSecret": "{clientSecret}", "ClientPassword": "{clientPassword}"},
  "target": "the secrets of {applicationName}", "secretFields": ["ClientSecret", "ClientPassword", "clientSecret", "clientPassword", "registration_access_token"],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "POST /v2/security/oauth2/client/client-configuration/register-client": {
  "kind": "action", "entityType": "security/oauth2-client",
  "params": ["applicationName"],
  "target": "{applicationName} with its authorization server", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "POST /v2/security/oauth2/client/client-configuration/rotate-keys": {
  "kind": "action", "entityType": "security/oauth2-client",
  "params": ["applicationName"],
  "target": "the keys of {applicationName}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "PUT /v2/security/oauth2/server/client": {
  "kind": "upsert", "entityType": "security/oauth2-server-client", "readOperation": "GET /v2/security/oauth2/server/client",
  "schema": "OAuth2ServerClient", "target": "{clientId}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "DELETE /v2/security/oauth2/server/client": {
  "kind": "delete", "entityType": "security/oauth2-server-client", "readOperation": "GET /v2/security/oauth2/server/client",
  "schema": "OAuth2ServerClient", "target": "{clientId}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "POST /v2/security/oauth2/server/client/secret": {
  "kind": "action", "entityType": "security/oauth2-server-client",
  "params": ["clientId"], "localParams": ["clientSecret"],
  "body": {"ClientSecret": "{clientSecret}"},
  "target": "the client secret of {clientId}", "secretFields": ["ClientSecret", "clientSecret"],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "PUT /v2/security/oauth2/resource-server": {
  "kind": "upsert", "entityType": "security/oauth2-resource-server", "readOperation": "GET /v2/security/oauth2/resource-server",
  "schema": "OAuth2ResourceServer", "target": "{name}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "DELETE /v2/security/oauth2/resource-server": {
  "kind": "delete", "entityType": "security/oauth2-resource-server", "readOperation": "GET /v2/security/oauth2/resource-server",
  "schema": "OAuth2ResourceServer", "target": "{name}", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "POST /v2/security/oauth2/resource-server/secret": {
  "kind": "action", "entityType": "security/oauth2-resource-server",
  "params": ["name"], "localParams": ["clientSecret"],
  "body": {"ClientSecret": "{clientSecret}"},
  "target": "the client secret of {name}", "secretFields": ["ClientSecret", "clientSecret"],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "PUT /v2/security/oauth2/server": {
  "kind": "upsert", "entityType": "security/oauth2-server", "readOperation": "GET /v2/security/oauth2/server",
  "schema": "OAuth2ServerConfiguration", "target": "the authorization server", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "DELETE /v2/security/oauth2/server": {
  "kind": "delete", "entityType": "security/oauth2-server", "readOperation": "GET /v2/security/oauth2/server",
  "schema": "OAuth2ServerConfiguration", "target": "the authorization server", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "maximum", "consequence": "Every client of this authorization server stops being able to authenticate." } ]
 },
 "POST /v2/security/oauth2/server/password": {
  "kind": "action", "entityType": "security/oauth2-server",
  "params": [], "localParams": ["serverPassword"],
  "body": {"ServerPassword": "{serverPassword}"},
  "target": "the authorization server password", "secretFields": ["ServerPassword", "serverPassword"],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "PUT /v2/security/web-auth": {
  "kind": "upsert", "entityType": "security/web-authentication", "readOperation": "GET /v2/security/web-auth",
  "schema": "WebAuthenticationSettings", "target": "web authentication", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "POST /v2/security/web-auth/smtp-password": {
  "kind": "action", "entityType": "security/web-authentication",
  "params": [], "localParams": ["smtpPassword"],
  "body": {"SMPTPPassword": "{smtpPassword}"},
  "target": "the SMTP password", "secretFields": ["SMPTPPassword", "smtpPassword"],
  "grade": [ { "when": {"op": "true"}, "grade": "reinforced" } ]
 },
 "PUT /v2/security/audit/enabled": {
  "kind": "upsert", "entityType": "security/audit-settings", "readOperation": "GET /v2/security/audit/enabled",
  "schema": "AuditingEnabled", "target": "auditing", "secretFields": [],
  "grade": [ { "when": {"op": "equals", "path": "proposed.Enabled", "value": false}, "grade": "reinforced", "consequence": "The instance stops recording security events while auditing is off." } ]
 },
 "POST /v2/security/audit/record/copy": {
  "kind": "action", "entityType": "security/audit-settings",
  "params": [], "localParams": ["auditCopyNamespace"], "optionalParams": ["deleteAfterCopy", "beginDateTime", "endDateTime"],
  "body": {"AuditCopyNamespace": "{auditCopyNamespace}", "DeleteAfterCopy": "{deleteAfterCopy}", "BeginDateTime": "{beginDateTime}", "EndDateTime": "{endDateTime}"},
  "target": "a copy of the audit records to {auditCopyNamespace}", "secretFields": [],
  "grade": [
   { "when": {"op": "equals", "path": "params.deleteAfterCopy", "value": "true"}, "grade": "maximum", "consequence": "Copying with deletion removes the records from this instance's audit trail: it is a purge with another name." },
   { "when": {"op": "true"}, "grade": "reinforced" }
  ]
 },
 "POST /v2/security/audit/record/purge": {
  "kind": "action", "entityType": "security/audit-settings",
  "params": [], "optionalParams": ["beginDateTime", "endDateTime"],
  "body": {"BeginDateTime": "{beginDateTime}", "EndDateTime": "{endDateTime}"},
  "target": "the audit records of this instance", "secretFields": [],
  "grade": [ { "when": {"op": "true"}, "grade": "maximum", "consequence": "This erases the instance's own audit trail, the record that outlives FlightDeck's session trail. It cannot be undone." } ]
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
