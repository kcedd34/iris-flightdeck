/// Action-kind mutations (feature 003 data-model §5.1, contract ui-pattern-delta D1): official
/// operations that change state through a verb with parameters and no editable object — SQL grant
/// and revoke, a password change, audit purge and copy, secret replacements, token deletions.
/// <p>Principle V holds: an action has a prior state even without an object, so the dry-run shows
/// the affected set before and after (from the descriptor's readOperation), and when the platform
/// offers no listing it shows exactly what will be sent, with the same component and the same
/// graded confirmation.
/// <p>A descriptor declares: params (the official operation's query parameters), optional options
/// (modifiers), an optional readOperation with readParams, an optional rowKey identifying the
/// affected row in that listing, the effect (add or remove), an optional body template, the target
/// template, grades, secret fields and an impact provider.
Class FlightDeck.Mutation.Action [ Abstract ]
{

/// Builds the evaluation context. Returns "" and sets failure when the preview cannot be computed.
ClassMethod Context(request As %DynamicObject, descriptor As %DynamicObject, Output failure As %DynamicObject) As %DynamicObject
{
	set failure = ""
	set operationId = request.operationId
	set capability = ##class(FlightDeck.Capability.Map).CurrentEntry(operationId)
	if 'capability.available {
		set failure = {"status":501, "code":"UNAVAILABLE", "message":(capability.reason)}
		quit ""
	}
	if 'capability.allowed {
		set failure = {"status":403, "code":"FORBIDDEN", "message":(capability.reason)}
		quit ""
	}
	set params = $select($isobject(request.params):request.params, 1:{})
	set options = $select($isobject(request.options):request.options, 1:{})
	// Every declared parameter is required: the official operation identifies its target with them.
	// localParams are required too, but never travel as query parameters: a password belongs in the
	// body, not in a URL that reaches a log (Constitution VI), and a listing's own parameter (the
	// collection a secret belongs to) is not part of the operation FlightDeck calls.
	set required = []
	set iter = descriptor.params.%GetIterator()
	while iter.%GetNext(, .name) { do required.%Push(name) }
	if descriptor.%IsDefined("localParams") {
		set iter = descriptor.localParams.%GetIterator()
		while iter.%GetNext(, .name) { do required.%Push(name) }
	}
	set iter = required.%GetIterator()
	while iter.%GetNext(, .name) {
		if params.%Get(name) = "" {
			set failure = {"status":400, "code":"MISSING_KEY", "message":("Parameter '"_name_"' is required.")}
			quit
		}
	}
	quit:$isobject(failure) ""
	// Optional parameters are declared so they can appear in a body template, and may be empty: an
	// audit purge without dates means every record, which is the official operation's own default.
	if descriptor.%IsDefined("optionalParams") {
		set iter = descriptor.optionalParams.%GetIterator()
		while iter.%GetNext(, .name) { do:'params.%IsDefined(name) params.%Set(name, "") }
	}
	quit:$isobject(failure) ""
	// Only declared options travel: an undeclared one would be sent to the official API unreviewed.
	set out = {}
	if descriptor.%IsDefined("options") {
		set iter = descriptor.options.%GetIterator()
		while iter.%GetNext(, .name) {
			if options.%IsDefined(name) do out.%Set(name, options.%Get(name))
		}
	}
	set ctx = {"operationId":(operationId), "kind":"action", "keys":(params), "params":(params), "options":(out), "current":{}, "proposed":{}, "changedFields":[], "facts":{}}
	do ctx.%Set("isSystem", 0, "boolean")
	do ctx.%Set("isFlightDeck", 0, "boolean")
	set ctx.affected = ..Affected(descriptor, ctx, .readFailure)
	if $isobject(readFailure) set failure = readFailure quit ""
	set ctx.fingerprint = ..Fingerprint(descriptor, ctx)
	quit ctx
}

/// The rows of the descriptor's readOperation that the action affects, or "" when it declares none.
/// Sets failure when the listing cannot be read and the action needs it.
ClassMethod Affected(descriptor As %DynamicObject, ctx As %DynamicObject, Output failure As %DynamicObject) As %DynamicAbstractObject
{
	set failure = ""
	quit:'descriptor.%IsDefined("readOperation") ""
	set query = ..Fill(descriptor.readParams, ctx)
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", ##class(FlightDeck.Domain.Entity).Path(descriptor.readOperation), query, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 {
		set failure = {"status":(status), "code":($select(status=403:"FORBIDDEN", status=501:"UNAVAILABLE", 1:"UPSTREAM_REJECTED")), "message":(##class(FlightDeck.Admin.Client).ErrorText(json, raw)), "raw":(raw)}
		quit ""
	}
	quit $select($isobject(json) && $isobject(json.result):json.result, 1:[])
}

/// True when a listing row is the one the action names (descriptor rowKey: field -> {param}).
/// <p>rowKey is a list of {field, value} pairs, not an object: an official listing field may be
/// named "Privilege", and a descriptor may never carry a key by that name (Constitution III).
/// A pair may name alternative fields separated by "|": the official SQL listings return `Object`
/// and `Action` where their own schema declares `Name` and `Privilege`, a divergence recorded in
/// verification/README.md. FlightDeck accepts either rather than guessing which build it is talking
/// to, and never rewrites what the API returned.
ClassMethod Matches(descriptor As %DynamicObject, ctx As %DynamicObject, row As %DynamicObject) As %Boolean
{
	quit:'descriptor.%IsDefined("rowKey") 0
	set iter = descriptor.rowKey.%GetIterator(), match = 1
	while iter.%GetNext(, .key) {
		set fields = key.field, wanted = $zconvert(..Template(key.value, ctx), "U"), found = 0
		for i=1:1:$length(fields, "|") {
			set field = $piece(fields, "|", i)
			if row.%IsDefined(field), $zconvert(row.%Get(field), "U") = wanted set found = 1 quit
		}
		if 'found set match = 0 quit
	}
	quit match
}

/// The matched row, or "" when the action's target is absent from the listing.
ClassMethod Matched(descriptor As %DynamicObject, ctx As %DynamicObject) As %DynamicObject
{
	quit:'$isobject(ctx.affected) ""
	set iter = ctx.affected.%GetIterator(), found = ""
	while iter.%GetNext(, .row) { if ..Matches(descriptor, ctx, row) { set found = row quit } }
	quit found
}

/// "{param}" -> the parameter's value; anything else is literal.
ClassMethod Template(text As %String, ctx As %DynamicObject) As %String
{
	set iter = ctx.params.%GetIterator()
	while iter.%GetNext(.name, .value) { set text = $replace(text, "{"_name_"}", value) }
	set iter = ctx.options.%GetIterator()
	while iter.%GetNext(.name, .value) { set text = $replace(text, "{"_name_"}", value) }
	quit text
}

/// Fills a template object ({"grantee":"{grantee}"}) from the context's parameters.
/// Fills a template object from the context's parameters. A field whose template resolves to
/// nothing is left out: an empty date is not the same as a date, and the official operation reads
/// its absence as "every record".
ClassMethod Fill(template As %DynamicObject, ctx As %DynamicObject) As %DynamicObject
{
	set out = {}
	quit:'$isobject(template) out
	set iter = template.%GetIterator()
	while iter.%GetNext(.key, .value) {
		if $isobject(value) {
			set nested = ..Fill(value, ctx)
			do:nested.%Size()>0 out.%Set(key, nested)
			continue
		}
		set filled = ..Template(value, ctx)
		continue:filled=""
		continue:(($extract(filled) = "{") && ($extract(filled, *) = "}"))
		do out.%Set(key, filled)
	}
	quit out
}

/// The state the preview was computed from: the matched row when there is a listing, the parameters
/// themselves when there is none (so apply must carry exactly what was reviewed).
ClassMethod Fingerprint(descriptor As %DynamicObject, ctx As %DynamicObject) As %String
{
	set matched = ..Matched(descriptor, ctx)
	set state = {"params":(##class(FlightDeck.Mutation.Mask).Object(##class(%DynamicAbstractObject).%FromJSON(ctx.params.%ToJSON()), descriptor.secretFields)), "options":(ctx.options)}
	if $isobject(matched) set state.row = matched
	do state.%Set("present", $isobject(matched), "boolean")
	quit ##class(FlightDeck.Mutation.Fingerprint).Of(state, descriptor.secretFields)
}

/// The PreviewResponse for an action (masked).
ClassMethod Preview(descriptor As %DynamicObject, ctx As %DynamicObject) As %DynamicObject
{
	set target = ##class(FlightDeck.Mutation.Grade).Target(descriptor, ctx.params)
	set target = ..Template(target, ctx)
	set resolved = ##class(FlightDeck.Mutation.Grade).Resolve(descriptor, ctx, ctx.params)
	set matched = ..Matched(descriptor, ctx)
	set effect = $select(descriptor.%IsDefined("effect"):descriptor.effect, 1:"")
	set rows = [], noChange = 0
	if $isobject(ctx.affected) {
		// The affected set, before and after: only the named row changes, and it is the only row shown
		// as changed. Nothing is sent until apply.
		set present = $isobject(matched)
		set after = $case(effect, "add":1, "remove":0, :present)
		set label = ..Label(descriptor, ctx)
		set row = {"field":(label), "label":(label)}
		do row.%Set("changed", (present '= after), "boolean")
		do row.%Set("secret", 0, "boolean")
		do row.%Set("current", $select(present:..RowText(matched), 1:"not granted"))
		do row.%Set("commanded", $select(after:"granted", 1:"not granted"))
		do rows.%Push(row)
		set noChange = (present = after)
	}
	set response = {
		"kind":"action", "target":(target), "rows":(rows), "grade":(resolved.grade),
		"fingerprint":(ctx.fingerprint), "impact":{"state":"none"}
	}
	do response.%Set("confirmText", $select(resolved.confirmText="":"", 1:target), $select(resolved.confirmText="":"null", 1:"string"))
	do response.%Set("consequence", resolved.consequence, $select(resolved.consequence="":"null", 1:"string"))
	do response.%Set("noChange", noChange, "boolean")
	set blocked = ##class(FlightDeck.Mutation.SelfProtection).Evaluate(descriptor, ctx)
	if blocked = "" { do response.%Set("blocked", "", "null") } else { set response.blocked = {"message":(blocked)} }
	// Without a listing the user reviews exactly what will be sent, as in request mode.
	if 'descriptor.%IsDefined("readOperation") {
		set response.requestMode = {
			"request": {"method":($piece(ctx.operationId, " ", 1)), "path":(##class(FlightDeck.Domain.Entity).Path(ctx.operationId)), "query":(..Query(descriptor, ctx)), "headers":{}},
			"reason": "This operation takes parameters, not an object. The platform offers no listing to compare, so this is exactly what will be sent."
		}
		if descriptor.%IsDefined("body") set response.requestMode.request.body = ##class(FlightDeck.Mutation.Mask).Object(..Fill(descriptor.body, ctx), descriptor.secretFields).%ToJSON()
	} else {
		do response.%Set("requestMode", "", "null")
	}
	// What the user should know while the instance works on it (feature 003: the platform's own TLS
	// test takes a fixed ten seconds).
	do response.%Set("applyNotice", $select(descriptor.%IsDefined("applyNotice"):descriptor.applyNotice, 1:""), $select(descriptor.%IsDefined("applyNotice"):"string", 1:"null"))
	if descriptor.%IsDefined("impact") {
		set when = $select(descriptor.%IsDefined("impactWhen"):descriptor.impactWhen, 1:{"op":"true"})
		if ##class(FlightDeck.Domain.Predicate).Eval(when, ctx) set response.impact = ##class(FlightDeck.Mutation.Service).Impact(descriptor.impact, ctx.current, ctx)
	}
	quit response
}

/// Human label of the affected row, from the descriptor's rowLabel template.
ClassMethod Label(descriptor As %DynamicObject, ctx As %DynamicObject) As %String
{
	quit ..Template($select(descriptor.%IsDefined("rowLabel"):descriptor.rowLabel, 1:descriptor.target), ctx)
}

/// What the listing says about the row today, including the provenance the official API reports.
ClassMethod RowText(row As %DynamicObject) As %String
{
	set text = "granted"
	if row.%IsDefined("GrantedVia"), row.GrantedVia '= "" set text = text _ " (" _ row.GrantedVia _ ")"
	quit text
}

/// The query the official operation receives: declared parameters plus declared options.
ClassMethod Query(descriptor As %DynamicObject, ctx As %DynamicObject) As %DynamicObject
{
	set query = {}
	set iter = descriptor.params.%GetIterator()
	while iter.%GetNext(, .name) { do query.%Set(name, ctx.params.%Get(name)) }
	set iter = ctx.options.%GetIterator()
	while iter.%GetNext(.name, .value) { do query.%Set(name, value) }
	quit query
}

/// apply: sends the official operation with its parameters and optional body.
ClassMethod Apply(descriptor As %DynamicObject, ctx As %DynamicObject, preview As %DynamicObject, Output status As %Integer) As %DynamicObject
{
	set method = $piece(ctx.operationId, " ", 1), path = ##class(FlightDeck.Domain.Entity).Path(ctx.operationId)
	set body = ""
	if descriptor.%IsDefined("body") set body = ..Fill(descriptor.body, ctx)
	set sc = ##class(FlightDeck.Domain.Upstream).Call(method, path, ..Query(descriptor, ctx), body, .writeStatus, .json, .raw)
	if $$$ISERR(sc) set writeStatus = 500, raw = $system.Status.GetErrorText(sc), json = ""
	if writeStatus >= 300 {
		set message = ##class(FlightDeck.Mutation.Mask).Text(##class(FlightDeck.Admin.Client).ErrorText(json, raw), ..Fill($select(descriptor.%IsDefined("body"):descriptor.body, 1:{}), ctx), descriptor.secretFields)
		set trail = ##class(FlightDeck.Mutation.Service).Trail(preview, ctx, "Failed", writeStatus, message)
		set status = 502
		set response = {"error":{"code":"UPSTREAM_REJECTED", "message":(message), "raw":(##class(FlightDeck.Mutation.Mask).Text(raw, ..Fill($select(descriptor.%IsDefined("body"):descriptor.body, 1:{}), ctx), descriptor.secretFields))}, "trail":(trail)}
		do response.%Set("validation", ##class(FlightDeck.Mutation.Service).IsValidation(json, writeStatus), "boolean")
		do response.%Set("officialStatus", writeStatus, "number")
		quit response
	}
	do ##class(FlightDeck.Domain.LinkCache).Invalidate()
	set status = 200
	quit {"result":{}, "trail":(##class(FlightDeck.Mutation.Service).Trail(preview, ctx, "Applied", writeStatus, ""))}
}

}
