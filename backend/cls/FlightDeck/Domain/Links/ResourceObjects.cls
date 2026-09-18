/// Link provider "resource-objects" (feature 003 spec FR-005, research R8): what a resource
/// protects — web applications, wallet collections, privileged routine applications and services.
/// <p>Each source is one official listing, gated on its own capability: when one is refused or
/// unavailable, that source is named in the reason and the others still answer. The group never
/// implies "nothing" when it means "could not read".
Class FlightDeck.Domain.Links.ResourceObjects [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/web-apps", "GET /v2/wallet/collections", "GET /v2/security/privileged-routines", "GET /v2/security/services")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set resource = entity.keys.name
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("resource-objects", "objects this resource protects", "in")
	set unread = []
	do ..Collect(group, unread, "GET /v2/web-apps", {"maxRows":1000}, "Resource", resource, "web-application", "web-apps", "Name", "web application")
	do ..Collect(group, unread, "GET /v2/wallet/collections", {"maxRows":1000}, "UseResource", resource, "wallet-collection", "security", "Name", "wallet collection (use)")
	do ..Collect(group, unread, "GET /v2/wallet/collections", {"maxRows":1000}, "EditResource", resource, "wallet-collection", "security", "Name", "wallet collection (edit)")
	do ..Collect(group, unread, "GET /v2/security/privileged-routines", {"maxRows":1000}, "Resource", resource, "privileged-routine", "permissions", "Name", "privileged routine application")
	do ..Collect(group, unread, "GET /v2/security/services", {"maxRows":1000}, "Resource", resource, "service", "permissions", "Name", "service")
	set group.count = group.items.%Size()
	if unread.%Size() > 0 {
		do group.%Set("truncated", 1, "boolean")
		set group.state = "undetermined"
		set group.reason = "These are the objects that could be read. Not read: " _ ##class(FlightDeck.Domain.Links.RoleHolders).PathText(unread)
	}
	quit group
}

/// One official listing: every item whose `field` names this resource becomes a link.
ClassMethod Collect(group As %DynamicObject, unread As %DynamicArray, operationId As %String, query As %DynamicObject, field As %String, resource As %String, entityType As %String, domain As %String, nameField As %String, label As %String)
{
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", ##class(FlightDeck.Domain.Entity).Path(operationId), query, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 {
		do unread.%Push(label _ "s (" _ ##class(FlightDeck.Admin.Client).ErrorText($get(json), $get(raw)) _ ")")
		quit
	}
	set items = $select($isobject(json) && $isobject(json.result):json.result, 1:[])
	set iter = items.%GetIterator()
	while iter.%GetNext(, .item) {
		// Some listings name the resource with the permission it needs ("FD_Demo_Reports:WRITE" on a
		// wallet collection); the resource is the part before the colon.
		set named = $piece(item.%Get(field), ":", 1)
		continue:(named'=resource)
		set detail = label _ $select($piece(item.%Get(field), ":", 2)'="":" (" _ $zconvert($piece(item.%Get(field), ":", 2), "L") _ ")", 1:"")
		do group.items.%Push(##class(FlightDeck.Domain.LinkProviders).Item(entityType, domain, item.%Get(nameField), detail))
	}
}

}
