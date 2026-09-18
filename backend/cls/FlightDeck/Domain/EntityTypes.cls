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
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "Application",
  "listSchema": "WebApplicationListItem",
  "facts": "web-application",
  "markers": [
   {
    "id": "open-api",
    "tone": "warning",
    "text": "Open API \u00b7 no authentication",
    "variants": [
     {
      "when": {
       "op": "equals",
       "path": "facts.unauthenticatedOnly",
       "value": false
      },
      "text": "Open API \u00b7 unauthenticated access allowed"
     }
    ],
    "when": {
     "op": "and",
     "all": [
      {
       "op": "equals",
       "path": "facts.unauthenticated",
       "value": true
      },
      {
       "op": "equals",
       "path": "facts.restDispatcher",
       "value": true
      },
      {
       "op": "not",
       "expr": {
        "op": "equals",
        "path": "facts.staticFiles",
        "value": true
       }
      }
     ]
    }
   },
   {
    "id": "static-only",
    "tone": "caution",
    "text": "No authentication \u00b7 static files only",
    "variants": [
     {
      "when": {
       "op": "equals",
       "path": "facts.unauthenticatedOnly",
       "value": false
      },
      "text": "Unauthenticated access allowed \u00b7 static files only"
     }
    ],
    "when": {
     "op": "and",
     "all": [
      {
       "op": "equals",
       "path": "facts.unauthenticated",
       "value": true
      },
      {
       "op": "equals",
       "path": "facts.staticFiles",
       "value": true
      }
     ]
    }
   },
   {
    "id": "no-auth",
    "tone": "caution",
    "text": "No authentication",
    "variants": [
     {
      "when": {
       "op": "equals",
       "path": "facts.unauthenticatedOnly",
       "value": false
      },
      "text": "Unauthenticated access allowed"
     }
    ],
    "when": {
     "op": "and",
     "all": [
      {
       "op": "equals",
       "path": "facts.unauthenticated",
       "value": true
      },
      {
       "op": "not",
       "expr": {
        "op": "equals",
        "path": "facts.restDispatcher",
        "value": true
       }
      },
      {
       "op": "not",
       "expr": {
        "op": "equals",
        "path": "facts.staticFiles",
        "value": true
       }
      }
     ]
    }
   },
   {
    "id": "system",
    "tone": "neutral",
    "text": "System application",
    "when": {
     "op": "equals",
     "path": "facts.system",
     "value": true
    }
   },
   {
    "id": "flightdeck",
    "tone": "neutral",
    "text": "Serves FlightDeck",
    "when": {
     "op": "equals",
     "path": "facts.flightDeck",
     "value": true
    }
   },
   {
    "id": "disabled",
    "tone": "neutral",
    "text": "Disabled",
    "when": {
     "op": "equals",
     "path": "object.Enabled",
     "value": false
    }
   }
  ],
  "links": [
   "resource-roles",
   "role-owners",
   "resource-public",
   "rest-service"
  ],
  "mutations": [
   "PUT /v2/web-app",
   "DELETE /v2/web-app"
  ]
 },
 "web-apps/pct-access": {
  "domain": "web-apps",
  "entityType": "pct-access",
  "label": "Percent class access",
  "section": "percent-class-access",
  "listOperation": "GET /v2/web-app/pct-accesses",
  "detailOperation": "GET /v2/web-app/pct-access",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   },
   {
    "param": "allowType",
    "field": "AllowType"
   },
   {
    "param": "class",
    "field": "Class"
   }
  ],
  "displayName": "{class} ({allowType}) on {name}",
  "schema": "WebAppPctAccess",
  "listSchema": "PercentClassAccessListItem",
  "facts": "",
  "markers": [
   {
    "id": "system",
    "tone": "neutral",
    "text": "System",
    "when": {
     "op": "equals",
     "path": "object.System",
     "value": true
    }
   },
   {
    "id": "denied",
    "tone": "neutral",
    "text": "Access denied",
    "when": {
     "op": "equals",
     "path": "object.AllowAccess",
     "value": false
    }
   }
  ],
  "links": [],
  "mutations": [
   "PUT /v2/web-app/pct-access",
   "DELETE /v2/web-app/pct-access"
  ]
 },
 "permissions/user": {
  "domain": "permissions",
  "entityType": "user",
  "label": "User",
  "section": "users",
  "listOperation": "GET /v2/security/users",
  "detailOperation": "GET /v2/security/user",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "User",
  "listSchema": "UserListItem",
  "facts": "user",
  "markers": [
   {
    "id": "disabled",
    "tone": "caution",
    "text": "Disabled",
    "when": {
     "op": "equals",
     "path": "facts.enabled",
     "value": false
    }
   },
   {
    "id": "expired",
    "tone": "caution",
    "text": "Account expired",
    "when": {
     "op": "equals",
     "path": "facts.expired",
     "value": true
    }
   },
   {
    "id": "external-authentication",
    "tone": "neutral",
    "text": "Authenticated elsewhere",
    "when": {
     "op": "equals",
     "path": "facts.externalAuthentication",
     "value": true
    }
   }
  ],
  "links": [
   "user-roles",
   "effective-privileges",
   "sql-privileges"
  ],
  "mutations": [
   "POST /v2/security/user",
   "PUT /v2/security/user",
   "DELETE /v2/security/user",
   "POST /v2/security/user/password"
  ]
 },
 "permissions/role": {
  "domain": "permissions",
  "entityType": "role",
  "label": "Role",
  "section": "roles",
  "listOperation": "GET /v2/security/roles",
  "detailOperation": "GET /v2/security/role",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "Role",
  "listSchema": "RoleListItem",
  "facts": "",
  "markers": [
   {
    "id": "escalation-only",
    "tone": "neutral",
    "text": "Escalation only",
    "when": {
     "op": "equals",
     "path": "object.EscalationOnly",
     "value": true
    }
   },
   {
    "id": "system",
    "tone": "neutral",
    "text": "System role",
    "when": {
     "op": "equals",
     "path": "object.CreatedBy",
     "value": "System"
    }
   }
  ],
  "links": [
   "role-resources",
   "role-holders",
   "effective-privileges",
   "sql-privileges"
  ],
  "mutations": [
   "PUT /v2/security/role",
   "DELETE /v2/security/role"
  ]
 },
 "permissions/resource": {
  "domain": "permissions",
  "entityType": "resource",
  "label": "Resource",
  "section": "resources",
  "listOperation": "GET /v2/security/resources",
  "detailOperation": "GET /v2/security/resource",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "Resource",
  "listSchema": "ResourceListItem",
  "facts": "",
  "markers": [
   {
    "id": "public",
    "tone": "caution",
    "text": "Public: {object.PublicPermission} for everyone",
    "when": {
     "op": "not",
     "expr": {
      "op": "empty",
      "path": "object.PublicPermission"
     }
    }
   },
   {
    "id": "protected",
    "tone": "neutral",
    "text": "The platform does not allow deleting it",
    "when": {
     "op": "equals",
     "path": "object.AllowDelete",
     "value": false
    }
   }
  ],
  "links": [
   "resource-roles",
   "resource-objects"
  ],
  "mutations": [
   "PUT /v2/security/resource",
   "DELETE /v2/security/resource"
  ]
 },
 "permissions/service": {
  "domain": "permissions",
  "entityType": "service",
  "label": "Service",
  "section": "services",
  "listOperation": "GET /v2/security/services",
  "detailOperation": "GET /v2/security/service",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "Service",
  "listSchema": "ServiceListItem",
  "facts": "",
  "markers": [
   {
    "id": "disabled",
    "tone": "neutral",
    "text": "Disabled",
    "when": {
     "op": "equals",
     "path": "object.Enabled",
     "value": false
    }
   },
   {
    "id": "public",
    "tone": "caution",
    "text": "Public",
    "when": {
     "op": "equals",
     "path": "object.Public",
     "value": true
    }
   }
  ],
  "links": [
   "resource-roles"
  ],
  "mutations": [
   "PUT /v2/security/service"
  ]
 },
 "permissions/privileged-routine": {
  "domain": "permissions",
  "entityType": "privileged-routine",
  "label": "Privileged routine application",
  "section": "privileged-routines",
  "listOperation": "GET /v2/security/privileged-routines",
  "detailOperation": "GET /v2/security/privileged-routine",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "PrivilegedRoutineApplication",
  "listSchema": "PrivilegedRoutineApplicationListItem",
  "facts": "",
  "markers": [
   {
    "id": "disabled",
    "tone": "neutral",
    "text": "Disabled",
    "when": {
     "op": "equals",
     "path": "object.Enabled",
     "value": false
    }
   },
   {
    "id": "system",
    "tone": "neutral",
    "text": "System application",
    "when": {
     "op": "equals",
     "path": "object.IsSystemApp",
     "value": true
    }
   }
  ],
  "links": [
   "resource-roles"
  ],
  "mutations": [
   "PUT /v2/security/privileged-routine",
   "DELETE /v2/security/privileged-routine"
  ]
 },
 "security/tls-configuration": {
  "domain": "security",
  "entityType": "tls-configuration",
  "label": "TLS configuration",
  "section": "tls",
  "listOperation": "GET /v2/security/ssl-configurations",
  "detailOperation": "GET /v2/security/ssl-configuration",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "SSLConfig",
  "listSchema": "SSLConfigurationListItem",
  "facts": "",
  "markers": [
   {
    "id": "disabled",
    "tone": "neutral",
    "text": "Disabled",
    "when": {
     "op": "equals",
     "path": "object.Enabled",
     "value": false
    }
   },
   {
    "id": "server",
    "tone": "neutral",
    "text": "Server",
    "when": {
     "op": "equals",
     "path": "object.Type",
     "value": "Server"
    }
   },
   {
    "id": "validity-unknown",
    "tone": "neutral",
    "text": "Validity not reported by the platform",
    "when": {
     "op": "true"
    }
   }
  ],
  "links": [
   "tls-consumers"
  ],
  "mutations": [
   "PUT /v2/security/ssl-configuration",
   "DELETE /v2/security/ssl-configuration",
   "POST /v2/security/ssl-configuration/test"
  ]
 },
 "security/x509-credential": {
  "domain": "security",
  "entityType": "x509-credential",
  "label": "X.509 credential",
  "section": "x509",
  "listOperation": "GET /v2/security/x509-credentials",
  "detailOperation": "GET /v2/security/x509-credential",
  "keys": [
   {
    "param": "alias",
    "field": "Alias"
   }
  ],
  "displayName": "{alias}",
  "schema": "X509Credential",
  "listSchema": "X509CredentialsListItem",
  "facts": "x509-credential",
  "markers": [
   {
    "id": "expired",
    "tone": "warning",
    "text": "Expired {facts.daysRemaining} days ago",
    "when": {
     "op": "equals",
     "path": "facts.validityBand",
     "value": "expired"
    }
   },
   {
    "id": "expiring",
    "tone": "caution",
    "text": "Expires in {facts.daysRemaining} days",
    "when": {
     "op": "equals",
     "path": "facts.validityBand",
     "value": "expiring"
    }
   },
   {
    "id": "validity-not-read",
    "tone": "neutral",
    "text": "Validity not read",
    "when": {
     "op": "equals",
     "path": "facts.validityBand",
     "value": "not-read"
    }
   },
   {
    "id": "validity-unknown",
    "tone": "neutral",
    "text": "Validity not reported by the platform",
    "when": {
     "op": "equals",
     "path": "facts.validityBand",
     "value": "unknown"
    }
   },
   {
    "id": "private-key",
    "tone": "neutral",
    "text": "Holds a private key",
    "when": {
     "op": "equals",
     "path": "facts.hasPrivateKey",
     "value": true
    }
   }
  ],
  "links": [
   "certificate"
  ],
  "mutations": [
   "POST /v2/security/x509-credential",
   "PUT /v2/security/x509-credential",
   "DELETE /v2/security/x509-credential"
  ]
 },
 "security/wallet-collection": {
  "domain": "security",
  "entityType": "wallet-collection",
  "label": "Wallet collection",
  "section": "wallet",
  "listOperation": "GET /v2/wallet/collections",
  "detailOperation": "GET /v2/wallet/collection",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "WalletCollection",
  "listSchema": "WalletCollectionListItem",
  "facts": "wallet-collection",
  "markers": [
   {
    "id": "secrets",
    "tone": "neutral",
    "text": "{facts.secretCount} secrets",
    "variants": [
     {
      "when": {
       "op": "equals",
       "path": "facts.secretCount",
       "value": 1
      },
      "text": "1 secret"
     }
    ],
    "when": {
     "op": "defined",
     "path": "facts.secretCount"
    }
   }
  ],
  "links": [
   "wallet-secrets",
   "wallet-users"
  ],
  "mutations": [
   "PUT /v2/wallet/collection",
   "DELETE /v2/wallet/collection",
   "PUT /v2/wallet/secret",
   "DELETE /v2/wallet/secret"
  ]
 },
 "security/ldap-configuration": {
  "domain": "security",
  "entityType": "ldap-configuration",
  "label": "LDAP configuration",
  "section": "ldap",
  "listOperation": "GET /v2/security/ldap/configurations",
  "detailOperation": "GET /v2/security/ldap/configuration",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "LDAPConfig",
  "listSchema": "LDAPConfigurationListItem",
  "facts": "",
  "markers": [
   {
    "id": "disabled",
    "tone": "neutral",
    "text": "Disabled",
    "when": {
     "op": "equals",
     "path": "object.Enabled",
     "value": false
    }
   }
  ],
  "links": [],
  "mutations": [
   "PUT /v2/security/ldap/configuration",
   "DELETE /v2/security/ldap/configuration",
   "POST /v2/security/ldap/configuration/search-password",
   "POST /v2/security/ldap/test"
  ]
 },
 "security/mft-connection": {
  "domain": "security",
  "entityType": "mft-connection",
  "label": "MFT connection",
  "section": "mft",
  "listOperation": "GET /v2/security/mft/connections",
  "detailOperation": "GET /v2/security/mft/connection",
  "keys": [
   {
    "param": "connection",
    "field": "Name"
   }
  ],
  "displayName": "{connection}",
  "schema": "MFTConnection",
  "listSchema": "MFTConnectionListItem",
  "facts": "",
  "markers": [
   {
    "id": "authorized",
    "tone": "neutral",
    "text": "Authorized",
    "when": {
     "op": "equals",
     "path": "object.IsAuthorized",
     "value": true
    }
   }
  ],
  "links": [],
  "mutations": [
   "PUT /v2/security/mft/connection",
   "DELETE /v2/security/mft/connection",
   "DELETE /v2/security/mft/connection/token",
   "GET /v2/security/mft/connection/auth-code-url"
  ]
 },
 "security/superserver": {
  "domain": "security",
  "entityType": "superserver",
  "label": "Superserver",
  "section": "superservers",
  "listOperation": "GET /v2/security/superservers",
  "detailOperation": "GET /v2/security/superserver",
  "keys": [
   {
    "param": "port",
    "field": "Port"
   }
  ],
  "displayName": "{port}",
  "schema": "Superserver",
  "listSchema": "SuperserverListItem",
  "facts": "",
  "markers": [
   {
    "id": "disabled",
    "tone": "neutral",
    "text": "Disabled",
    "when": {
     "op": "equals",
     "path": "object.Enabled",
     "value": false
    }
   },
   {
    "id": "system-default",
    "tone": "neutral",
    "text": "System default",
    "when": {
     "op": "equals",
     "path": "object.SystemDefault",
     "value": true
    }
   }
  ],
  "links": [
   "tls-consumers"
  ],
  "mutations": [
   "PUT /v2/security/superserver",
   "DELETE /v2/security/superserver"
  ]
 },
 "security/oauth2-server-definition": {
  "domain": "security",
  "entityType": "oauth2-server-definition",
  "label": "OAuth 2.0 server definition",
  "section": "oauth2",
  "listOperation": "GET /v2/security/oauth2/client/server-definitions",
  "detailOperation": "GET /v2/security/oauth2/client/server-definition",
  "keys": [
   {
    "param": "serverId",
    "field": "ServerId"
   }
  ],
  "displayName": "{serverId}",
  "schema": "OAuth2ServerDefinition",
  "listSchema": "OAuth2AuthorizationServerListItem",
  "facts": "",
  "markers": [],
  "links": [
   "oauth2-clients"
  ],
  "mutations": [
   "PUT /v2/security/oauth2/client/server-definition",
   "DELETE /v2/security/oauth2/client/server-definition",
   "POST /v2/security/oauth2/client/server-definition/initial-access-token",
   "POST /v2/security/oauth2/client/server-definition"
  ]
 },
 "security/oauth2-server-client": {
  "domain": "security",
  "entityType": "oauth2-server-client",
  "label": "OAuth 2.0 client of this server",
  "section": "oauth2",
  "listOperation": "GET /v2/security/oauth2/server/clients",
  "detailOperation": "GET /v2/security/oauth2/server/client",
  "keys": [
   {
    "param": "clientId",
    "field": "ClientId"
   }
  ],
  "displayName": "{clientId}",
  "schema": "OAuth2ServerClient",
  "listSchema": "OAuth2ServerClientListItem",
  "facts": "",
  "markers": [],
  "links": [],
  "mutations": [
   "PUT /v2/security/oauth2/server/client",
   "DELETE /v2/security/oauth2/server/client",
   "POST /v2/security/oauth2/server/client/secret",
   "POST /v2/security/oauth2/server/client"
  ]
 },
 "security/oauth2-resource-server": {
  "domain": "security",
  "entityType": "oauth2-resource-server",
  "label": "OAuth 2.0 resource server",
  "section": "oauth2",
  "listOperation": "GET /v2/security/oauth2/resource-servers",
  "detailOperation": "GET /v2/security/oauth2/resource-server",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "OAuth2ResourceServer",
  "listSchema": "OAuth2ResourceServerListItem",
  "facts": "",
  "markers": [
   {
    "id": "disabled",
    "tone": "neutral",
    "text": "Disabled",
    "when": {
     "op": "equals",
     "path": "object.Enabled",
     "value": false
    }
   }
  ],
  "links": [
   "oauth2-resource-server-mappings"
  ],
  "mutations": [
   "PUT /v2/security/oauth2/resource-server",
   "DELETE /v2/security/oauth2/resource-server",
   "POST /v2/security/oauth2/resource-server/secret"
  ]
 },
 "security/oauth2-client": {
  "domain": "security",
  "entityType": "oauth2-client",
  "label": "OAuth 2.0 client configuration",
  "section": "oauth2",
  "detailOperation": "GET /v2/security/oauth2/client/client-configuration",
  "keys": [
   {
    "param": "applicationName",
    "field": "ApplicationName"
   }
  ],
  "displayName": "{applicationName}",
  "schema": "OAuth2Client",
  "facts": "",
  "markers": [
   {
    "id": "disabled",
    "tone": "neutral",
    "text": "Disabled",
    "when": {
     "op": "equals",
     "path": "object.Enabled",
     "value": false
    }
   }
  ],
  "links": [],
  "mutations": [
   "PUT /v2/security/oauth2/client/client-configuration",
   "DELETE /v2/security/oauth2/client/client-configuration",
   "POST /v2/security/oauth2/client/client-configuration/secrets",
   "POST /v2/security/oauth2/client/client-configuration/register-client",
   "POST /v2/security/oauth2/client/client-configuration/rotate-keys",
   "POST /v2/security/oauth2/revoke"
  ]
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
   {
    "id": "audit-off",
    "tone": "warning",
    "text": "Auditing is off",
    "when": {
     "op": "equals",
     "path": "object.Enabled",
     "value": false
    }
   }
  ],
  "links": [
   "audit-records"
  ],
  "singleton": true,
  "mutations": [
   "PUT /v2/security/audit/enabled",
   "POST /v2/security/audit/record/copy",
   "POST /v2/security/audit/record/purge",
   "POST /v2/security/audit/event/clear-count"
  ]
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
  "links": [
   "encryption-keys",
   "encryption-data-element-keys",
   "encryption-file-keys",
   "encryption-file-admins"
  ],
  "singleton": true,
  "readOnly": true,
  "mutations": [
   "PUT /v2/security/encryption/settings",
   "POST /v2/security/encryption/file",
   "POST /v2/security/encryption/file/activate",
   "POST /v2/security/encryption/key/deactivate"
  ]
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
  "mutations": [
   "PUT /v2/security/web-auth",
   "POST /v2/security/web-auth/smtp-password"
  ]
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
  "mutations": [
   "PUT /v2/security/oauth2/server",
   "DELETE /v2/security/oauth2/server",
   "POST /v2/security/oauth2/server/password"
  ]
 },
 "tasks/task": {
  "domain": "tasks",
  "entityType": "task",
  "label": "Task",
  "section": "tasks",
  "listOperation": "GET /v2/tasks",
  "detailOperation": "GET /v2/task",
  "keys": [
   {
    "param": "id",
    "field": "Id"
   }
  ],
  "displayName": "{object.Name}",
  "schema": "Task",
  "listSchema": "TaskListItem",
  "facts": "task",
  "markers": [
   {
    "id": "system",
    "tone": "neutral",
    "text": "System task",
    "when": {
     "op": "equals",
     "path": "facts.isSystem",
     "value": true
    }
   },
   {
    "id": "suspended",
    "tone": "caution",
    "text": "Suspended",
    "when": {
     "op": "equals",
     "path": "facts.suspended",
     "value": true
    }
   },
   {
    "id": "running",
    "tone": "actual",
    "text": "Running now",
    "when": {
     "op": "equals",
     "path": "facts.running",
     "value": true
    }
   },
   {
    "id": "failing",
    "tone": "warning",
    "text": "Last run failed",
    "when": {
     "op": "equals",
     "path": "facts.lastResult",
     "value": "Error"
    }
   },
   {
    "id": "intermittent",
    "tone": "caution",
    "text": "Intermittent failures",
    "when": {
     "op": "equals",
     "path": "facts.intermittent",
     "value": true
    }
   }
  ],
  "links": [],
  "mutations": [
   "PUT /v2/task",
   "POST /v2/task",
   "DELETE /v2/task",
   "POST /v2/task/suspend",
   "POST /v2/task/resume",
   "POST /v2/task/run"
  ],
  "compose": "task-history"
 },
 "tasks/task-manager": {
  "domain": "tasks",
  "entityType": "task-manager",
  "label": "Task manager",
  "section": "tasks",
  "detailOperation": "GET /v2/task/manager",
  "keys": [],
  "displayName": "Task manager",
  "facts": "task-manager",
  "markers": [
   {
    "id": "manager-suspended",
    "tone": "warning",
    "text": "The task manager is suspended for the whole instance",
    "when": {
     "op": "equals",
     "path": "object.Status",
     "value": "Suspended"
    }
   },
   {
    "id": "manager-stopped",
    "tone": "warning",
    "text": "The task manager is not running",
    "when": {
     "op": "equals",
     "path": "object.Status",
     "value": "Not running"
    }
   }
  ],
  "links": [
   "task-upcoming"
  ],
  "singleton": true,
  "mutations": [
   "POST /v2/task/manager/suspend",
   "POST /v2/task/manager/resume",
   "POST /v2/task/manager/run"
  ]
 },
 "tasks/wqm-category": {
  "domain": "tasks",
  "entityType": "wqm-category",
  "label": "Work queue category",
  "section": "work-queue-categories",
  "listOperation": "GET /v2/wqm-categories",
  "detailOperation": "GET /v2/wqm-category",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "WQMCategory",
  "listSchema": "WQMCategoryListItem",
  "facts": "",
  "markers": [],
  "links": [],
  "mutations": [
   "PUT /v2/wqm-category",
   "DELETE /v2/wqm-category"
  ]
 },
 "tasks/async-result": {
  "domain": "tasks",
  "entityType": "async-result",
  "label": "Async result",
  "section": "async-results",
  "listOperation": "GET /v2/async-results",
  "detailOperation": "GET /v2/async-result",
  "keys": [
   {
    "param": "id",
    "field": "GUID"
   }
  ],
  "displayName": "{object.TaskName}",
  "schema": "AsyncTask",
  "listSchema": "AsyncTaskListItem",
  "facts": "async-result",
  "markers": [
   {
    "id": "async-running",
    "tone": "actual",
    "text": "{object.State}",
    "when": {
     "op": "in",
     "path": "object.State",
     "values": [
      "Queued",
      "Running",
      "Paused"
     ]
    }
   },
   {
    "id": "async-failed",
    "tone": "warning",
    "text": "Failed",
    "when": {
     "op": "equals",
     "path": "object.State",
     "value": "Failed"
    }
   },
   {
    "id": "async-canceled",
    "tone": "neutral",
    "text": "Canceled",
    "when": {
     "op": "equals",
     "path": "object.State",
     "value": "Canceled"
    }
   }
  ],
  "links": [],
  "mutations": [
   "POST /v2/async-result/cancel",
   "POST /v2/async-result/pause",
   "POST /v2/async-result/resume"
  ]
 },
 "system/process": {
  "domain": "system",
  "entityType": "process",
  "label": "Process",
  "section": "processes",
  "listOperation": "GET /v2/processes",
  "detailOperation": "GET /v2/process",
  "keys": [
   {
    "param": "id",
    "field": "Pid"
   }
  ],
  "displayName": "{id}",
  "schema": "Process",
  "listSchema": "ProcessListItem",
  "facts": "process",
  "markers": [
   {
    "id": "own-session",
    "tone": "selected",
    "text": "Serving this request",
    "when": {
     "op": "equals",
     "path": "facts.isThisRequest",
     "value": true
    }
   },
   {
    "id": "not-terminable",
    "tone": "neutral",
    "text": "The instance does not allow terminating this process",
    "when": {
     "op": "equals",
     "path": "facts.canBeTerminated",
     "value": false
    }
   }
  ],
  "links": [],
  "mutations": [
   "POST /v2/process/terminate",
   "POST /v2/process/suspend",
   "POST /v2/process/resume",
   "POST /v2/process/broadcast"
  ]
 },
 "system/database": {
  "domain": "system",
  "entityType": "database",
  "label": "Database",
  "section": "databases",
  "listOperation": "GET /v2/databases",
  "detailOperation": "GET /v2/database",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "ConfigDatabase",
  "listSchema": "ConfigDatabaseListItem",
  "facts": "",
  "markers": [],
  "links": [
   "database-directory"
  ],
  "mutations": [
   "PUT /v2/database",
   "DELETE /v2/database"
  ]
 },
 "system/database-dir": {
  "domain": "system",
  "entityType": "database-dir",
  "label": "Database directory",
  "section": "directories",
  "listOperation": "GET /v2/database-dirs",
  "detailOperation": "GET /v2/database-dir",
  "keys": [
   {
    "param": "dir",
    "field": "Directory"
   }
  ],
  "displayName": "{dir}",
  "schema": "LocalDatabase",
  "listSchema": "LocalDatabaseListItem",
  "facts": "database-dir",
  "markers": [
   {
    "id": "dismounted",
    "tone": "caution",
    "text": "Not mounted",
    "when": {
     "op": "equals",
     "path": "facts.mounted",
     "value": false
    }
   },
   {
    "id": "read-only",
    "tone": "neutral",
    "text": "Read only",
    "when": {
     "op": "equals",
     "path": "facts.readOnly",
     "value": true
    }
   },
   {
    "id": "encrypted",
    "tone": "neutral",
    "text": "Encrypted",
    "when": {
     "op": "equals",
     "path": "facts.encrypted",
     "value": true
    }
   },
   {
    "id": "occupancy",
    "tone": "caution",
    "text": "{facts.occupancyText}",
    "when": {
     "op": "in",
     "path": "facts.occupancyBand",
     "values": [
      "caution",
      "warning"
     ]
    },
    "variants": [
     {
      "when": {
       "op": "equals",
       "path": "facts.occupancyBand",
       "value": "warning"
      },
      "text": "{facts.occupancyText}",
      "tone": "warning"
     }
    ]
   }
  ],
  "links": [
   "database-volumes"
  ],
  "mutations": [
   "PUT /v2/database-dir",
   "POST /v2/database-dir",
   "POST /v2/database-dir/mount",
   "POST /v2/database-dir/dismount",
   "POST /v2/database-dir/expand-volume",
   "POST /v2/database-dir/modify-size",
   "POST /v2/database-dir/compact",
   "POST /v2/database-dir/defragment",
   "POST /v2/database-dir/integrity-check",
   "POST /v2/database-dir/truncate",
   "DELETE /v2/database-dir"
  ]
 },
 "system/namespace": {
  "domain": "system",
  "entityType": "namespace",
  "label": "Namespace",
  "section": "namespaces",
  "listOperation": "GET /v2/namespaces",
  "detailOperation": "GET /v2/namespace",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "Namespace",
  "listSchema": "NamespaceListItem",
  "facts": "",
  "markers": [],
  "links": [
   "global-mappings",
   "package-mappings",
   "routine-mappings"
  ],
  "mutations": [
   "PUT /v2/namespace",
   "DELETE /v2/namespace",
   "POST /v2/namespace/copy-mappings",
   "POST /v2/namespace/enable-interop"
  ]
 },
 "system/global-mapping": {
  "domain": "system",
  "entityType": "global-mapping",
  "label": "Global mapping",
  "section": "namespaces",
  "detailOperation": "GET /v2/namespace/global-mapping",
  "keys": [
   {
    "param": "namespace",
    "field": "Namespace"
   },
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{namespace}",
  "schema": "MapGlobal",
  "facts": "",
  "markers": [],
  "links": [],
  "mutations": [
   "PUT /v2/namespace/global-mapping",
   "DELETE /v2/namespace/global-mapping"
  ]
 },
 "system/package-mapping": {
  "domain": "system",
  "entityType": "package-mapping",
  "label": "Package mapping",
  "section": "namespaces",
  "detailOperation": "GET /v2/namespace/package-mapping",
  "keys": [
   {
    "param": "namespace",
    "field": "Namespace"
   },
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{namespace}",
  "schema": "MapPackage",
  "facts": "",
  "markers": [],
  "links": [],
  "mutations": [
   "PUT /v2/namespace/package-mapping",
   "DELETE /v2/namespace/package-mapping"
  ]
 },
 "system/routine-mapping": {
  "domain": "system",
  "entityType": "routine-mapping",
  "label": "Routine mapping",
  "section": "namespaces",
  "detailOperation": "GET /v2/namespace/routine-mapping",
  "keys": [
   {
    "param": "namespace",
    "field": "Namespace"
   },
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{namespace}",
  "schema": "MapRoutine",
  "facts": "",
  "markers": [],
  "links": [],
  "mutations": [
   "PUT /v2/namespace/routine-mapping",
   "DELETE /v2/namespace/routine-mapping"
  ]
 },
 "system/device": {
  "domain": "system",
  "entityType": "device",
  "label": "Device",
  "section": "devices",
  "listOperation": "GET /v2/devices",
  "detailOperation": "GET /v2/device",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "Device",
  "listSchema": "DeviceListItem",
  "facts": "",
  "markers": [],
  "links": [],
  "mutations": [
   "PUT /v2/device",
   "DELETE /v2/device"
  ]
 },
 "system/device-subtype": {
  "domain": "system",
  "entityType": "device-subtype",
  "label": "Device subtype",
  "section": "devices",
  "listOperation": "GET /v2/device/subtypes",
  "detailOperation": "GET /v2/device/subtype",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "DeviceSubType",
  "listSchema": "DeviceSubTypeListItem",
  "facts": "",
  "markers": [],
  "links": [],
  "mutations": [
   "PUT /v2/device/subtype",
   "DELETE /v2/device/subtype"
  ]
 },
 "system/device-settings": {
  "domain": "system",
  "entityType": "device-settings",
  "label": "Device settings",
  "section": "devices",
  "detailOperation": "GET /v2/device/settings",
  "keys": [],
  "displayName": "Device settings",
  "schema": "DeviceSettings",
  "facts": "",
  "markers": [],
  "links": [],
  "singleton": true,
  "mutations": [
   "PUT /v2/device/settings"
  ]
 },
 "system/license-key": {
  "domain": "system",
  "entityType": "license-key",
  "label": "License key",
  "section": "license",
  "detailOperation": "GET /v2/license/key",
  "keys": [],
  "displayName": "License key",
  "facts": "",
  "markers": [],
  "links": [],
  "singleton": true,
  "mutations": [
   "PUT /v2/license/key",
   "POST /v2/license/key/validate"
  ]
 },
 "system/license-server": {
  "domain": "system",
  "entityType": "license-server",
  "label": "License server",
  "section": "license",
  "listOperation": "GET /v2/license/servers",
  "detailOperation": "GET /v2/license/server",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "LicenseServer",
  "listSchema": "LicenseServerListItem",
  "facts": "",
  "markers": [],
  "links": [],
  "mutations": [
   "PUT /v2/license/server",
   "DELETE /v2/license/server"
  ]
 },
 "system/lock": {
  "domain": "system",
  "entityType": "lock",
  "label": "Lock",
  "section": "locks",
  "listOperation": "GET /v2/locks",
  "keys": [
   {
    "param": "id",
    "field": "DeleteID"
   }
  ],
  "displayName": "{id}",
  "listSchema": "LockListItem",
  "facts": "lock",
  "markers": [
   {
    "id": "not-removable",
    "tone": "neutral",
    "text": "The instance does not allow removing this lock",
    "when": {
     "op": "equals",
     "path": "facts.removable",
     "value": false
    }
   }
  ],
  "links": [],
  "mutations": [
   "DELETE /v2/lock"
  ]
 },
 "system/web-session": {
  "domain": "system",
  "entityType": "web-session",
  "label": "Web session",
  "section": "web-sessions",
  "listOperation": "GET /v2/web-sessions",
  "keys": [
   {
    "param": "id",
    "field": "SessionId"
   }
  ],
  "displayName": "{id}",
  "listSchema": "WebSessionListItem",
  "facts": "",
  "markers": [],
  "links": [],
  "mutations": [
   "DELETE /v2/web-session"
  ]
 },
 "system/ecp-data-server": {
  "domain": "system",
  "entityType": "ecp-data-server",
  "label": "ECP data server",
  "section": "ecp",
  "listOperation": "GET /v2/ecp/data-servers",
  "detailOperation": "GET /v2/ecp/data-server",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "ECPDataServer",
  "listSchema": "ECPDataServerListItem",
  "facts": "",
  "markers": [],
  "links": [
   "ecp-databases"
  ],
  "mutations": [
   "PUT /v2/ecp/data-server",
   "DELETE /v2/ecp/data-server",
   "POST /v2/ecp/data-server/action"
  ]
 },
 "system/ecp-app-server": {
  "domain": "system",
  "entityType": "ecp-app-server",
  "label": "ECP application server",
  "section": "ecp",
  "listOperation": "GET /v2/ecp/application-servers",
  "keys": [
   {
    "param": "name",
    "field": "ClientName"
   }
  ],
  "displayName": "{name}",
  "listSchema": "ECPClientListItem",
  "facts": "",
  "markers": [],
  "links": [],
  "mutations": []
 },
 "system/ecp-ssl-connection": {
  "domain": "system",
  "entityType": "ecp-ssl-connection",
  "label": "ECP SSL connection",
  "section": "ecp",
  "listOperation": "GET /v2/ecp/application-server-ssl-connections",
  "keys": [
   {
    "param": "name",
    "field": "ComputerName"
   }
  ],
  "displayName": "{name}",
  "listSchema": "ECPSSLConnectionListItem",
  "facts": "",
  "markers": [],
  "links": [],
  "mutations": [
   "POST /v2/ecp/application-server-ssl-connection/authorize",
   "POST /v2/ecp/application-server-ssl-connection/reject",
   "DELETE /v2/ecp/application-server-ssl-connection"
  ]
 },
 "system/ecp-settings": {
  "domain": "system",
  "entityType": "ecp-settings",
  "label": "ECP settings",
  "section": "ecp",
  "detailOperation": "GET /v2/ecp/settings",
  "keys": [],
  "displayName": "ECP settings",
  "schema": "ECPSettings",
  "facts": "",
  "markers": [],
  "links": [],
  "singleton": true,
  "mutations": [
   "PUT /v2/ecp/settings"
  ]
 },
 "system/ext-lang-server": {
  "domain": "system",
  "entityType": "ext-lang-server",
  "label": "External language server",
  "section": "external-language-servers",
  "listOperation": "GET /v2/ext-lang-servers",
  "detailOperation": "GET /v2/ext-lang-server",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "LanguageServer",
  "listSchema": "LanguageServerListItem",
  "facts": "",
  "markers": [],
  "links": [
   "language-server-activity"
  ],
  "mutations": [
   "PUT /v2/ext-lang-server",
   "DELETE /v2/ext-lang-server",
   "POST /v2/ext-lang-server/start",
   "POST /v2/ext-lang-server/stop"
  ]
 },
 "system/doc-db": {
  "domain": "system",
  "entityType": "doc-db",
  "label": "DocDB application",
  "section": "docdb",
  "listOperation": "GET /v2/doc-dbs",
  "detailOperation": "GET /v2/doc-db",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "DocDBApplication",
  "listSchema": "DocDBApplicationListItem",
  "facts": "",
  "markers": [],
  "links": [],
  "mutations": [
   "PUT /v2/doc-db",
   "DELETE /v2/doc-db"
  ]
 },
 "system/fs-access-purpose": {
  "domain": "system",
  "entityType": "fs-access-purpose",
  "label": "File access purpose",
  "section": "file-system-access",
  "listOperation": "GET /v2/fs-access-purposes",
  "detailOperation": "GET /v2/fs-access-purpose",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "FSAccessPurpose",
  "listSchema": "FSAccessPurposeListItem",
  "facts": "",
  "markers": [],
  "links": [
   "fs-access-paths"
  ],
  "mutations": [
   "PUT /v2/fs-access-purpose",
   "DELETE /v2/fs-access-purpose",
   "PUT /v2/fs-access-purpose/path",
   "DELETE /v2/fs-access-purpose/path"
  ]
 },
 "security/oauth2-resource-server-mapping": {
  "domain": "security",
  "entityType": "oauth2-resource-server-mapping",
  "label": "Resource server mapping",
  "section": "oauth2",
  "detailOperation": "GET /v2/security/oauth2/resource-server/mapping",
  "keys": [
   {
    "param": "service",
    "field": "Service"
   },
   {
    "param": "key",
    "field": "Key"
   }
  ],
  "displayName": "{key}",
  "schema": "OAuth2ResourceServerMapping",
  "facts": "",
  "markers": [],
  "links": [],
  "mutations": [
   "PUT /v2/security/oauth2/resource-server/mapping",
   "DELETE /v2/security/oauth2/resource-server/mapping"
  ]
 }
}
}

}
