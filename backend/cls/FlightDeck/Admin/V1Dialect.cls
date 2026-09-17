/// Translates a v2 operation into its SysAdmin API v1 request. The table (FlightDeck.Admin.V1Routes)
/// is keyed by v2 operationId, so privileges and domain assignment always come from the v2 contract
/// (Constitution III, dialect note). Every different-shape translation is verified by effect in
/// FlightDeck.Test.V1Translations.
Class FlightDeck.Admin.V1Dialect [ Abstract ]
{

/// True when the v2 operation has a v1 route or a v1-only native provider.
ClassMethod IsAvailable(operationId As %String) As %Boolean
{
	quit $isobject(##class(FlightDeck.Admin.V1Routes).Table().%Get(operationId))
}

/// True when a v1-only native provider answers the operation (Constitution I gaps); outputs its class.
ClassMethod NativeProvider(operationId As %String, Output provider As %String) As %Boolean
{
	set entry = ##class(FlightDeck.Admin.V1Routes).Table().%Get(operationId)
	set provider = $select($isobject(entry):entry.native, 1:"")
	quit provider '= ""
}

/// The reason an unavailable operation carries: the version message, followed by the recorded
/// reason when the operation is deliberately withheld (namespace writes, journal).
ClassMethod UnavailableReason(operationId As %String) As %String
{
	set reason = ##class(FlightDeck.API.Response).#MSGVERSION
	set withheld = ##class(FlightDeck.Admin.V1Routes).Withheld().%Get(operationId)
	quit reason _ $select(withheld'="":" "_withheld, 1:"")
}

/// Outputs the v1 method, dispatcher-relative path and body. Returns 0 when there is no v1 route.
ClassMethod Translate(operationId As %String, body As %DynamicAbstractObject, Output method As %String, Output path As %String, Output v1Body As %DynamicAbstractObject) As %Boolean
{
	set method = "", path = "", v1Body = ""
	set entry = ##class(FlightDeck.Admin.V1Routes).Table().%Get(operationId)
	if '$isobject(entry) || (entry.native '= "") quit 0
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
