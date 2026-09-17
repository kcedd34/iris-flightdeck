/// Request mode of the mutation layer (feature 002 spec FR-039, plan Constitution Check V scope
/// note): a mutating REST test request has no current state to compare, so the dry-run shows exactly
/// what will be sent, with the same component and the same graded confirmation (DELETE is reinforced:
/// type the path). The trail records the masked request and its status.
Class FlightDeck.Mutation.RequestMode [ Abstract ]
{

/// Fingerprint of a request: there is no server state to compare, so the request itself is hashed;
/// apply must carry exactly the request that was previewed.
ClassMethod Fingerprint(request As %DynamicObject) As %String
{
	quit ##class(FlightDeck.Mutation.Fingerprint).Of(##class(FlightDeck.Mutation.Mask).Request(request))
}

ClassMethod Context(request As %DynamicObject, descriptor As %DynamicObject, Output failure As %DynamicObject) As %DynamicObject
{
	set failure = ""
	set composite = ##class(FlightDeck.Capability.Composite).Current("rest.execute")
	if $isobject(composite) && ('composite.available || 'composite.allowed) {
		set failure = {"status":($select('composite.available:501, 1:403)), "code":($select('composite.available:"UNAVAILABLE", 1:"FORBIDDEN")), "message":(composite.reason)}
		quit ""
	}
	set test = request.request
	set invalid = ##class(FlightDeck.Rest.Executor).Validate(test)
	if $isobject(invalid) set failure = invalid quit ""
	set method = $zconvert(test.method, "U")
	if '$listfind($listbuild("POST", "PUT", "PATCH", "DELETE"), method) {
		set failure = {"status":400, "code":"BAD_REQUEST", "message":("Only POST, PUT, PATCH and DELETE go through the dry-run; run "_method_" directly.")}
		quit ""
	}
	set test.method = method
	set ctx = {"operationId":(request.operationId), "kind":"request", "keys":{}, "current":{}, "proposed":{}, "changedFields":[], "facts":{}, "request":(test)}
	do ctx.%Set("isSystem", 0, "boolean")
	do ctx.%Set("isFlightDeck", 0, "boolean")
	set ctx.fingerprint = ..Fingerprint(test)
	quit ctx
}

ClassMethod Preview(descriptor As %DynamicObject, ctx As %DynamicObject) As %DynamicObject
{
	set resolved = ##class(FlightDeck.Mutation.Grade).Resolve(descriptor, ctx, "")
	set response = {
		"kind":"request", "target":(ctx.request.method_" "_ctx.request.path), "rows":[],
		"grade":(resolved.grade),
		"fingerprint":(ctx.fingerprint), "impact":{"state":"none"},
		"requestMode":{"request":(##class(FlightDeck.Mutation.Mask).Request(ctx.request)), "reason":"A test request has no current state to compare. This is exactly what will be sent."}
	}
	do response.%Set("confirmText", resolved.confirmText, $select(resolved.confirmText="":"null", 1:"string"))
	do response.%Set("consequence", resolved.consequence, $select(resolved.consequence="":"null", 1:"string"))
	do response.%Set("noChange", 0, "boolean")
	do response.%Set("blocked", "", "null")
	quit response
}

ClassMethod Apply(descriptor As %DynamicObject, ctx As %DynamicObject, preview As %DynamicObject, Output status As %Integer) As %DynamicObject
{
	set result = ##class(FlightDeck.Rest.Executor).Run(ctx.request, .failure)
	if $isobject(failure) {
		set status = failure.status
		set trail = ##class(FlightDeck.Mutation.Service).Trail(preview, ctx, "Failed", failure.status, failure.message)
		quit {"error":{"code":(failure.code), "message":(failure.message), "raw":null}, "trail":(trail)}
	}
	set status = 200
	set outcome = $select(result.status < 400:"Applied", 1:"Failed")
	set trail = ##class(FlightDeck.Mutation.Service).Trail(preview, ctx, outcome, result.status, $select(outcome="Failed":$extract(result.body, 1, 500), 1:""))
	quit {"result":(result), "trail":(trail)}
}

}
