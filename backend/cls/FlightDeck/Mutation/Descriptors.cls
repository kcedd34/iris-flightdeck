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
   {
    "when": {
     "op": "equals",
     "path": "isFlightDeck",
     "value": true
    },
    "grade": "reinforced"
   },
   {
    "when": {
     "op": "and",
     "all": [
      {
       "op": "equals",
       "path": "kind",
       "value": "edit"
      },
      {
       "op": "or",
       "any": [
        {
         "op": "equals",
         "path": "proposed.Enabled",
         "value": false
        },
        {
         "op": "changed",
         "fields": [
          "AutheEnabled",
          "Resource",
          "MatchRoles",
          "NameSpace",
          "DispatchClass"
         ]
        }
       ]
      }
     ]
    },
    "grade": "reinforced"
   }
  ],
  "selfProtection": [
   {
    "when": {
     "op": "and",
     "all": [
      {
       "op": "equals",
       "path": "isFlightDeck",
       "value": true
      },
      {
       "op": "equals",
       "path": "proposed.Enabled",
       "value": false
      }
     ]
    }
   },
   {
    "when": {
     "op": "and",
     "all": [
      {
       "op": "equals",
       "path": "isFlightDeck",
       "value": true
      },
      {
       "op": "changed",
       "fields": [
        "NameSpace",
        "DispatchClass"
       ]
      }
     ]
    }
   },
   {
    "when": {
     "op": "and",
     "all": [
      {
       "op": "equals",
       "path": "isFlightDeck",
       "value": true
      },
      {
       "op": "bitsCleared",
       "path": "proposed.AutheEnabled",
       "bitsPath": "facts.requiredAuthBits"
      }
     ]
    }
   },
   {
    "when": {
     "op": "and",
     "all": [
      {
       "op": "equals",
       "path": "isFlightDeck",
       "value": true
      },
      {
       "op": "lacksTargetRole",
       "path": "proposed.MatchRoles",
       "rolePath": "facts.runtimeRole"
      }
     ]
    }
   }
  ],
  "impact": "webapp-impact",
  "impactWhen": {
   "op": "and",
   "all": [
    {
     "op": "equals",
     "path": "kind",
     "value": "edit"
    },
    {
     "op": "or",
     "any": [
      {
       "op": "equals",
       "path": "proposed.Enabled",
       "value": false
      },
      {
       "op": "changed",
       "fields": [
        "AutheEnabled",
        "Resource",
        "MatchRoles",
        "NameSpace",
        "DispatchClass"
       ]
      }
     ]
    }
   ]
  }
 },
 "DELETE /v2/web-app": {
  "kind": "delete",
  "entityType": "web-apps/web-application",
  "readOperation": "GET /v2/web-app",
  "schema": "Application",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "equals",
     "path": "isSystem",
     "value": true
    },
    "grade": "maximum",
    "consequence": "This is a system application. The platform or its tools may stop working."
   },
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ],
  "selfProtection": [
   {
    "when": {
     "op": "equals",
     "path": "isFlightDeck",
     "value": true
    }
   }
  ],
  "impact": "webapp-impact",
  "impactWhen": {
   "op": "true"
  }
 },
 "PUT /v2/web-app/pct-access": {
  "kind": "upsert",
  "entityType": "web-apps/pct-access",
  "readOperation": "GET /v2/web-app/pct-access",
  "schema": "WebAppPctAccess",
  "target": "{class}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "equals",
     "path": "isFlightDeck",
     "value": true
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/security/user": {
  "kind": "upsert",
  "entityType": "permissions/user",
  "readOperation": "GET /v2/security/user",
  "schema": "User",
  "target": "{name}",
  "secretFields": [
   "Password"
  ],
  "bodyShape": "user-create",
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "PUT /v2/security/user": {
  "kind": "upsert",
  "entityType": "permissions/user",
  "readOperation": "GET /v2/security/user",
  "schema": "User",
  "target": "{name}",
  "secretFields": [
   "Password"
  ],
  "grade": [
   {
    "when": {
     "op": "checkIncomplete"
    },
    "grade": "reinforced"
   },
   {
    "when": {
     "op": "and",
     "all": [
      {
       "op": "equals",
       "path": "facts.selfTarget",
       "value": true
      },
      {
       "op": "changed",
       "fields": [
        "Roles",
        "EscalationRoles",
        "Enabled",
        "ExpirationDate"
       ]
      }
     ]
    },
    "grade": "reinforced",
    "consequence": "This is your own account. The change takes effect in this session immediately."
   },
   {
    "when": {
     "op": "or",
     "any": [
      {
       "op": "equals",
       "path": "proposed.Enabled",
       "value": false
      },
      {
       "op": "changed",
       "fields": [
        "Roles",
        "EscalationRoles",
        "ExpirationDate"
       ]
      }
     ]
    },
    "grade": "reinforced"
   }
  ],
  "selfProtection": [
   {
    "when": {
     "op": "lastAdministrator"
    },
    "message": "last-administrator"
   }
  ],
  "impact": "role-impact",
  "impactWhen": {
   "op": "changed",
   "fields": [
    "Roles",
    "EscalationRoles",
    "Enabled"
   ]
  }
 },
 "DELETE /v2/security/user": {
  "kind": "delete",
  "entityType": "permissions/user",
  "readOperation": "GET /v2/security/user",
  "schema": "User",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "checkIncomplete"
    },
    "grade": "reinforced"
   },
   {
    "when": {
     "op": "equals",
     "path": "facts.selfTarget",
     "value": true
    },
    "grade": "maximum",
    "consequence": "This is your own account. Deleting it ends your access immediately."
   },
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ],
  "selfProtection": [
   {
    "when": {
     "op": "lastAdministrator"
    },
    "message": "last-administrator"
   }
  ],
  "impact": "role-impact",
  "impactWhen": {
   "op": "true"
  }
 },
 "POST /v2/security/user/password": {
  "kind": "action",
  "entityType": "permissions/user",
  "params": [
   "name"
  ],
  "localParams": [
   "newPassword"
  ],
  "target": "the password of {name}",
  "secretFields": [
   "NewPassword",
   "newPassword"
  ],
  "body": {
   "NewPassword": "{newPassword}"
  },
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/security/role": {
  "kind": "upsert",
  "entityType": "permissions/role",
  "readOperation": "GET /v2/security/role",
  "schema": "Role",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "checkIncomplete"
    },
    "grade": "reinforced"
   },
   {
    "when": {
     "op": "changed",
     "fields": [
      "Resources",
      "GrantedRoles"
     ]
    },
    "grade": "reinforced"
   }
  ],
  "selfProtection": [
   {
    "when": {
     "op": "lastAdministrator"
    },
    "message": "last-administrator"
   }
  ],
  "impact": "role-impact",
  "impactWhen": {
   "op": "changed",
   "fields": [
    "Resources",
    "GrantedRoles"
   ]
  }
 },
 "DELETE /v2/security/role": {
  "kind": "delete",
  "entityType": "permissions/role",
  "readOperation": "GET /v2/security/role",
  "schema": "Role",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "checkIncomplete"
    },
    "grade": "reinforced"
   },
   {
    "when": {
     "op": "equals",
     "path": "isSystem",
     "value": true
    },
    "grade": "maximum",
    "consequence": "This is a system role. What depends on it stops working."
   },
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ],
  "selfProtection": [
   {
    "when": {
     "op": "lastAdministrator"
    },
    "message": "last-administrator"
   }
  ],
  "impact": "role-impact",
  "impactWhen": {
   "op": "true"
  }
 },
 "PUT /v2/security/resource": {
  "kind": "upsert",
  "entityType": "permissions/resource",
  "readOperation": "GET /v2/security/resource",
  "schema": "Resource",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "changed",
     "fields": [
      "PublicPermission"
     ]
    },
    "grade": "reinforced"
   }
  ],
  "impact": "resource-impact",
  "impactWhen": {
   "op": "changed",
   "fields": [
    "PublicPermission"
   ]
  }
 },
 "DELETE /v2/security/resource": {
  "kind": "delete",
  "entityType": "permissions/resource",
  "readOperation": "GET /v2/security/resource",
  "schema": "Resource",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "checkIncomplete"
    },
    "grade": "reinforced"
   },
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ],
  "selfProtection": [
   {
    "when": {
     "op": "lastAdministrator"
    },
    "message": "last-administrator"
   }
  ],
  "impact": "resource-impact",
  "impactWhen": {
   "op": "true"
  }
 },
 "PUT /v2/security/service": {
  "kind": "upsert",
  "entityType": "permissions/service",
  "readOperation": "GET /v2/security/service",
  "schema": "Service",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "equals",
     "path": "proposed.Enabled",
     "value": false
    },
    "grade": "reinforced"
   }
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
   {
    "when": {
     "op": "changed",
     "fields": [
      "MatchRoles",
      "Resource",
      "Routines"
     ]
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /v2/security/privileged-routine": {
  "kind": "delete",
  "entityType": "permissions/privileged-routine",
  "readOperation": "GET /v2/security/privileged-routine",
  "schema": "PrivilegedRoutineApplication",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/security/sql-privilege/grant": {
  "kind": "action",
  "entityType": "permissions/user",
  "params": [
   "namespace",
   "grantee",
   "type",
   "object",
   "action"
  ],
  "options": [
   "withGrant"
  ],
  "readOperation": "GET /v2/security/sql-privileges",
  "readParams": {
   "grantee": "{grantee}",
   "namespace": "{namespace}",
   "maxRows": "1000"
  },
  "rowKey": [
   {
    "field": "Type",
    "value": "{type}"
   },
   {
    "field": "Object|Name",
    "value": "{object}"
   },
   {
    "field": "Action|Privilege",
    "value": "{action}"
   }
  ],
  "rowLabel": "{action} on {object}",
  "effect": "add",
  "target": "{action} on {object} for {grantee}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /v2/security/sql-privilege/revoke": {
  "kind": "action",
  "entityType": "permissions/user",
  "params": [
   "namespace",
   "grantee",
   "type",
   "object",
   "action"
  ],
  "options": [
   "withGrant",
   "cascade",
   "asGrantor"
  ],
  "readOperation": "GET /v2/security/sql-privileges",
  "readParams": {
   "grantee": "{grantee}",
   "namespace": "{namespace}",
   "maxRows": "1000"
  },
  "rowKey": [
   {
    "field": "Type",
    "value": "{type}"
   },
   {
    "field": "Object|Name",
    "value": "{object}"
   },
   {
    "field": "Action|Privilege",
    "value": "{action}"
   }
  ],
  "rowLabel": "{action} on {object}",
  "effect": "remove",
  "target": "{action} on {object} for {grantee}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ],
  "impact": "sql-privilege-impact",
  "impactWhen": {
   "op": "true"
  }
 },
 "POST /v2/security/sql-admin-privilege/grant": {
  "kind": "action",
  "entityType": "permissions/user",
  "params": [
   "privilege",
   "grantee",
   "namespace"
  ],
  "options": [
   "withGrant"
  ],
  "readOperation": "GET /v2/security/sql-admin-privileges",
  "readParams": {
   "grantee": "{grantee}",
   "namespace": "{namespace}",
   "maxRows": "1000"
  },
  "rowKey": [
   {
    "field": "Privilege",
    "value": "{privilege}"
   }
  ],
  "rowLabel": "{privilege} in {namespace}",
  "effect": "add",
  "target": "{privilege} for {grantee}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /v2/security/sql-admin-privilege/revoke": {
  "kind": "action",
  "entityType": "permissions/user",
  "params": [
   "privilege",
   "grantee",
   "namespace"
  ],
  "options": [],
  "readOperation": "GET /v2/security/sql-admin-privileges",
  "readParams": {
   "grantee": "{grantee}",
   "namespace": "{namespace}",
   "maxRows": "1000"
  },
  "rowKey": [
   {
    "field": "Privilege",
    "value": "{privilege}"
   }
  ],
  "rowLabel": "{privilege} in {namespace}",
  "effect": "remove",
  "target": "{privilege} for {grantee}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/security/sql-column-privilege/grant": {
  "kind": "action",
  "entityType": "permissions/user",
  "params": [
   "action",
   "grantee",
   "namespace",
   "object",
   "column",
   "type"
  ],
  "options": [
   "withGrant"
  ],
  "readOperation": "GET /v2/security/sql-column-privileges",
  "readParams": {
   "grantee": "{grantee}",
   "namespace": "{namespace}",
   "object": "{object}",
   "maxRows": "1000"
  },
  "rowKey": [
   {
    "field": "Column",
    "value": "{column}"
   },
   {
    "field": "Action|Privilege",
    "value": "{action}"
   }
  ],
  "rowLabel": "{action} on {object}.{column}",
  "effect": "add",
  "target": "{action} on {object}.{column} for {grantee}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /v2/security/sql-column-privilege/revoke": {
  "kind": "action",
  "entityType": "permissions/user",
  "params": [
   "action",
   "grantee",
   "namespace",
   "object",
   "column",
   "type"
  ],
  "options": [
   "withGrant",
   "asGrantor"
  ],
  "readOperation": "GET /v2/security/sql-column-privileges",
  "readParams": {
   "grantee": "{grantee}",
   "namespace": "{namespace}",
   "object": "{object}",
   "maxRows": "1000"
  },
  "rowKey": [
   {
    "field": "Column",
    "value": "{column}"
   },
   {
    "field": "Action|Privilege",
    "value": "{action}"
   }
  ],
  "rowLabel": "{action} on {object}.{column}",
  "effect": "remove",
  "target": "{action} on {object}.{column} for {grantee}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/security/ssl-configuration": {
  "kind": "upsert",
  "entityType": "security/tls-configuration",
  "readOperation": "GET /v2/security/ssl-configuration",
  "schema": "SSLConfig",
  "target": "{name}",
  "secretFields": [
   "PrivateKeyPassword"
  ],
  "grade": [
   {
    "when": {
     "op": "or",
     "any": [
      {
       "op": "equals",
       "path": "proposed.Enabled",
       "value": false
      },
      {
       "op": "changed",
       "fields": [
        "CertificateFile",
        "PrivateKeyFile",
        "CAFile",
        "VerifyPeer",
        "Type"
       ]
      }
     ]
    },
    "grade": "reinforced"
   }
  ],
  "impact": "tls-impact",
  "impactWhen": {
   "op": "true"
  }
 },
 "DELETE /v2/security/ssl-configuration": {
  "kind": "delete",
  "entityType": "security/tls-configuration",
  "readOperation": "GET /v2/security/ssl-configuration",
  "schema": "SSLConfig",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ],
  "impact": "tls-impact",
  "impactWhen": {
   "op": "true"
  }
 },
 "POST /v2/security/ssl-configuration/test": {
  "kind": "action",
  "entityType": "security/tls-configuration",
  "params": [
   "name"
  ],
  "localParams": [
   "host",
   "port"
  ],
  "body": {
   "Host": "{host}",
   "Port": "{port}"
  },
  "target": "a test connection from {name} to {host}:{port}",
  "secretFields": [],
  "applyNotice": "The platform runs this test itself and takes up to ten seconds to answer a connection it cannot make.",
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /v2/security/x509-credential": {
  "kind": "upsert",
  "entityType": "security/x509-credential",
  "readOperation": "GET /v2/security/x509-credential",
  "schema": "X509Credential",
  "target": "{alias}",
  "secretFields": [
   "PrivateKeyPassword"
  ],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "PUT /v2/security/x509-credential": {
  "kind": "upsert",
  "entityType": "security/x509-credential",
  "readOperation": "GET /v2/security/x509-credential",
  "schema": "X509Credential",
  "target": "{alias}",
  "secretFields": [
   "PrivateKeyPassword"
  ],
  "grade": [
   {
    "when": {
     "op": "changed",
     "fields": [
      "OwnerList",
      "CAFile",
      "PeerNames"
     ]
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /v2/security/x509-credential": {
  "kind": "delete",
  "entityType": "security/x509-credential",
  "readOperation": "GET /v2/security/x509-credential",
  "schema": "X509Credential",
  "target": "{alias}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/wallet/collection": {
  "kind": "upsert",
  "entityType": "security/wallet-collection",
  "readOperation": "GET /v2/wallet/collection",
  "schema": "WalletCollection",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "changed",
     "fields": [
      "UseResource",
      "EditResource"
     ]
    },
    "grade": "reinforced"
   }
  ],
  "impact": "wallet-impact",
  "impactWhen": {
   "op": "true"
  }
 },
 "DELETE /v2/wallet/collection": {
  "kind": "delete",
  "entityType": "security/wallet-collection",
  "readOperation": "GET /v2/wallet/collection",
  "schema": "WalletCollection",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ],
  "impact": "wallet-impact",
  "impactWhen": {
   "op": "true"
  }
 },
 "PUT /v2/wallet/secret": {
  "kind": "action",
  "entityType": "security/wallet-collection",
  "params": [
   "name"
  ],
  "localParams": [
   "collection",
   "type",
   "secret"
  ],
  "readOperation": "GET /v2/wallet/secrets",
  "readParams": {
   "collection": "{collection}",
   "maxRows": "1000"
  },
  "rowKey": [
   {
    "field": "Name",
    "value": "{name}"
   }
  ],
  "rowLabel": "{name}",
  "effect": "add",
  "body": {
   "Type": "{type}",
   "WalletSecretConfig": {
    "Secret": "{secret}"
   }
  },
  "target": "{name}",
  "secretFields": [
   "WalletSecretConfig",
   "Secret",
   "secret"
  ],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "DELETE /v2/wallet/secret": {
  "kind": "action",
  "entityType": "security/wallet-collection",
  "params": [
   "name"
  ],
  "localParams": [
   "collection"
  ],
  "readOperation": "GET /v2/wallet/secrets",
  "readParams": {
   "collection": "{collection}",
   "maxRows": "1000"
  },
  "rowKey": [
   {
    "field": "Name",
    "value": "{name}"
   }
  ],
  "rowLabel": "{name}",
  "effect": "remove",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/security/ldap/configuration": {
  "kind": "upsert",
  "entityType": "security/ldap-configuration",
  "readOperation": "GET /v2/security/ldap/configuration",
  "schema": "LDAPConfig",
  "target": "{name}",
  "secretFields": [
   "LDAPSearchPassword"
  ],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /v2/security/ldap/configuration": {
  "kind": "delete",
  "entityType": "security/ldap-configuration",
  "readOperation": "GET /v2/security/ldap/configuration",
  "schema": "LDAPConfig",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/security/ldap/configuration/search-password": {
  "kind": "action",
  "entityType": "security/ldap-configuration",
  "params": [
   "name"
  ],
  "localParams": [
   "searchPassword"
  ],
  "body": {
   "LDAPSearchPassword": "{searchPassword}"
  },
  "target": "the search password of {name}",
  "secretFields": [
   "LDAPSearchPassword",
   "searchPassword"
  ],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/security/mft/connection": {
  "kind": "upsert",
  "entityType": "security/mft-connection",
  "readOperation": "GET /v2/security/mft/connection",
  "schema": "MFTConnection",
  "target": "{connection}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "changed",
     "fields": [
      "URL",
      "SSLConfiguration",
      "Username",
      "Service"
     ]
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /v2/security/mft/connection": {
  "kind": "delete",
  "entityType": "security/mft-connection",
  "readOperation": "GET /v2/security/mft/connection",
  "schema": "MFTConnection",
  "target": "{connection}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /v2/security/mft/connection/token": {
  "kind": "action",
  "entityType": "security/mft-connection",
  "params": [
   "connection"
  ],
  "target": "the stored token of {connection}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/security/superserver": {
  "kind": "upsert",
  "entityType": "security/superserver",
  "readOperation": "GET /v2/security/superserver",
  "schema": "Superserver",
  "target": "{port}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "or",
     "any": [
      {
       "op": "equals",
       "path": "proposed.Enabled",
       "value": false
      },
      {
       "op": "changed",
       "fields": [
        "SSLConfig",
        "SSLSupportLevel",
        "EnableECP",
        "EnableMirror"
       ]
      }
     ]
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /v2/security/superserver": {
  "kind": "delete",
  "entityType": "security/superserver",
  "readOperation": "GET /v2/security/superserver",
  "schema": "Superserver",
  "target": "{port}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/security/oauth2/client/server-definition": {
  "kind": "upsert",
  "entityType": "security/oauth2-server-definition",
  "readOperation": "GET /v2/security/oauth2/client/server-definition",
  "schema": "OAuth2ServerDefinition",
  "target": "{serverId}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /v2/security/oauth2/client/server-definition": {
  "kind": "delete",
  "entityType": "security/oauth2-server-definition",
  "readOperation": "GET /v2/security/oauth2/client/server-definition",
  "schema": "OAuth2ServerDefinition",
  "target": "{serverId}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/security/oauth2/client/server-definition/initial-access-token": {
  "kind": "action",
  "entityType": "security/oauth2-server-definition",
  "params": [
   "serverId"
  ],
  "localParams": [
   "initialAccessToken"
  ],
  "body": {
   "InitialAccessToken": "{initialAccessToken}"
  },
  "target": "the initial access token of {serverId}",
  "secretFields": [
   "InitialAccessToken",
   "initialAccessToken"
  ],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/security/oauth2/client/client-configuration": {
  "kind": "upsert",
  "entityType": "security/oauth2-client",
  "readOperation": "GET /v2/security/oauth2/client/client-configuration",
  "schema": "OAuth2Client",
  "target": "{applicationName}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /v2/security/oauth2/client/client-configuration": {
  "kind": "delete",
  "entityType": "security/oauth2-client",
  "readOperation": "GET /v2/security/oauth2/client/client-configuration",
  "schema": "OAuth2Client",
  "target": "{applicationName}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/security/oauth2/client/client-configuration/secrets": {
  "kind": "action",
  "entityType": "security/oauth2-client",
  "params": [
   "applicationName"
  ],
  "localParams": [
   "clientSecret"
  ],
  "body": {
   "ClientSecret": "{clientSecret}",
   "ClientPassword": "{clientPassword}"
  },
  "target": "the secrets of {applicationName}",
  "secretFields": [
   "ClientSecret",
   "ClientPassword",
   "clientSecret",
   "clientPassword",
   "registration_access_token"
  ],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/security/oauth2/client/client-configuration/register-client": {
  "kind": "action",
  "entityType": "security/oauth2-client",
  "params": [
   "applicationName"
  ],
  "target": "{applicationName} with its authorization server",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/security/oauth2/client/client-configuration/rotate-keys": {
  "kind": "action",
  "entityType": "security/oauth2-client",
  "params": [
   "applicationName"
  ],
  "target": "the keys of {applicationName}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/security/oauth2/server/client": {
  "kind": "upsert",
  "entityType": "security/oauth2-server-client",
  "readOperation": "GET /v2/security/oauth2/server/client",
  "schema": "OAuth2ServerClient",
  "target": "{clientId}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /v2/security/oauth2/server/client": {
  "kind": "delete",
  "entityType": "security/oauth2-server-client",
  "readOperation": "GET /v2/security/oauth2/server/client",
  "schema": "OAuth2ServerClient",
  "target": "{clientId}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/security/oauth2/server/client/secret": {
  "kind": "action",
  "entityType": "security/oauth2-server-client",
  "params": [
   "clientId"
  ],
  "localParams": [
   "clientSecret"
  ],
  "body": {
   "ClientSecret": "{clientSecret}"
  },
  "target": "the client secret of {clientId}",
  "secretFields": [
   "ClientSecret",
   "clientSecret"
  ],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/security/oauth2/resource-server": {
  "kind": "upsert",
  "entityType": "security/oauth2-resource-server",
  "readOperation": "GET /v2/security/oauth2/resource-server",
  "schema": "OAuth2ResourceServer",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /v2/security/oauth2/resource-server": {
  "kind": "delete",
  "entityType": "security/oauth2-resource-server",
  "readOperation": "GET /v2/security/oauth2/resource-server",
  "schema": "OAuth2ResourceServer",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/security/oauth2/resource-server/secret": {
  "kind": "action",
  "entityType": "security/oauth2-resource-server",
  "params": [
   "name"
  ],
  "localParams": [
   "clientSecret"
  ],
  "body": {
   "ClientSecret": "{clientSecret}"
  },
  "target": "the client secret of {name}",
  "secretFields": [
   "ClientSecret",
   "clientSecret"
  ],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/security/oauth2/server": {
  "kind": "upsert",
  "entityType": "security/oauth2-server",
  "readOperation": "GET /v2/security/oauth2/server",
  "schema": "OAuth2ServerConfiguration",
  "target": "the authorization server",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /v2/security/oauth2/server": {
  "kind": "delete",
  "entityType": "security/oauth2-server",
  "readOperation": "GET /v2/security/oauth2/server",
  "schema": "OAuth2ServerConfiguration",
  "target": "the authorization server",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "maximum",
    "consequence": "Every client of this authorization server stops being able to authenticate."
   }
  ]
 },
 "POST /v2/security/oauth2/server/password": {
  "kind": "action",
  "entityType": "security/oauth2-server",
  "params": [],
  "localParams": [
   "serverPassword"
  ],
  "body": {
   "ServerPassword": "{serverPassword}"
  },
  "target": "the authorization server password",
  "secretFields": [
   "ServerPassword",
   "serverPassword"
  ],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/security/web-auth": {
  "kind": "upsert",
  "entityType": "security/web-authentication",
  "readOperation": "GET /v2/security/web-auth",
  "schema": "WebAuthenticationSettings",
  "target": "web authentication",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/security/web-auth/smtp-password": {
  "kind": "action",
  "entityType": "security/web-authentication",
  "params": [],
  "localParams": [
   "smtpPassword"
  ],
  "body": {
   "SMPTPPassword": "{smtpPassword}"
  },
  "target": "the SMTP password",
  "secretFields": [
   "SMPTPPassword",
   "smtpPassword"
  ],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/security/audit/enabled": {
  "kind": "upsert",
  "entityType": "security/audit-settings",
  "readOperation": "GET /v2/security/audit/enabled",
  "schema": "AuditingEnabled",
  "target": "auditing",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "equals",
     "path": "proposed.Enabled",
     "value": false
    },
    "grade": "reinforced",
    "consequence": "The instance stops recording security events while auditing is off."
   }
  ]
 },
 "POST /v2/security/audit/record/copy": {
  "kind": "action",
  "entityType": "security/audit-settings",
  "params": [],
  "localParams": [
   "auditCopyNamespace"
  ],
  "optionalParams": [
   "deleteAfterCopy",
   "beginDateTime",
   "endDateTime"
  ],
  "body": {
   "AuditCopyNamespace": "{auditCopyNamespace}",
   "DeleteAfterCopy": "{deleteAfterCopy}",
   "BeginDateTime": "{beginDateTime}",
   "EndDateTime": "{endDateTime}"
  },
  "target": "a copy of the audit records to {auditCopyNamespace}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "equals",
     "path": "params.deleteAfterCopy",
     "value": "true"
    },
    "grade": "maximum",
    "consequence": "Copying with deletion removes the records from this instance's audit trail: it is a purge with another name."
   },
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/security/audit/record/purge": {
  "kind": "action",
  "entityType": "security/audit-settings",
  "params": [],
  "optionalParams": [
   "beginDateTime",
   "endDateTime"
  ],
  "body": {
   "BeginDateTime": "{beginDateTime}",
   "EndDateTime": "{endDateTime}"
  },
  "target": "the audit records of this instance",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "maximum",
    "consequence": "This erases the instance's own audit trail, the record that outlives FlightDeck's session trail. It cannot be undone."
   }
  ]
 },
 "FLIGHTDECK REST execute": {
  "kind": "request",
  "target": "{path}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "equals",
     "path": "request.method",
     "value": "DELETE"
    },
    "grade": "reinforced"
   }
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
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/task": {
  "kind": "upsert",
  "entityType": "tasks/task",
  "readOperation": "GET /v2/task",
  "schema": "Task",
  "target": "{id}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /v2/task": {
  "kind": "upsert",
  "entityType": "tasks/task",
  "readOperation": "GET /v2/task",
  "schema": "Task",
  "target": "a new task",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "DELETE /v2/task": {
  "kind": "delete",
  "entityType": "tasks/task",
  "readOperation": "GET /v2/task",
  "schema": "Task",
  "target": "{id}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ],
  "selfProtection": [
   {
    "when": {
     "op": "equals",
     "path": "isSystem",
     "value": true
    },
    "message": "system-task"
   }
  ]
 },
 "POST /v2/task/suspend": {
  "kind": "action",
  "entityType": "tasks/task",
  "params": [
   "id"
  ],
  "target": "task {id}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /v2/task/resume": {
  "kind": "action",
  "entityType": "tasks/task",
  "params": [
   "id"
  ],
  "target": "task {id}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /v2/task/run": {
  "kind": "action",
  "entityType": "tasks/task",
  "params": [
   "id"
  ],
  "target": "an on-demand run of task {id}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ],
  "body": {
   "RunNow": true
  },
  "applyNotice": "The instance schedules the run and reports it; a run already in flight is refused with its start time."
 },
 "POST /v2/task/manager/suspend": {
  "kind": "action",
  "entityType": "tasks/task-manager",
  "params": [],
  "target": "the task manager",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "No scheduled task runs anywhere on this instance until the manager is resumed."
   }
  ]
 },
 "POST /v2/task/manager/resume": {
  "kind": "action",
  "entityType": "tasks/task-manager",
  "params": [],
  "target": "the task manager",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /v2/task/manager/run": {
  "kind": "action",
  "entityType": "tasks/task-manager",
  "params": [],
  "target": "the task manager",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "PUT /v2/wqm-category": {
  "kind": "upsert",
  "entityType": "tasks/wqm-category",
  "readOperation": "GET /v2/wqm-category",
  "schema": "WQMCategory",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "DELETE /v2/wqm-category": {
  "kind": "delete",
  "entityType": "tasks/wqm-category",
  "readOperation": "GET /v2/wqm-category",
  "schema": "WQMCategory",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/async-result/cancel": {
  "kind": "action",
  "entityType": "tasks/async-result",
  "params": [
   "id"
  ],
  "target": "async result {id}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /v2/async-result/pause": {
  "kind": "action",
  "entityType": "tasks/async-result",
  "params": [
   "id"
  ],
  "target": "async result {id}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /v2/async-result/resume": {
  "kind": "action",
  "entityType": "tasks/async-result",
  "params": [
   "id"
  ],
  "target": "async result {id}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /v2/process/terminate": {
  "kind": "action",
  "entityType": "system/process",
  "params": [
   "id"
  ],
  "target": "process {id}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "maximum",
    "consequence": "The process stops at once. Work in flight is lost, and anything waiting on it fails."
   }
  ],
  "selfProtection": [
   {
    "when": {
     "op": "equals",
     "path": "isOwnSession",
     "value": true
    },
    "message": "own-session"
   }
  ],
  "disabledReason": "The instance reports that this process cannot be terminated.",
  "refusedWhen": {
   "op": "equals",
   "path": "facts.canBeTerminated",
   "value": false
  }
 },
 "POST /v2/process/suspend": {
  "kind": "action",
  "entityType": "system/process",
  "params": [
   "id"
  ],
  "target": "process {id}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "The process stops running until it is resumed. Anything waiting on it waits."
   }
  ],
  "disabledReason": "The instance reports that this process cannot be suspended.",
  "refusedWhen": {
   "op": "equals",
   "path": "facts.canBeSuspended",
   "value": false
  }
 },
 "POST /v2/process/resume": {
  "kind": "action",
  "entityType": "system/process",
  "params": [
   "id"
  ],
  "target": "process {id}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ],
  "disabledReason": "The instance reports that this process cannot be suspended or resumed.",
  "refusedWhen": {
   "op": "equals",
   "path": "facts.canBeSuspended",
   "value": false
  }
 },
 "POST /v2/process/broadcast": {
  "kind": "action",
  "entityType": "system/process",
  "params": [
   "id"
  ],
  "target": "process {id}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ],
  "localParams": [
   "message"
  ],
  "body": {
   "Message": "{message}"
  },
  "disabledReason": "The instance reports that this process cannot receive a broadcast.",
  "refusedWhen": {
   "op": "equals",
   "path": "facts.canReceiveBroadcast",
   "value": false
  }
 },
 "DELETE /v2/lock": {
  "kind": "action",
  "entityType": "system/lock",
  "params": [
   "id"
  ],
  "target": "lock {id}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "The lock is removed. Whatever held it no longer does."
   }
  ],
  "disabledReason": "The instance reports that this lock cannot be removed.",
  "refusedWhen": {
   "op": "equals",
   "path": "facts.removable",
   "value": false
  }
 },
 "DELETE /v2/web-session": {
  "kind": "action",
  "entityType": "system/web-session",
  "params": [
   "id"
  ],
  "target": "web session {id}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "The session ends at once for whoever is using it."
   }
  ]
 },
 "PUT /v2/database": {
  "kind": "upsert",
  "entityType": "system/database",
  "readOperation": "GET /v2/database",
  "schema": "ConfigDatabase",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/database-dir": {
  "kind": "upsert",
  "entityType": "system/database-dir",
  "readOperation": "GET /v2/database-dir",
  "schema": "LocalDatabase",
  "target": "{dir}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/database-dir": {
  "kind": "upsert",
  "entityType": "system/database-dir",
  "readOperation": "GET /v2/database-dir",
  "schema": "LocalDatabase",
  "target": "a new database directory",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /v2/database-dir": {
  "kind": "delete",
  "entityType": "system/database-dir",
  "readOperation": "GET /v2/database-dir",
  "schema": "LocalDatabase",
  "target": "{dir}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "The directory is removed from the configuration. The files on disk stay where they are."
   }
  ]
 },
 "POST /v2/database-dir/mount": {
  "kind": "action",
  "entityType": "system/database-dir",
  "params": [
   "dir"
  ],
  "target": "{dir}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/database-dir/dismount": {
  "kind": "action",
  "entityType": "system/database-dir",
  "params": [
   "dir"
  ],
  "target": "{dir}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "Everything that reads or writes this database stops working until it is mounted again."
   }
  ]
 },
 "POST /v2/database-dir/expand-volume": {
  "kind": "action",
  "entityType": "system/database-dir",
  "params": [
   "dir"
  ],
  "target": "{dir}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/database-dir/modify-size": {
  "kind": "action",
  "entityType": "system/database-dir",
  "params": [
   "dir"
  ],
  "target": "{dir}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/database-dir/compact": {
  "kind": "action",
  "entityType": "system/database-dir",
  "params": [
   "dir"
  ],
  "target": "{dir}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "Compacting rewrites blocks while the database stays in use."
   }
  ],
  "applyNotice": "The instance runs this as a background task. FlightDeck follows it and reports what the platform says.",
  "expectedDuration": "minutes on a large database"
 },
 "POST /v2/database-dir/defragment": {
  "kind": "action",
  "entityType": "system/database-dir",
  "params": [
   "dir"
  ],
  "target": "{dir}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "Defragmenting rewrites blocks while the database stays in use."
   }
  ],
  "applyNotice": "The instance runs this as a background task. FlightDeck follows it and reports what the platform says.",
  "expectedDuration": "minutes, and longer on a fragmented database"
 },
 "POST /v2/database-dir/integrity-check": {
  "kind": "action",
  "entityType": "system/database-dir",
  "params": [
   "dir"
  ],
  "target": "{dir}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "The integrity check rewrites blocks while the database stays in use."
   }
  ],
  "applyNotice": "The instance runs this as a background task. FlightDeck follows it and reports what the platform says.",
  "expectedDuration": "minutes, and longer on a large database"
 },
 "PUT /v2/namespace": {
  "kind": "upsert",
  "entityType": "system/namespace",
  "readOperation": "GET /v2/namespace",
  "schema": "Namespace",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/namespace/copy-mappings": {
  "kind": "action",
  "entityType": "system/namespace",
  "params": [
   "name"
  ],
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ],
  "localParams": [
   "source"
  ],
  "body": {
   "SourceNamespace": "{source}"
  }
 },
 "POST /v2/namespace/enable-interop": {
  "kind": "action",
  "entityType": "system/namespace",
  "params": [
   "name"
  ],
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "Interoperability is enabled for this namespace and its globals are extended."
   }
  ]
 },
 "PUT /v2/namespace/global-mapping": {
  "kind": "upsert",
  "entityType": "system/global-mapping",
  "readOperation": "GET /v2/namespace/global-mapping",
  "schema": "MapGlobal",
  "target": "{name} in {namespace}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "DELETE /v2/namespace/global-mapping": {
  "kind": "delete",
  "entityType": "system/global-mapping",
  "readOperation": "GET /v2/namespace/global-mapping",
  "schema": "MapGlobal",
  "target": "{name} in {namespace}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/namespace/package-mapping": {
  "kind": "upsert",
  "entityType": "system/package-mapping",
  "readOperation": "GET /v2/namespace/package-mapping",
  "schema": "MapPackage",
  "target": "{name} in {namespace}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "DELETE /v2/namespace/package-mapping": {
  "kind": "delete",
  "entityType": "system/package-mapping",
  "readOperation": "GET /v2/namespace/package-mapping",
  "schema": "MapPackage",
  "target": "{name} in {namespace}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/namespace/routine-mapping": {
  "kind": "upsert",
  "entityType": "system/routine-mapping",
  "readOperation": "GET /v2/namespace/routine-mapping",
  "schema": "MapRoutine",
  "target": "{name} in {namespace}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "DELETE /v2/namespace/routine-mapping": {
  "kind": "delete",
  "entityType": "system/routine-mapping",
  "readOperation": "GET /v2/namespace/routine-mapping",
  "schema": "MapRoutine",
  "target": "{name} in {namespace}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/device": {
  "kind": "upsert",
  "entityType": "system/device",
  "readOperation": "GET /v2/device",
  "schema": "Device",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "DELETE /v2/device": {
  "kind": "delete",
  "entityType": "system/device",
  "readOperation": "GET /v2/device",
  "schema": "Device",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/device/subtype": {
  "kind": "upsert",
  "entityType": "system/device-subtype",
  "readOperation": "GET /v2/device/subtype",
  "schema": "DeviceSubType",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "DELETE /v2/device/subtype": {
  "kind": "delete",
  "entityType": "system/device-subtype",
  "readOperation": "GET /v2/device/subtype",
  "schema": "DeviceSubType",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/device/settings": {
  "kind": "upsert",
  "entityType": "system/device-settings",
  "readOperation": "GET /v2/device/settings",
  "schema": "DeviceSettings",
  "target": "the device settings",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/license/key": {
  "kind": "upsert",
  "entityType": "system/license-key",
  "readOperation": "GET /v2/license/key",
  "schema": null,
  "target": "the license key",
  "secretFields": [
   "AuthorizationKey"
  ],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "The instance runs under the new key from now on."
   }
  ]
 },
 "POST /v2/license/key/validate": {
  "kind": "action",
  "entityType": "system/license-key",
  "params": [],
  "target": "the license key",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ],
  "localParams": [
   "path"
  ],
  "body": {
   "Path": "{path}"
  }
 },
 "PUT /v2/license/server": {
  "kind": "upsert",
  "entityType": "system/license-server",
  "readOperation": "GET /v2/license/server",
  "schema": "LicenseServer",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "DELETE /v2/license/server": {
  "kind": "delete",
  "entityType": "system/license-server",
  "readOperation": "GET /v2/license/server",
  "schema": "LicenseServer",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/ecp/data-server": {
  "kind": "upsert",
  "entityType": "system/ecp-data-server",
  "readOperation": "GET /v2/ecp/data-server",
  "schema": "ECPDataServer",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /v2/ecp/data-server": {
  "kind": "delete",
  "entityType": "system/ecp-data-server",
  "readOperation": "GET /v2/ecp/data-server",
  "schema": "ECPDataServer",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/ecp/data-server/action": {
  "kind": "action",
  "entityType": "system/ecp-data-server",
  "params": [
   "name"
  ],
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ],
  "localParams": [
   "action"
  ],
  "body": {
   "Action": "{action}"
  }
 },
 "PUT /v2/ecp/settings": {
  "kind": "upsert",
  "entityType": "system/ecp-settings",
  "readOperation": "GET /v2/ecp/settings",
  "schema": "ECPSettings",
  "target": "the ECP settings",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/ecp/application-server-ssl-connection/authorize": {
  "kind": "action",
  "entityType": "system/ecp-ssl-connection",
  "params": [
   "name"
  ],
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/ecp/application-server-ssl-connection/reject": {
  "kind": "action",
  "entityType": "system/ecp-ssl-connection",
  "params": [
   "name"
  ],
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /v2/ecp/application-server-ssl-connection": {
  "kind": "action",
  "entityType": "system/ecp-ssl-connection",
  "params": [
   "name"
  ],
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/ext-lang-server": {
  "kind": "upsert",
  "entityType": "system/ext-lang-server",
  "readOperation": "GET /v2/ext-lang-server",
  "schema": "LanguageServer",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "DELETE /v2/ext-lang-server": {
  "kind": "delete",
  "entityType": "system/ext-lang-server",
  "readOperation": "GET /v2/ext-lang-server",
  "schema": "LanguageServer",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "POST /v2/ext-lang-server/start": {
  "kind": "action",
  "entityType": "system/ext-lang-server",
  "params": [
   "name"
  ],
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /v2/ext-lang-server/stop": {
  "kind": "action",
  "entityType": "system/ext-lang-server",
  "params": [
   "name"
  ],
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "Code that calls this language server fails until it is started again."
   }
  ]
 },
 "PUT /v2/doc-db": {
  "kind": "upsert",
  "entityType": "system/doc-db",
  "readOperation": "GET /v2/doc-db",
  "schema": "DocDBApplication",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "DELETE /v2/doc-db": {
  "kind": "delete",
  "entityType": "system/doc-db",
  "readOperation": "GET /v2/doc-db",
  "schema": "DocDBApplication",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/fs-access-purpose": {
  "kind": "upsert",
  "entityType": "system/fs-access-purpose",
  "readOperation": "GET /v2/fs-access-purpose",
  "schema": "FSAccessPurpose",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "DELETE /v2/fs-access-purpose": {
  "kind": "delete",
  "entityType": "system/fs-access-purpose",
  "readOperation": "GET /v2/fs-access-purpose",
  "schema": "FSAccessPurpose",
  "target": "{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "PUT /v2/fs-access-purpose/path": {
  "kind": "action",
  "entityType": "system/fs-access-purpose",
  "params": [
   "name"
  ],
  "target": "a path of {name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ],
  "localParams": [
   "path"
  ],
  "body": {
   "Path": "{path}"
  }
 },
 "DELETE /v2/fs-access-purpose/path": {
  "kind": "action",
  "entityType": "system/fs-access-purpose",
  "params": [
   "name"
  ],
  "target": "a path of {name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ],
  "localParams": [
   "path"
  ],
  "body": {
   "Path": "{path}"
  }
 },
 "PUT /v2/security/oauth2/resource-server/mapping": {
  "kind": "upsert",
  "entityType": "security/oauth2-resource-server-mapping",
  "readOperation": "GET /v2/security/oauth2/resource-server/mapping",
  "schema": "OAuth2ResourceServerMapping",
  "target": "{key} of {service}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "DELETE /v2/security/oauth2/resource-server/mapping": {
  "kind": "delete",
  "entityType": "security/oauth2-resource-server-mapping",
  "readOperation": "GET /v2/security/oauth2/resource-server/mapping",
  "schema": "OAuth2ResourceServerMapping",
  "target": "{key} of {service}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "Requests that relied on this mapping stop resolving to the service."
   }
  ]
 },
 "POST /v2/security/oauth2/server/client": {
  "kind": "upsert",
  "entityType": "security/oauth2-server-client",
  "readOperation": "GET /v2/security/oauth2/server/client",
  "schema": "OAuth2ServerClient",
  "target": "a new OAuth 2.0 client",
  "secretFields": [
   "ClientSecret"
  ],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /v2/security/oauth2/client/server-definition": {
  "kind": "upsert",
  "entityType": "security/oauth2-server-definition",
  "readOperation": "GET /v2/security/oauth2/client/server-definition",
  "schema": "OAuth2ServerDefinition",
  "target": "a new authorization server definition",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "equals",
     "path": "params.discover",
     "value": "true"
    },
    "grade": "reinforced",
    "consequence": "The instance contacts the authorization server to read its metadata."
   },
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /v2/security/audit/event/clear-count": {
  "kind": "action",
  "entityType": "security/audit-settings",
  "params": [
   "source",
   "type",
   "name"
  ],
  "target": "the count of {source}/{type}/{name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "The recorded count for this event returns to zero. What it counted is not recoverable."
   }
  ]
 },
 "POST /v2/security/ldap/test": {
  "kind": "action",
  "entityType": "security/ldap-configuration",
  "params": [],
  "localParams": [
   "Username",
   "Password"
  ],
  "body": {
   "Username": "{Username}",
   "Password": "{Password}"
  },
  "target": "a test login against the directory server",
  "secretFields": [
   "Password"
  ],
  "applyNotice": "The instance signs in to the directory server itself and reports what it answered.",
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "This is a real sign-in attempt at the directory server. Repeated failures can lock the account there, and the attempt is recorded in that server's own logs."
   }
  ]
 },
 "GET /v2/security/mft/connection/auth-code-url": {
  "kind": "action",
  "entityType": "security/mft-connection",
  "params": [
   "connection"
  ],
  "localParams": [
   "redirect",
   "scope"
  ],
  "target": "an authorization URL for {connection}",
  "secretFields": [],
  "applyNotice": "The instance asks the file transfer provider for the URL and returns what it answered.",
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "The URL this returns begins an authorization at the provider, for the scope asked. Anyone who follows it can grant that access."
   }
  ]
 },
 "POST /v2/security/oauth2/revoke": {
  "kind": "action",
  "entityType": "security/oauth2-client",
  "params": [
   "user"
  ],
  "target": "the OAuth 2.0 tokens of {user}",
  "secretFields": [],
  "applyNotice": "The instance revokes the tokens at the authorization server and reports its answer.",
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced",
    "consequence": "Every access and refresh token this instance holds for that user stops working at once, here and at the authorization server. They sign in again to get new ones."
   }
  ]
 }
}
}

}
