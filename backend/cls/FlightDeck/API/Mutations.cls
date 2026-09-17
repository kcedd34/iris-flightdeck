/// POST /v1/mutations/preview and /apply (feature 002 contract). Thin HTTP adapter over
/// FlightDeck.Mutation.Service. apply is guarded by the Router's safe-mode check (it is not in the
/// allow-list); preview changes nothing and is allowed while safe mode is armed.
Class FlightDeck.API.Mutations [ Abstract ]
{

ClassMethod Preview() As %Status
{
	set request = ..Body(.sc)
	quit:$$$ISERR(sc) ..BadBody(sc)
	set body = ##class(FlightDeck.Mutation.Service).DoPreview(request, .status)
	quit ##class(FlightDeck.API.Response).WriteJSON(body, status)
}

ClassMethod Apply() As %Status
{
	set request = ..Body(.sc)
	quit:$$$ISERR(sc) ..BadBody(sc)
	set body = ##class(FlightDeck.Mutation.Service).DoApply(request, .status)
	quit ##class(FlightDeck.API.Response).WriteJSON(body, status)
}

ClassMethod Body(Output sc As %Status) As %DynamicObject
{
	set sc = $$$OK
	try {
		set request = ##class(%DynamicAbstractObject).%FromJSON(%request.Content)
		if '$isobject(request) || (request.operationId = "") set sc = $$$ERROR($$$GeneralError, "operationId is required.")
	} catch ex {
		set sc = ex.AsStatus(), request = ""
	}
	quit request
}

ClassMethod BadBody(sc As %Status) As %Status
{
	quit ##class(FlightDeck.API.Response).WriteError(400, "BAD_REQUEST", "The request body is not a valid mutation request.", $system.Status.GetErrorText(sc))
}

}
