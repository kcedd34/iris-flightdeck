/// REST API explorer endpoints (UC04, feature 002 contract): discovery, specification, and the
/// confined test executor. POST /v1/rest/execute is allow-listed in the Router's safe-mode guard
/// because it applies the guard to the method of the request under test: GET, HEAD and OPTIONS run
/// directly; POST, PUT, PATCH and DELETE are refused while armed and, disarmed, run only through
/// POST /v1/mutations/apply in request mode, so no path skips the dry-run (research R8).
Class FlightDeck.API.Rest [ Abstract ]
{

ClassMethod Services() As %Status
{
	quit ##class(FlightDeck.API.Response).WriteJSON(##class(FlightDeck.Rest.Discovery).Services())
}

ClassMethod Specification() As %Status
{
	set webApplication = $get(%request.Data("webApplication", 1)), name = $get(%request.Data("name", 1))
	set service = ##class(FlightDeck.Rest.Discovery).Find(webApplication, name)
	if '$isobject(service) quit ##class(FlightDeck.API.Response).WriteError(404, "NOT_FOUND", "No REST service "_$select(webApplication'="":webApplication, 1:name)_" was discovered.")
	set response = ##class(FlightDeck.Rest.Discovery).Specification(service, .status, .error)
	if status '= 200 quit ##class(FlightDeck.API.Response).WriteError(status, $select(status=403:"FORBIDDEN", 1:"UPSTREAM_REJECTED"), error, error)
	quit ##class(FlightDeck.API.Response).WriteJSON(response)
}

ClassMethod Execute() As %Status
{
	try {
		set request = ##class(%DynamicAbstractObject).%FromJSON(%request.Content)
	} catch {
		return ##class(FlightDeck.API.Response).WriteError(400, "BAD_REQUEST", "The request body is not a valid test request.")
	}
	set method = $zconvert(request.method, "U")
	if $listfind($listbuild("POST", "PUT", "PATCH", "DELETE"), method) {
		if %request.GetCgiEnv("HTTP_X_FLIGHTDECK_SAFE_MODE") '= "disarmed" {
			quit ##class(FlightDeck.API.Response).WriteError(403, "SAFE_MODE_ON", ##class(FlightDeck.API.Response).#MSGSAFEMODE)
		}
		quit ##class(FlightDeck.API.Response).WriteError(422, "CONFIRMATION_REQUIRED", method_" test requests run through the dry-run: preview and apply them in request mode.")
	}
	set composite = ##class(FlightDeck.Capability.Composite).Current("rest.execute")
	if $isobject(composite) && 'composite.available quit ##class(FlightDeck.API.Response).WriteError(501, "UNAVAILABLE", composite.reason)
	if $isobject(composite) && 'composite.allowed quit ##class(FlightDeck.API.Response).WriteError(403, "FORBIDDEN", composite.reason)
	set result = ##class(FlightDeck.Rest.Executor).Run(request, .failure)
	if $isobject(failure) quit ##class(FlightDeck.API.Response).WriteError(failure.status, failure.code, failure.message)
	quit ##class(FlightDeck.API.Response).WriteJSON(result)
}

}
