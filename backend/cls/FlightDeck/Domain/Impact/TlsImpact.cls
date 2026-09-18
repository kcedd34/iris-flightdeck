/// Impact of changing or deleting a TLS configuration: the connections that name it stop using the
/// settings they have today (RN-FD-11).
Class FlightDeck.Domain.Impact.TlsImpact [ Abstract ]
{

ClassMethod Impact(current As %DynamicObject, ctx As %DynamicObject) As %DynamicObject
{
	set entity = {"entityType":"tls-configuration", "keys":{"name":(ctx.keys.name)}, "object":(ctx.current), "facts":{}}
	set consumers = ##class(FlightDeck.Domain.Links.TlsConsumers).Group(entity)
	if consumers.state '= "ok" {
		quit {"state":"undetermined", "summary":"What uses this TLS configuration could not be determined.", "reason":(consumers.reason)}
	}
	if consumers.items.%Size() = 0 quit {"state":"none", "summary":"No connection on this instance names this TLS configuration."}
	quit {"state":"ok", "summary":(consumers.items.%Size() _ " " _ $select(consumers.items.%Size()=1:"connection uses", 1:"connections use") _ " this TLS configuration."), "users":[], "objects":(consumers.items)}
}

}
