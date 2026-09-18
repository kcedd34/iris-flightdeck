import type { ComponentType } from "react";
import { Auditing, Encryption, Ldap, Mft, OAuth2, Superservers, TlsConfigurations, WebAuthentication, Wallet, X509Credentials } from "./security/sections";
import { PrivilegedRoutines } from "./permissions/PrivilegedRoutines";
import { Resources } from "./permissions/Resources";
import { Roles } from "./permissions/Roles";
import { Services } from "./permissions/Services";
import { Users } from "./permissions/Users";
import { Services as RestServices } from "./rest-apis/Services";
import { PercentClassAccess } from "./web-apps/PercentClassAccess";
import { WebApplications } from "./web-apps/WebApplications";

/** Sections built on the domain pattern. Sections not listed keep the feature 001 empty state. */
export const SECTIONS: Record<string, ComponentType> = {
  "web-apps/web-applications": WebApplications,
  "web-apps/percent-class-access": PercentClassAccess,
  "web-apps/rest-apis": RestServices,
  "permissions/users": Users,
  "permissions/roles": Roles,
  "permissions/resources": Resources,
  "permissions/services": Services,
  "permissions/privileged-routines": PrivilegedRoutines,
  "security/tls": TlsConfigurations,
  "security/x509": X509Credentials,
  "security/oauth2": OAuth2,
  "security/wallet": Wallet,
  "security/encryption": Encryption,
  "security/ldap": Ldap,
  "security/mft": Mft,
  "security/auditing": Auditing,
  "security/web-authentication": WebAuthentication,
  "security/superservers": Superservers,
};
