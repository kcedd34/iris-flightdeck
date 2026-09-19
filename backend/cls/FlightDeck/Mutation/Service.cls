/// The only server path that sends SysAdmin API writes, for this feature and every later domain
/// (Constitution V, feature 002 research R3 to R7, data-model §3.3 to §3.5).
/// <p>preview reads the current state through the official operation, computes the field-by-field
/// diff, grade, impact, self-protection and a state fingerprint. apply re-reads, refuses when the
/// fingerprint changed (nothing is overwritten), re-evaluates self-protection and grade against the
/// re-read state, checks the typed confirmation, then sends only what changed. Every answer is
/// masked before it leaves the server; every applied, failed or blocked write produces a trail
/// record.
Class FlightDeck.Mutation.Service [ Abstract ]
{

/// §9 message 17.
Parameter MSGCHANGED = "This object changed on the server while you were editing. Review the updated differences before applying.";

/// §9 message 18.
Parameter MSGNOCHANGE = "Nothing to apply. The proposed state matches the current one.";

Parameter CONCURRENCY = "checked: the object was re-read immediately before writing; a change made in the instant between that read and the write cannot be detected (the official API offers no version token)";

/// IRIS error codes the official API returns with HTTP 500 for rejected input (research R2).
Parameter VALIDATIONCODES = "1498,5802,7207,5659,7201,7202,7203,7204,7205,7206,7208,7209,7210,40301";

/// Builds the evaluation context. Returns "" and sets failure {status, code, message, raw} when the
/// preview cannot be computed.
/// Why this operation is refused for this object, or "" when it is not.
/// <p>Two sources, both declared as data: the descriptor's self-protection rules, and the capability
/// the official schema states about the object itself (<var>refusedWhen</var>). The rule is written
/// as a refusal rather than as a permission on purpose: a fact FlightDeck could not read is not a
/// refusal, so an unknown capability lets the platform answer for itself instead of being denied by
/// the portal on a guess. The second is the
/// rule of RN-FD-34 enforced where it must be — on the server. A screen that hid the control is not
/// a guard; a request that arrives anyway is refused here (feature 004 spec FR-029).
ClassMethod Refusal(descriptor As %DynamicObject, ctx As %DynamicObject) As %String
{
	set message = ##class(FlightDeck.Mutation.SelfProtection).Evaluate(descriptor, ctx)
	quit:message'="" message
	quit:'descriptor.%IsDefined("refusedWhen") ""
	quit:'##class(FlightDeck.Domain.Predicate).Eval(descriptor.refusedWhen, ctx) ""
	quit $select(descriptor.%IsDefined("disabledReason"):descriptor.disabledReason, 1:"The instance does not allow this operation on this object.")
}

ClassMethod Context(request As %DynamicObject, Output descriptor As %DynamicObject, Output failure As %DynamicObject) As %DynamicObject
{
	set failure = ""
	set operationId = request.operationId
	set descriptor = ##class(FlightDeck.Domain.Descriptor).Mutation(operationId)
	if '$isobject(descriptor) {
		set failure = {"status":404, "code":"NOT_FOUND", "message":("No mutation descriptor for "_operationId_".")}
		quit ""
	}
	if descriptor.kind = "request" quit ##class(FlightDeck.Mutation.RequestMode).Context(request, descriptor, .failure)
	if descriptor.kind = "action" quit ##class(FlightDeck.Mutation.Action).Context(request, descriptor, .failure)
	set capability = ##class(FlightDeck.Capability.Map).CurrentEntry(operationId)
	if 'capability.available {
		set failure = {"status":501, "code":"UNAVAILABLE", "message":(capability.reason)}
		quit ""
	}
	if 'capability.allowed {
		set failure = {"status":403, "code":"FORBIDDEN", "message":(capability.reason)}
		quit ""
	}
	set typeId = descriptor.entityType
	set type = ##class(FlightDeck.Domain.Descriptor).EntityType($piece(typeId, "/", 1), $piece(typeId, "/", 2))
	set keys = $select($isobject(request.keys):request.keys, 1:{})
	// A creation whose key the instance assigns has no key to require yet. Four operations are shaped
	// that way — a new task, a new database directory and the two OAuth 2.0 creates — and their
	// descriptors say so by naming no {key} in their target. Requiring the key regardless made all
	// four unreachable through the only path FlightDeck has to them: they answered "Key 'id' is
	// required" for an id that cannot exist until the operation has run. Found by feature 008, which
	// executed them for the first time.
	set assignsKey = (descriptor.target '[ "{")
	if 'assignsKey {
		set k = type.keys.%GetIterator()
		while k.%GetNext(, .key) {
			if keys.%Get(key.param) = "" {
				set failure = {"status":400, "code":"MISSING_KEY", "message":("Key '"_key.param_"' is required.")}
				quit
			}
		}
	}
	quit:$isobject(failure) ""
	// Current state through the official read operation. A creation with no key yet has none to read:
	// asking would send the read operation a request without its key, and its complaint would be
	// reported as though the create had failed.
	set current = "", status = 404, json = "", raw = ""
	if 'assignsKey {
		set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", ##class(FlightDeck.Domain.Entity).Path(descriptor.readOperation), keys, "", .status, .json, .raw)
		if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
		if status = 200 {
			set current = $select($isobject(json) && $isobject(json.result):json.result, 1:{})
		} elseif status '= 404 {
			set failure = {"status":(status), "code":($select(status=403:"FORBIDDEN", status=501:"UNAVAILABLE", 1:"UPSTREAM_REJECTED")), "message":(##class(FlightDeck.Admin.Client).ErrorText(json, raw)), "raw":(raw)}
			quit ""
		}
	}
	set kind = $case(descriptor.kind, "upsert":$select($isobject(current):"edit", 1:"create"), :descriptor.kind)
	if (kind '= "create") && '$isobject(current) {
		set failure = {"status":404, "code":"NOT_FOUND", "message":(##class(FlightDeck.Admin.Client).ErrorText(json, raw)), "raw":(raw)}
		quit ""
	}
	set proposed = $select(kind="delete":{}, $isobject(request.proposed):request.proposed, 1:{})
	// Facts about the target, from the entity type (list item facts) and the installer's record.
	set listItem = ##class(FlightDeck.Domain.Entity).ListItemFor(type, keys)
	set basis = $select($isobject(listItem):listItem, $isobject(current):current, 1:{})
	set facts = ##class(FlightDeck.Domain.Facts).For(type.facts, basis)
	// The signed-in user's own account: a change to it takes effect in this session immediately
	// (feature 003 FR-011), so a rule can grade it without any screen deciding that.
	do facts.%Set("selfTarget", (typeId = "permissions/user") && (keys.name = $username), "boolean")
	// The process serving this request. The detail read does not carry the identifier, so it is taken
	// from the key the caller named: the comparison stays exact, which is what lets the block be
	// affirmative rather than a suspicion (feature 004 FR-031, research R15).
	if typeId = "system/process" {
		set session = $select($isobject(current) && current.%IsDefined("CSPSessionID"):current.CSPSessionID, 1:"")
		set own = ##class(FlightDeck.Domain.Facts).OwnSessionId()
		do facts.%Set("isOwnSession", ((session '= "") && (own '= "") && (session = own)) || (keys.id = ##class(FlightDeck.Domain.Facts).OwnProcessId()), "boolean")
	}
	set record = ##class(FlightDeck.Domain.Facts).FlightDeckApplication(keys.name)
	if $isobject(record) {
		do facts.%Set("requiredAuthBits", +record.requiredAuthBits, "number")
		do facts.%Set("runtimeRole", record.runtimeRole)
	}
	set changed = []
	set iter = proposed.%GetIterator()
	while iter.%GetNext(.field, .value) {
		if (kind = "create") || '$isobject(current) || '..Same(current, proposed, field) do changed.%Push(field)
	}
	set ctx = {"operationId":(operationId), "kind":(kind), "keys":(keys), "current":($select($isobject(current):current, 1:{})), "proposed":(proposed), "changedFields":(changed), "facts":(facts)}
	do ctx.%Set("isSystem", ''facts.system || ''facts.isSystem || ''basis.System, "boolean")
	// The process serving this request (feature 004 FR-031): compared exactly, so the block that
	// follows is affirmative rather than a suspicion.
	do ctx.%Set("isOwnSession", ''facts.isOwnSession, "boolean")
	do ctx.%Set("isFlightDeck", ##class(FlightDeck.Domain.Facts).IsFlightDeckApplication(keys.name), "boolean")
	set ctx.fingerprint = ##class(FlightDeck.Mutation.Fingerprint).Of(current, descriptor.secretFields)
	quit ctx
}

/// The object as it would be after the change: the current state with the proposed fields applied.
/// Self-protection and impact rules test this, never the fragment the client sent.
ClassMethod Proposed(ctx As %DynamicObject) As %DynamicObject
{
	set merged = ##class(%DynamicAbstractObject).%FromJSON(ctx.current.%ToJSON())
	set iter = ctx.proposed.%GetIterator()
	while iter.%GetNext(.field, .value) { do ..CopyValue(ctx.proposed, field, merged, field) }
	quit merged
}

/// JSON-equal comparison of one field in two objects.
ClassMethod Same(a As %DynamicObject, b As %DynamicObject, field As %String) As %Boolean
{
	if a.%IsDefined(field) '= b.%IsDefined(field) quit 0
	set va = a.%Get(field), vb = b.%Get(field)
	if $isobject(va) || $isobject(vb) quit $isobject(va) && $isobject(vb) && (##class(FlightDeck.Mutation.Fingerprint).Canonical(va) = ##class(FlightDeck.Mutation.Fingerprint).Canonical(vb))
	if (a.%GetTypeOf(field) = "boolean") || (b.%GetTypeOf(field) = "boolean") quit ''va = ''vb
	if $isvalidnum(va) && $isvalidnum(vb) quit +va = +vb
	quit va = vb
}

/// The PreviewResponse for a context (masked).
ClassMethod Preview(descriptor As %DynamicObject, ctx As %DynamicObject) As %DynamicObject
{
	if ctx.kind = "request" quit ##class(FlightDeck.Mutation.RequestMode).Preview(descriptor, ctx)
	if ctx.kind = "action" quit ##class(FlightDeck.Mutation.Action).Preview(descriptor, ctx)
	set secrets = descriptor.secretFields
	set resolved = ##class(FlightDeck.Mutation.Grade).Resolve(descriptor, ctx, ctx.keys)
	set rows = ..Rows(descriptor, ctx)
	set response = {
		"kind":(ctx.kind), "target":(##class(FlightDeck.Mutation.Grade).Target(descriptor, ctx.keys)),
		"rows":(rows), "grade":(resolved.grade),
		"fingerprint":(ctx.fingerprint)
	}
	do response.%Set("confirmText", resolved.confirmText, $select(resolved.confirmText="":"null", 1:"string"))
	do response.%Set("consequence", resolved.consequence, $select(resolved.consequence="":"null", 1:"string"))
	do response.%Set("noChange", (ctx.kind = "edit") && (ctx.changedFields.%Size() = 0), "boolean")
	set blocked = ..Refusal(descriptor, ctx)
	if blocked = "" { do response.%Set("blocked", "", "null") } else { set response.blocked = {"message":(blocked)} }
	do response.%Set("requestMode", "", "null")
	// A server note about this preview: today, a last-administrator check that could not assert.
	set notice = $select($isobject(ctx.check):##class(FlightDeck.Mutation.LastAdmin).Notice(ctx), 1:"")
	do response.%Set("notice", notice, $select(notice="":"null", 1:"string"))
	set applyNotice = $select(descriptor.%IsDefined("applyNotice"):descriptor.applyNotice, 1:"")
	do response.%Set("applyNotice", applyNotice, $select(applyNotice="":"null", 1:"string"))
	// How long the platform is expected to take. An operation of minutes presented as a synchronous
	// request reads as a frozen application, so the duration is stated before anything is sent
	// (feature 004 spec FR-037b).
	set expected = $select(descriptor.%IsDefined("expectedDuration"):descriptor.expectedDuration, 1:"")
	do response.%Set("expectedDuration", expected, $select(expected="":"null", 1:"string"))
	set response.impact = {"state":"none"}
	if descriptor.%IsDefined("impact") && (ctx.kind '= "create") {
		set when = $select(descriptor.%IsDefined("impactWhen"):descriptor.impactWhen, 1:{"op":"true"})
		if ##class(FlightDeck.Domain.Predicate).Eval(when, ctx) set response.impact = ..Impact(descriptor.impact, ctx.current, ctx)
	}
	quit response
}

/// The impact provider's answer. `ctx` is the whole evaluation context, which action-kind providers
/// need because an action names its target with parameters instead of an object.
ClassMethod Impact(provider As %String, current As %DynamicObject, ctx As %DynamicObject = "") As %DynamicObject
{
	if provider = "webapp-impact" quit ##class(FlightDeck.Domain.Links.WebAppImpact).Impact(current)
	if provider = "role-impact" quit ##class(FlightDeck.Domain.Impact.RoleImpact).Impact(current, ctx)
	if provider = "resource-impact" quit ##class(FlightDeck.Domain.Impact.ResourceImpact).Impact(current, ctx)
	if provider = "sql-privilege-impact" quit ##class(FlightDeck.Domain.Impact.SqlPrivilegeImpact).Impact(current, ctx)
	if provider = "tls-impact" quit ##class(FlightDeck.Domain.Impact.TlsImpact).Impact(current, ctx)
	if provider = "wallet-impact" quit ##class(FlightDeck.Domain.Impact.WalletImpact).Impact(current, ctx)
	if ##class(FlightDeck.Domain.Fixtures).Enabled() quit $classmethod(##class(FlightDeck.Domain.Fixtures).#CATALOG, "Impact", provider, current)
	quit {"state":"undetermined", "summary":"The impact could not be determined.", "reason":("No impact provider "_provider_".")}
}

/// Field-by-field rows in official schema order: every field present in the current or proposed
/// state. Secret rows carry no values (Constitution VI).
ClassMethod Rows(descriptor As %DynamicObject, ctx As %DynamicObject) As %DynamicArray
{
	set rows = [], current = ctx.current, proposed = ctx.proposed
	set names = ##class(FlightDeck.Domain.Schemas).FieldNames(descriptor.schema)
	if ##class(FlightDeck.Domain.Fixtures).Enabled() && (names = "") set names = $classmethod(##class(FlightDeck.Domain.Fixtures).#CATALOG, "FieldNames", descriptor.schema)
	// Fields the official schema does not list still appear, after the schema's fields: nothing the
	// user changes or the API returns is left out of the diff.
	kill extra
	for object = current, proposed {
		set iter = object.%GetIterator()
		while iter.%GetNext(.field) { set:'$listfind(names, field) extra(field) = "" }
	}
	set field = ""
	for { set field = $order(extra(field)) quit:field=""  set names = names _ $listbuild(field) }
	set ptr = 0
	while $listnext(names, ptr, field) {
		continue:'current.%IsDefined(field)&&'proposed.%IsDefined(field)
		set secret = ##class(FlightDeck.Mutation.Mask).IsSecret(descriptor.secretFields, field)
		set row = {"field":(field), "label":(field)}
		if ctx.kind = "delete" {
			set isChanged = 1
		} else {
			set isChanged = ##class(FlightDeck.Domain.Predicate).ArrayHas(ctx.changedFields, field)
		}
		do row.%Set("changed", isChanged, "boolean")
		do row.%Set("secret", secret, "boolean")
		if 'secret {
			if (ctx.kind = "create") || 'current.%IsDefined(field) { do row.%Set("current", "", "null") } else { do ..CopyValue(current, field, row, "current") }
			if ctx.kind = "delete" {
				do row.%Set("commanded", "", "null")
			} elseif proposed.%IsDefined(field) {
				do ..CopyValue(proposed, field, row, "commanded")
			} else {
				do ..CopyValue(current, field, row, "commanded")
			}
		}
		do rows.%Push(row)
	}
	quit rows
}

ClassMethod CopyValue(from As %DynamicObject, field As %String, to As %DynamicObject, name As %String)
{
	set type = from.%GetTypeOf(field)
	if $listfind($listbuild("boolean", "number", "null"), type) {
		do to.%Set(name, from.%Get(field), type)
	} else {
		do to.%Set(name, from.%Get(field))
	}
}

/// preview entry point. Returns the HTTP status and body.
ClassMethod DoPreview(request As %DynamicObject, Output status As %Integer) As %DynamicObject
{
	set ctx = ..Context(request, .descriptor, .failure)
	if $isobject(failure) set status = failure.status quit ..ErrorBody(failure, request, descriptor)
	set status = 200
	set preview = ..Preview(descriptor, ctx)
	// A block is decided here, by the server: the attempt is recorded as Blocked even though the
	// dry run then offers no Apply (spec FR-014, US2 scenario 10). The record is masked like any other.
	if $isobject(preview.blocked) set preview.trail = ..Trail(preview, ctx, "Blocked", 403, preview.blocked.message)
	quit preview
}

/// apply entry point. Returns the HTTP status and body (data-model §3.4).
ClassMethod DoApply(request As %DynamicObject, Output status As %Integer) As %DynamicObject
{
	set ctx = ..Context(request, .descriptor, .failure)
	if $isobject(failure) set status = failure.status quit ..ErrorBody(failure, request, descriptor)
	set preview = ..Preview(descriptor, ctx)
	// Optimistic concurrency: the state re-read now must be the state the user reviewed.
	if ctx.fingerprint '= request.fingerprint {
		set status = 409
		quit {"error":{"code":"STATE_CHANGED", "message":(..#MSGCHANGED), "raw":null}, "preview":(preview)}
	}
	if $isobject(preview.blocked) {
		set status = 403
		set trail = ..Trail(preview, ctx, "Blocked", 403, preview.blocked.message)
		quit {"error":{"code":"SELF_PROTECTION", "message":(preview.blocked.message), "raw":null}, "trail":(trail)}
	}
	if preview.noChange {
		set status = 422
		quit {"error":{"code":"NO_CHANGE", "message":(..#MSGNOCHANGE), "raw":null}}
	}
	set unsatisfied = ##class(FlightDeck.Mutation.Grade).Unsatisfied(preview, request.confirmation, ''request.acknowledged)
	if unsatisfied '= "" {
		set status = 422
		quit {"error":{"code":"CONFIRMATION_REQUIRED", "message":(unsatisfied), "raw":null}, "preview":(preview)}
	}
	if ctx.kind = "request" quit ##class(FlightDeck.Mutation.RequestMode).Apply(descriptor, ctx, preview, .status)
	if ctx.kind = "action" quit ##class(FlightDeck.Mutation.Action).Apply(descriptor, ctx, preview, .status)
	// Send only what changed (edit), the proposed object (create), nothing (delete).
	set method = $piece(request.operationId, " ", 1), path = ##class(FlightDeck.Domain.Entity).Path(request.operationId)
	set body = ""
	if ctx.kind '= "delete" {
		set body = {}
		set iter = ctx.changedFields.%GetIterator()
		while iter.%GetNext(, .field) { do ..CopyValue(ctx.proposed, field, body, field) }
	}
	set sc = ##class(FlightDeck.Domain.Upstream).Call(method, path, ctx.keys, body, .writeStatus, .json, .raw)
	if $$$ISERR(sc) set writeStatus = 500, raw = $system.Status.GetErrorText(sc), json = ""
	if writeStatus >= 300 {
		set message = ##class(FlightDeck.Mutation.Mask).Text(##class(FlightDeck.Admin.Client).ErrorText(json, raw), ctx.proposed, descriptor.secretFields)
		set trail = ..Trail(preview, ctx, "Failed", writeStatus, message)
		set status = 502
		set error = {"code":"UPSTREAM_REJECTED", "message":(message)}
		do error.%Set("raw", ##class(FlightDeck.Mutation.Mask).Text(raw, ctx.proposed, descriptor.secretFields))
		set response = {"error":(error), "trail":(trail)}
		do response.%Set("validation", ..IsValidation(json, writeStatus), "boolean")
		do response.%Set("officialStatus", writeStatus, "number")
		quit response
	}
	do ##class(FlightDeck.Domain.LinkCache).Invalidate()
	set result = {}
	if ctx.kind '= "delete" {
		set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", ##class(FlightDeck.Domain.Entity).Path(descriptor.readOperation), ctx.keys, "", .readStatus, .readJson)
		if (readStatus = 200) && $isobject(readJson) set result = ##class(FlightDeck.Mutation.Mask).Object(readJson.result, descriptor.secretFields)
	}
	set status = 200
	quit {"result":(result), "trail":(..Trail(preview, ctx, "Applied", writeStatus, ""))}
}

/// True when an official rejection is an input validation error (research R2: returned as 500).
ClassMethod IsValidation(json As %DynamicAbstractObject, status As %Integer) As %Boolean
{
	if (status >= 400) && (status < 500) quit 1
	quit:'$isobject(json) 0
	set found = 0
	try {
		set iter = json.status.errors.%GetIterator()
		while iter.%GetNext(, .error) { if $listfind($listfromstring(..#VALIDATIONCODES), +error.code) set found = 1 quit }
	} catch {}
	quit found
}

/// A masked trail record (data-model §3.5). Rows come from the already masked preview.
ClassMethod Trail(preview As %DynamicObject, ctx As %DynamicObject, result As %String, status As %Integer, message As %String) As %DynamicObject
{
	set record = {
		"id":($system.Util.CreateGUID()), "time":($translate($zdatetime($ztimestamp, 3, 1, 3), " ", "T")_"Z"),
		"operationId":(ctx.operationId), "kind":(preview.kind), "target":(preview.target), "rows":(preview.rows),
		"result":(result), "concurrency":(..#CONCURRENCY)
	}
	do record.%Set("status", status, "number")
	do record.%Set("message", message, $select(message="":"null", 1:"string"))
	if $isobject(preview.requestMode) set record.request = preview.requestMode.request
	// The last-administrator check, when one ran: a reader of the trail must be able to tell an
	// affirmative block from a change applied under an incomplete check (feature 003 FR-010c).
	if $isobject(ctx.check) {
		set record.checkMode = ctx.check.mode
		set record.checkResult = ctx.check.result
		if $isobject(ctx.check.unread), ctx.check.unread.%Size() > 0 set record.checkUnread = ctx.check.unread
	}
	quit record
}

ClassMethod ErrorBody(failure As %DynamicObject, request As %DynamicObject, descriptor As %DynamicObject) As %DynamicObject
{
	set error = {"code":(failure.code), "message":(failure.message)}
	set raw = $select(failure.%IsDefined("raw"):failure.raw, 1:"")
	if $isobject(descriptor) set raw = ##class(FlightDeck.Mutation.Mask).Text(raw, request.proposed, descriptor.secretFields)
	do error.%Set("raw", raw, $select(raw="":"null", 1:"string"))
	quit {"error":(error)}
}

}
