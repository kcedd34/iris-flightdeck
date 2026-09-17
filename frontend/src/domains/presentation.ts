// Presentation of official objects in the inspector: grouping and labels only. Field names and
// types come from the generated official schemas (scripts/build/gen-schemas.py); nothing here
// renames or reinterprets an official field.
import type { ReactNode } from "react";
import { SCHEMAS, type ObjectSchema } from "./generated/schemas";

export interface Presentation {
  schema: keyof typeof SCHEMAS;
  sections: { title: string; fields: string[] }[];
  mono?: string[];
  format?: Record<string, (value: unknown) => ReactNode>;
}

/** AutheEnabled bits as the official schema documents them (Bit N = 2^N). */
export const AUTHENTICATION_BITS: [number, string][] = [
  [4, "Kerberos"],
  [32, "Password"],
  [64, "Unauthenticated"],
  [2048, "LDAP"],
  [8192, "Delegated"],
  [16384, "Login token"],
  [1048576, "Two-factor SMS"],
  [2097152, "Two-factor TOTP"],
];

export function authenticationMethods(mask: unknown): string[] {
  const value = Number(mask) || 0;
  return AUTHENTICATION_BITS.filter(([bit]) => (value & bit) === bit).map(([, label]) => label);
}

const LABELS: Record<string, string> = {
  AutheEnabled: "Authentication",
  NameSpace: "Namespace",
  IsNameSpaceDefault: "Namespace default",
  CSPZENEnabled: "CSP and Zen",
  CSRFToken: "CSRF token",
  LockCSPName: "Lock CSP name",
  JWTAuthEnabled: "JWT authentication",
  JWTAccessTokenTimeout: "JWT access timeout",
  JWTRefreshTokenTimeout: "JWT refresh timeout",
  InbndWebServicesEnabled: "Inbound web services",
  iKnowEnabled: "iKnow",
  DeepSeeEnabled: "DeepSee",
  GroupById: "Group by ID",
  WSGIType: "WSGI type",
  WSGIAppLocation: "WSGI location",
  WSGIAppName: "WSGI application",
  WSGICallable: "WSGI callable",
  WSGIDebug: "WSGI debug",
  ServeFilesTimeout: "Serve files timeout",
  MatchRoles: "Match roles",
  AllowAccess: "Allow access",
};

export function humanize(field: string): string {
  if (LABELS[field]) return LABELS[field]!;
  return field
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2")
    .replace(/^./, (c) => c.toUpperCase());
}

export function formatValue(value: unknown): string {
  if (value === null || value === undefined || value === "") return "—";
  if (typeof value === "boolean") return value ? "Yes" : "No";
  if (Array.isArray(value)) {
    if (value.length === 0) return "—";
    return value.map((v) => (typeof v === "object" ? JSON.stringify(v) : String(v))).join(", ");
  }
  if (typeof value === "object") return JSON.stringify(value);
  return String(value);
}

const WEB_APPLICATION: Presentation = {
  schema: "Application",
  sections: [
    { title: "Application", fields: ["Description", "NameSpace", "Enabled", "DispatchClass", "IsNameSpaceDefault"] },
    { title: "Security", fields: ["AutheEnabled", "Resource", "MatchRoles", "TwoFactorEnabled", "JWTAuthEnabled", "JWTAccessTokenTimeout", "JWTRefreshTokenTimeout", "CSRFToken", "LockCSPName", "PermittedClasses"] },
    { title: "Session", fields: ["Timeout", "UseCookies", "CookiePath", "SessionScope", "UserCookieScope", "GroupById", "EventClass", "LoginPage", "ChangePasswordPage", "ErrorPage"] },
    { title: "Files and CSP", fields: ["ServeFiles", "ServeFilesTimeout", "Path", "Recurse", "Package", "SuperClass", "AutoCompile", "CSPZENEnabled", "InbndWebServicesEnabled", "RedirectEmptyPath", "TraceEnabled", "DeepSeeEnabled", "iKnowEnabled"] },
    { title: "CORS", fields: ["CorsAllowlist", "CorsCredentialsAllowed", "CorsHeadersList"] },
    { title: "WSGI", fields: ["WSGIType", "WSGIAppLocation", "WSGIAppName", "WSGICallable", "WSGIDebug"] },
  ],
  mono: ["NameSpace", "DispatchClass", "Resource", "CookiePath", "Path", "Package", "SuperClass", "EventClass", "GroupById"],
  format: {
    AutheEnabled: (value) => authenticationMethods(value).join(", ") || "None",
    MatchRoles: (value) =>
      Array.isArray(value) && value.length
        ? (value as { MatchRole: string; TargetRoles: string[] }[])
            .map((m) => `${m.MatchRole ? m.MatchRole + " → " : "always → "}${m.TargetRoles.join(", ")}`)
            .join("; ")
        : "—",
  },
};

const PCT_ACCESS: Presentation = { schema: "WebAppPctAccess", sections: [{ title: "Access", fields: ["AllowAccess"] }] };

const ROLE: Presentation = {
  schema: "Role",
  sections: [{ title: "Role", fields: ["Description", "EscalationOnly", "GrantedRoles", "Resources"] }],
  format: {
    Resources: (value) =>
      Array.isArray(value) && value.length ? (value as { Name: string; Permissions: string }[]).map((r) => `${r.Name}:${r.Permissions}`).join(", ") : "—",
  },
};

const USER: Presentation = {
  schema: "User",
  sections: [{ title: "User", fields: ["FullName", "Enabled", "Roles", "EscalationRoles", "NameSpace", "Routine", "Comment", "ExpirationDate", "AccountNeverExpires", "PasswordNeverExpires", "ChangePassword"] }],
};

export const PRESENTATIONS: Record<string, Presentation> = {
  "web-apps/web-application": WEB_APPLICATION,
  "web-apps/pct-access": PCT_ACCESS,
  "permissions/role": ROLE,
  "permissions/user": USER,
};

/** Formats a value for display wherever it appears (inspector, dry-run, trail), by field name. */
export function formatField(field: string, value: unknown): string {
  if (field === "AutheEnabled" && (typeof value === "number" || typeof value === "string") && value !== "") {
    return `${authenticationMethods(value).join(", ") || "None"} (${value})`;
  }
  if (field === "MatchRoles" && Array.isArray(value)) {
    return value.length
      ? (value as { MatchRole: string; TargetRoles: string[] }[]).map((m) => `${m.MatchRole ? m.MatchRole + " → " : "always → "}${m.TargetRoles.join(", ")}`).join("; ")
      : "—";
  }
  return formatValue(value);
}

/** Every official field is shown: fields not placed in a section go to "Other". */
export function sectionsFor(key: string, object: Record<string, unknown>) {
  const presentation = PRESENTATIONS[key];
  const schema: ObjectSchema | undefined = presentation ? SCHEMAS[presentation.schema] : undefined;
  const placed = new Set(presentation?.sections.flatMap((s) => s.fields) ?? []);
  const known = schema ? schema.fields.map((f) => f.name) : Object.keys(object);
  const other = known.filter((name) => !placed.has(name) && name in object);
  const sections = [...(presentation?.sections ?? []), ...(other.length ? [{ title: "Other", fields: other }] : [])];
  return sections
    .map((section) => ({
      title: section.title,
      fields: section.fields
        .filter((name) => name in object)
        .map((name) => ({
          label: humanize(name),
          value: presentation?.format?.[name]?.(object[name]) ?? formatValue(object[name]),
          mono: presentation?.mono?.includes(name),
          numeric: typeof object[name] === "number",
        })),
    }))
    .filter((section) => section.fields.length > 0);
}
