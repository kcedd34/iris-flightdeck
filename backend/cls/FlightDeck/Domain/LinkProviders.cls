/// Registry of link providers named by entity-type descriptors (feature 002 data-model §1.3).
/// Every provider composes official reads only, declares the operations it calls (for composite
/// capabilities), and answers one LinkGroup or "" when the group does not apply.
/// <p>A provider that serves several groups of the same family names its method after a colon
/// ("Class:Method"); the class still declares every operation those groups call.
Class FlightDeck.Domain.LinkProviders [ Abstract ]
{

ClassMethod Class(provider As %String) As %String
{
	// The pattern catalog's own providers exist only on a fixtures install (research R13).
	if provider = "catalog-tags" quit $select(##class(FlightDeck.Domain.Fixtures).Enabled():##class(FlightDeck.Domain.Fixtures).#CATALOG, 1:"")
	quit $case(provider,
		"resource-roles":"FlightDeck.Domain.Links.ResourceRoles",
		"role-owners":"FlightDeck.Domain.Links.RoleOwners",
		"resource-public":"FlightDeck.Domain.Links.ResourcePublic",
		"rest-service":"FlightDeck.Domain.Links.RestService",
		"role-holders":"FlightDeck.Domain.Links.RoleHolders",
		"user-roles":"FlightDeck.Domain.Links.UserRoles",
		"effective-privileges":"FlightDeck.Domain.Links.EffectivePrivileges",
		"role-resources":"FlightDeck.Domain.Links.RoleResources",
		"resource-objects":"FlightDeck.Domain.Links.ResourceObjects",
		"sql-privileges":"FlightDeck.Domain.Links.SqlPrivileges",
		"wallet-secrets":"FlightDeck.Domain.Links.WalletSecrets",
		"wallet-users":"FlightDeck.Domain.Links.WalletUsers",
		"tls-consumers":"FlightDeck.Domain.Links.TlsConsumers",
		"certificate":"FlightDeck.Domain.Links.Certificate",
		"oauth2-clients":"FlightDeck.Domain.Links.OAuth2Clients",
		"encryption-keys":"FlightDeck.Domain.Links.EncryptionKeys:Activated",
		"encryption-data-element-keys":"FlightDeck.Domain.Links.EncryptionKeys:DataElement",
		"encryption-file-keys":"FlightDeck.Domain.Links.EncryptionKeys:FileKeys",
		"encryption-file-admins":"FlightDeck.Domain.Links.EncryptionKeys:FileAdmins",
		"oauth2-resource-server-mappings":"FlightDeck.Domain.Links.ResourceServerMappings",
		"audit-records":"FlightDeck.Domain.Links.AuditRecords",
		"global-mappings":"FlightDeck.Domain.Links.GlobalMappings",
		"package-mappings":"FlightDeck.Domain.Links.PackageMappings",
		"routine-mappings":"FlightDeck.Domain.Links.RoutineMappings",
		"database-volumes":"FlightDeck.Domain.Links.DatabaseVolumes",
		"ecp-databases":"FlightDeck.Domain.Links.EcpDatabases",
		"language-server-activity":"FlightDeck.Domain.Links.LanguageServerActivity",
		"fs-access-paths":"FlightDeck.Domain.Links.FsAccessPaths",
		"task-upcoming":"FlightDeck.Domain.Links.TaskUpcoming",
		:"")
}

/// Declares a parameter the provider needs before it can answer (feature 003 contract
/// ui-pattern-delta D2): the panel renders a control for it, and the group answers nothing until it
/// has a value. `values` are the known choices when the session may list them, empty when it may not
/// — the reason then says why, and the control accepts a typed value.
ClassMethod Parameter(name As %String, required As %Boolean = 1, values As %DynamicArray = "", value As %String = "") As %DynamicObject
{
	set parameter = {"name":(name)}
	do parameter.%Set("required", required, "boolean")
	set parameter.values = $select($isobject(values):values, 1:[])
	do parameter.%Set("value", value, $select(value="":"null", 1:"string"))
	quit parameter
}

/// Marks a group as waiting for a parameter the caller has not supplied yet.
ClassMethod NeedsParameter(group As %DynamicObject, parameters As %DynamicArray, reason As %String = "") As %DynamicObject
{
	set group.state = "needs-parameter"
	set group.parameters = parameters
	if reason '= "" set group.reason = reason
	quit group
}

/// A LinkGroup skeleton.
ClassMethod NewGroup(provider As %String, label As %String, direction As %String = "out") As %DynamicObject
{
	set group = {"provider":(provider), "direction":(direction), "label":(label), "state":"ok", "items":[]}
	do group.%Set("reason", "", "null")
	do group.%Set("count", "", "null")
	quit group
}

/// Marks a group as refused or failed from an official call's answer, verbatim.
ClassMethod FromFailure(group As %DynamicObject, operationId As %String, status As %Integer, json As %DynamicAbstractObject, raw As %String) As %DynamicObject
{
	if status = 403 {
		set group.state = "forbidden"
		set op = ##class(FlightDeck.Capability.Map).Operation(operationId)
		set group.reason = $select($isobject(op):##class(FlightDeck.API.Response).RequiresMessage(op.requires), 1:##class(FlightDeck.Admin.Client).ErrorText(json, raw))
	} elseif status = 501 {
		set group.state = "unavailable"
		set group.reason = ##class(FlightDeck.Admin.Client).UnavailableReason(operationId)
	} else {
		set group.state = "undetermined"
		set group.reason = ##class(FlightDeck.Admin.Client).ErrorText(json, raw)
	}
	quit group
}

/// LinkItem.
ClassMethod Item(entityType As %String, domain As %String, name As %String, detail As %String = "") As %DynamicObject
{
	set item = {"entityType":(entityType), "domain":(domain), "displayName":(name), "keys":{"name":(name)}}
	do item.%Set("detail", detail, $select(detail="":"null", 1:"string"))
	quit item
}

}
