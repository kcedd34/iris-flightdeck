#!/usr/bin/env python3
"""Generate the official object schemas the domain screens and the mutation layer use.

Source (never edited): docs/sysadmin-api-v2.json, components.schemas.
Outputs:
  frontend/src/domains/generated/schemas.ts     field metadata for forms and inspectors
  backend/cls/FlightDeck/Domain/Schemas.cls     the same metadata for diffs (XData JSON)

Only field names, types, descriptions and enums are copied; FlightDeck never renames an official
field (feature 002 research R1). Labels and grouping live next to the screens, not here.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "docs" / "sysadmin-api-v2.json"
OUT_TS = ROOT / "frontend" / "src" / "domains" / "generated" / "schemas.ts"
OUT_CLS = ROOT / "backend" / "cls" / "FlightDeck" / "Domain" / "Schemas.cls"

# Schema name -> exported id. List schemas are arrays; their item object is used.
SCHEMAS = {
    # Feature 002: web applications
    "Application": "Application",
    "WebApplicationList": "WebApplicationListItem",
    "WebAppPctAccess": "WebAppPctAccess",
    "PercentClassAccessList": "PercentClassAccessListItem",
    # Feature 003: permissions
    "User": "User",
    "UserList": "UserListItem",
    "Role": "Role",
    "RoleList": "RoleListItem",
    "Resource": "Resource",
    "ResourceList": "ResourceListItem",
    "Service": "Service",
    "ServiceList": "ServiceListItem",
    "PrivilegedRoutineApplication": "PrivilegedRoutineApplication",
    "PrivilegedRoutineApplicationList": "PrivilegedRoutineApplicationListItem",
    "RoleOwnerList": "RoleOwnerListItem",
    "SQLPrivilegeList": "SQLPrivilegeListItem",
    "SQLAdminPrivilegeList": "SQLAdminPrivilegeListItem",
    "SQLColumnPrivilegeList": "SQLColumnPrivilegeListItem",
    # Feature 003: security and secrets
    "SSLConfig": "SSLConfig",
    "SSLConfigurationList": "SSLConfigurationListItem",
    "X509Credential": "X509Credential",
    "X509CredentialsList": "X509CredentialsListItem",
    "X509CredentialCertificate": "X509CredentialCertificate",
    "WalletCollection": "WalletCollection",
    "WalletCollectionList": "WalletCollectionListItem",
    "WalletSecretList": "WalletSecretListItem",
    "OAuth2Client": "OAuth2Client",
    "OAuth2ClientsUsingServer": "OAuth2ClientsUsingServerItem",
    "OAuth2ServerDefinition": "OAuth2ServerDefinition",
    "OAuth2AuthorizationServerList": "OAuth2AuthorizationServerListItem",
    "OAuth2ServerConfiguration": "OAuth2ServerConfiguration",
    "OAuth2ServerClient": "OAuth2ServerClient",
    "OAuth2ServerClientList": "OAuth2ServerClientListItem",
    "OAuth2ResourceServer": "OAuth2ResourceServer",
    "OAuth2ResourceServerList": "OAuth2ResourceServerListItem",
    "OAuth2ResourceServerMapping": "OAuth2ResourceServerMapping",
    "LDAPConfig": "LDAPConfig",
    "LDAPConfigurationList": "LDAPConfigurationListItem",
    "MFTConnection": "MFTConnection",
    "MFTConnectionList": "MFTConnectionListItem",
    "Superserver": "Superserver",
    "SuperserverList": "SuperserverListItem",
    "WebAuthenticationSettings": "WebAuthenticationSettings",
    "EncryptionSettings": "EncryptionSettings",
    "AuditingEnabled": "AuditingEnabled",
    "AuditEvent": "AuditEvent",
    # Feature 004: tasks. Names are the ones the official operations reference, not guesses:
    # every entry below was read back from docs/sysadmin-api-v2.json responses.
    "Task": "Task",
    "TaskList": "TaskListItem",
    "TaskHistory": "TaskHistoryItem",
    "TaskExtraInfo": "TaskExtraInfo",
    "UpcomingTasks": "UpcomingTaskItem",
    "WQMCategory": "WQMCategory",
    "WQMCategoryList": "WQMCategoryListItem",
    "AsyncTask": "AsyncTask",
    "AsyncTaskList": "AsyncTaskListItem",
    # Feature 004: operating system
    "Process": "Process",
    "ProcessList": "ProcessListItem",
    "ConfigDatabase": "ConfigDatabase",
    "ConfigDatabaseList": "ConfigDatabaseListItem",
    "LocalDatabase": "LocalDatabase",
    "LocalDatabaseList": "LocalDatabaseListItem",
    "VolumeFiles": "VolumeFilesItem",
    "Namespace": "Namespace",
    "NamespaceList": "NamespaceListItem",
    "MapGlobal": "MapGlobal",
    "MapPackage": "MapPackage",
    "MapRoutine": "MapRoutine",
    "GlobalMappingList": "GlobalMappingListItem",
    "PackageMappingList": "PackageMappingListItem",
    "RoutineMappingList": "RoutineMappingListItem",
    "Device": "Device",
    "DeviceList": "DeviceListItem",
    "DeviceSubType": "DeviceSubType",
    "DeviceSubTypeList": "DeviceSubTypeListItem",
    "DeviceSettings": "DeviceSettings",
    "LicenseServer": "LicenseServer",
    "LicenseServerList": "LicenseServerListItem",
    "LockList": "LockListItem",
    "WebSessionList": "WebSessionListItem",
    "ECPDataServer": "ECPDataServer",
    "ECPDataServerList": "ECPDataServerListItem",
    "ECPClientList": "ECPClientListItem",
    "ECPSSLConnectionList": "ECPSSLConnectionListItem",
    "ECPSettings": "ECPSettings",
    "LanguageServer": "LanguageServer",
    "LanguageServerList": "LanguageServerListItem",
    "LanguageServerActivityList": "LanguageServerActivityListItem",
    "DocDBApplication": "DocDBApplication",
    "DocDBApplicationList": "DocDBApplicationListItem",
    "FSAccessPurpose": "FSAccessPurpose",
    "FSAccessPurposeList": "FSAccessPurposeListItem",
    "FSAccessPathList": "FSAccessPathListItem",
    # Feature 004: the instrument cluster's sources. docs/prd.md says SystemResourcesStats and
    # SharedMemoryUsage declare no shape; in the specification as shipped both are fully declared,
    # and the probe of 2026-09-18 confirmed them field for field (verification/README.md).
    "SystemUsageStats": "SystemUsageStats",
    "SharedMemoryUsage": "SharedMemoryUsageItem",
    "SystemResourcesStats": "SystemResourcesStatsItem",
    "MainDashboardStats": "MainDashboardStats",
    "GlobalsAndRoutinesStats": "GlobalsAndRoutinesStats",
    "ECPStats": "ECPStats",
    "LicenseUsage": "LicenseUsage",
    # Feature 005: the logs domain. Names read back from the operations' own responses.
    "JournalFile": "JournalFile",
    "JournalFileList": "JournalFileListItem",
    "JournalRecord": "JournalRecord",
    "JournalSettings": "JournalSettings",
    "AuditEventList": "AuditEventListItem",
    "AuditRecord": "AuditRecord",
}


def fail(message):
    print(f"gen-schemas: {message}", file=sys.stderr)
    sys.exit(1)


def clean(text):
    text = re.sub(r"<br\s*/?>", "\n", text or "")
    return re.sub(r"<[^>]+>", "", text).strip()


def field_type(prop, components):
    if "$ref" in prop:
        return "object"
    t = prop.get("type", "object")
    if t == "array":
        items = prop.get("items", {})
        if "$ref" in items:
            return "array<object>"
        return f"array<{items.get('type', 'object')}>"
    return t


def flatten(schema, components, seen=None):
    """Properties of a schema, following allOf and $ref once each.

    The official specification composes several objects out of a base plus an extension (AsyncTask is
    AsyncTaskBase plus its own fields). Reading only "properties" would silently drop the base's
    fields, which is the kind of quiet loss FlightDeck must not ship.
    """
    seen = seen or set()
    ref = schema.get("$ref")
    if ref:
        target = ref.rsplit("/", 1)[-1]
        if target in seen:
            return {}
        seen.add(target)
        return flatten(components.get(target, {}), components, seen)
    if schema.get("type") == "array":
        return flatten(schema.get("items", {}), components, seen)
    props = dict(schema.get("properties") or {})
    for part in schema.get("allOf", []):
        ref = part.get("$ref")
        if ref:
            target = ref.rsplit("/", 1)[-1]
            if target in seen:
                continue
            seen.add(target)
            props.update(flatten(components.get(target, {}), components, seen))
        else:
            props.update(flatten(part, components, seen))
    return props


def build():
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    components = spec["components"]["schemas"]
    out = {}
    for name, export in SCHEMAS.items():
        if name not in components:
            fail(f"schema {name} not found in the official specification")
        schema = components[name]
        if schema.get("type") == "array":
            schema = schema.get("items", {})
        props = flatten(schema, components)
        if not props:
            fail(f"schema {name} has no properties")
        fields = []
        for field, prop in props.items():
            entry = {"name": field, "type": field_type(prop, components), "description": clean(prop.get("description", ""))}
            if "enum" in prop:
                entry["enum"] = prop["enum"]
            items = prop.get("items", {})
            if isinstance(items, dict) and items.get("type") == "object" and items.get("properties"):
                entry["itemFields"] = [{"name": k, "type": field_type(v, components)} for k, v in items["properties"].items()]
            fields.append(entry)
        out[export] = {"source": name, "fields": fields}
    return out


def main():
    data = build()
    payload = json.dumps(data, indent=1, ensure_ascii=True)
    ts = (
        "// Generated by scripts/build/gen-schemas.py from docs/sysadmin-api-v2.json. Do not edit by hand.\n"
        "// Official field names, types, descriptions and enums (feature 002 research R1).\n\n"
        "export interface SchemaField {\n"
        "  name: string;\n"
        "  type: string;\n"
        "  description: string;\n"
        "  enum?: readonly string[];\n"
        "  itemFields?: readonly { name: string; type: string }[];\n"
        "}\n\n"
        "export interface ObjectSchema {\n"
        "  source: string;\n"
        "  fields: readonly SchemaField[];\n"
        "}\n\n"
        f"export const SCHEMAS: Record<{' | '.join(repr(k).replace(chr(39), chr(34)) for k in data)}, ObjectSchema> = {payload};\n"
    )
    cls = (
        "/// Generated by scripts/build/gen-schemas.py from docs/sysadmin-api-v2.json. Do not edit by hand.\n"
        "/// Official field metadata used by the mutation layer's field-by-field diff (feature 002 R1).\n"
        "Class FlightDeck.Domain.Schemas [ Abstract ]\n"
        "{\n\n"
        "XData Schemas [ MimeType = application/json ]\n"
        "{\n"
        f"{payload}\n"
        "}\n\n"
        "/// The schema metadata keyed by exported id. Cached per process.\n"
        "ClassMethod All() As %DynamicObject\n"
        "{\n"
        "\tif $isobject($get(%FlightDeckSchemas)) quit %FlightDeckSchemas\n"
        "\tset xdata = ##class(%Dictionary.CompiledXData).%OpenId($classname()_\"||Schemas\")\n"
        "\tset %FlightDeckSchemas = ##class(%DynamicAbstractObject).%FromJSON(xdata.Data)\n"
        "\tquit %FlightDeckSchemas\n"
        "}\n\n"
        "/// Field names of one schema, in specification order, as a $list.\n"
        "ClassMethod FieldNames(schema As %String) As %List\n"
        "{\n"
        "\tset names = \"\", def = ..All().%Get(schema)\n"
        "\tquit:'$isobject(def) \"\"\n"
        "\tset iter = def.fields.%GetIterator()\n"
        "\twhile iter.%GetNext(, .field) { set names = names _ $listbuild(field.name) }\n"
        "\tquit names\n"
        "}\n\n"
        "}\n"
    )
    ts_target = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT_TS
    cls_target = Path(sys.argv[2]) if len(sys.argv) > 2 else OUT_CLS
    ts_target.parent.mkdir(parents=True, exist_ok=True)
    cls_target.parent.mkdir(parents=True, exist_ok=True)
    ts_target.write_text(ts, encoding="utf-8", newline="\n")
    cls_target.write_text(cls, encoding="utf-8", newline="\n")
    print(f"gen-schemas: {len(data)} schemas -> {ts_target}, {cls_target}")


if __name__ == "__main__":
    main()
