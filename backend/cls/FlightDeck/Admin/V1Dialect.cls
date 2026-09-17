/// Translates a v2 operation into its SysAdmin API v1 request. The table (FlightDeck.Admin.V1Routes)
/// is keyed by v2 operationId, so privileges and domain assignment always come from the v2 contract
/// (Constitution III, dialect note). Every different-shape translation is verified by effect in
/// FlightDeck.Test.V1Translations.
Class FlightDeck.Admin.V1Dialect [ Abstract ]
{

/// True when the v2 operation has a v1 route.
ClassMethod IsAvailable(operationId As %String) As %Boolean
{
	quit $isobject(##class(FlightDeck.Admin.V1Routes).Table().%Get(operationId))
}

/// Outputs the v1 method, dispatcher-relative path and body. Returns 0 when there is no v1 route.
ClassMethod Translate(operationId As %String, body As %DynamicAbstractObject, Output method As %String, Output path As %String, Output v1Body As %DynamicAbstractObject) As %Boolean
{
	set method = "", path = "", v1Body = ""
	set entry = ##class(FlightDeck.Admin.V1Routes).Table().%Get(operationId)
	if '$isobject(entry) quit 0
	set method = entry.method
	set path = $select(entry.unversioned:"", 1:"/v1") _ entry.path
	set rule = entry.body.rule
	if rule = "passthrough" {
		set v1Body = body
	} elseif rule = "action" {
		set v1Body = {"Action":(entry.body.value)}
	} elseif rule = "actionFromBoolean" {
		set flag = entry.body.default
		if $isobject(body), body.%IsDefined(entry.body.field) set flag = body.%Get(entry.body.field)
		set v1Body = {"Action":($select(flag:entry.body.ifTrue, 1:entry.body.ifFalse))}
	}
	quit 1
}

}
