/// Link provider "tls-consumers": what names a TLS configuration — MFT connections, OAuth client
/// configurations and superservers. Each source is capability-gated on its own operation.
Class FlightDeck.Domain.Links.TlsConsumers [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/mft/connections", "GET /v2/security/superservers")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set name = $select(entity.entityType = "tls-configuration":entity.keys.name, 1:entity.object.SSLConfig)
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("tls-consumers", "configurations use this TLS configuration", "in")
	if name = "" {
		set group.label = "No TLS configuration is named here"
		set group.count = 0
		quit group
	}
	set unread = []
	do ..Collect(group, unread, "GET /v2/security/mft/connections", "SSLConfiguration", name, "mft-connection", "Name", "MFT connection")
	do ..Collect(group, unread, "GET /v2/security/superservers", "SSLConfig", name, "superserver", "Port", "superserver")
	set group.count = group.items.%Size()
	if unread.%Size() > 0 {
		set group.state = "undetermined"
		set group.reason = "Not read: " _ ##class(FlightDeck.Domain.Links.RoleHolders).PathText(unread)
	}
	quit group
}

ClassMethod Collect(group As %DynamicObject, unread As %DynamicArray, operationId As %String, field As %String, name As %String, entityType As %String, nameField As %String, label As %String)
{
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", ##class(FlightDeck.Domain.Entity).Path(operationId), {"maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 {
		do unread.%Push(label _ "s (" _ ##class(FlightDeck.Admin.Client).ErrorText($get(json), $get(raw)) _ ")")
		quit
	}
	set iter = $select($isobject(json) && $isobject(json.result):json.result, 1:[]).%GetIterator()
	while iter.%GetNext(, .item) {
		continue:(item.%Get(field)'=name)
		do group.items.%Push(##class(FlightDeck.Domain.LinkProviders).Item(entityType, "security", item.%Get(nameField), label))
	}
}

}
