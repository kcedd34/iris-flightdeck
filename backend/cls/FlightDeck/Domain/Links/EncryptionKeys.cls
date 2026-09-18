/// Link providers for the encryption section's reads.
/// <p>FlightDeck declines the encryption **writes** on every version (feature 003: a mistake there
/// can make data permanently unreadable, and there is no safe way to rehearse it). The reads were
/// never part of that decision, and a section that shows a setting but not the keys it applies to is
/// telling half the truth. These four are the other half.
Class FlightDeck.Domain.Links.EncryptionKeys [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/encryption/keys", "GET /v2/security/encryption/data-element-keys", "GET /v2/security/encryption/file/keys", "GET /v2/security/encryption/file/admins")
}

/// The keys the instance has activated.
ClassMethod Activated(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	quit ..Simple("encryption-keys", "activated encryption keys", "GET /v2/security/encryption/keys")
}

/// The keys used for data-element encryption.
ClassMethod DataElement(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	quit ..Simple("encryption-data-element-keys", "data element encryption keys", "GET /v2/security/encryption/data-element-keys")
}

/// The keys inside one key file. The file is a parameter: the platform answers only for a named one.
ClassMethod FileKeys(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	quit ..ForFile("encryption-file-keys", "keys in this key file", "GET /v2/security/encryption/file/keys", params)
}

/// The administrators of one key file: who may activate the keys that make data readable.
ClassMethod FileAdmins(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	quit ..ForFile("encryption-file-admins", "administrators of this key file", "GET /v2/security/encryption/file/admins", params)
}

ClassMethod Simple(id As %String, label As %String, operationId As %String) As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup(id, label, "out")
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", ##class(FlightDeck.Domain.Entity).Path(operationId), {}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, operationId, status, $get(json), $get(raw))
	do ..Fill(group, json)
	quit group
}

ClassMethod ForFile(id As %String, label As %String, operationId As %String, params As %DynamicObject) As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup(id, label, "out")
	set file = $select($isobject(params):params.%Get("file"), 1:"")
	if file = "" {
		// The platform names no key file of its own, so the value is typed: the group answers nothing
		// until it has one, and says so rather than showing an empty list (contract delta D2).
		set parameters = [(##class(FlightDeck.Domain.LinkProviders).Parameter("file", 1, []))]
		quit ##class(FlightDeck.Domain.LinkProviders).NeedsParameter(group, parameters, "Name the key file to read, as the instance knows it.")
	}
	set group.parameters = [(##class(FlightDeck.Domain.LinkProviders).Parameter("file", 1, [], file))]
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", ##class(FlightDeck.Domain.Entity).Path(operationId), {"file":(file)}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, operationId, status, $get(json), $get(raw))
	do ..Fill(group, json)
	quit group
}

/// Rows as the platform returned them. A key is identified by whatever field it carries; nothing is
/// composed, and no key material is ever part of these answers.
ClassMethod Fill(group As %DynamicObject, json As %DynamicAbstractObject)
{
	set rows = $select($isobject(json) && $isobject(json.result):json.result, 1:[])
	if '$isobject(rows) || (rows.%ClassName(1) '= "%Library.DynamicArray") {
		set rows = $select($isobject(rows):[(rows)], 1:[])
	}
	set iter = rows.%GetIterator()
	while iter.%GetNext(, .row) {
		if '$isobject(row) {
			do group.items.%Push({"entityType":"encryption-key", "domain":"security", "displayName":(row), "keys":{}, "detail":""})
			continue
		}
		set name = $select(row.%IsDefined("KeyID"):row.KeyID, row.%IsDefined("Name"):row.Name, row.%IsDefined("Username"):row.Username, 1:"")
		set detail = $select(row.%IsDefined("Description"):row.Description, row.%IsDefined("Type"):row.Type, row.%IsDefined("KeyFile"):row.KeyFile, 1:"")
		do group.items.%Push({"entityType":"encryption-key", "domain":"security", "displayName":(name), "keys":{}, "detail":(detail)})
	}
	set group.count = group.items.%Size()
}

}
