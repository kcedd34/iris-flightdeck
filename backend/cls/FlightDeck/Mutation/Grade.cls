/// Confirmation grade resolution (RN-FD-04, feature 002 research R5). The grade is decided by the
/// operation and the proposed change, from the descriptor's ordered rules; first match wins,
/// default simple. Resolved in preview and again in apply against re-read state.
Class FlightDeck.Mutation.Grade [ Abstract ]
{

/// Returns {"grade", "confirmText", "consequence"}.
ClassMethod Resolve(descriptor As %DynamicObject, ctx As %DynamicObject, keys As %DynamicObject) As %DynamicObject
{
	set grade = "simple", consequence = ""
	if descriptor.%IsDefined("grade") {
		set iter = descriptor.grade.%GetIterator()
		while iter.%GetNext(, .rule) {
			if ##class(FlightDeck.Domain.Predicate).Eval(rule.when, ctx) {
				set grade = rule.grade
				set consequence = $select(rule.%IsDefined("consequence"):rule.consequence, 1:"")
				quit
			}
		}
	}
	set out = {"grade":(grade)}
	do out.%Set("confirmText", $select(grade="simple":"", 1:..Target(descriptor, keys, ctx)), $select(grade="simple":"null", 1:"string"))
	do out.%Set("consequence", consequence, $select(consequence="":"null", 1:"string"))
	quit out
}

/// The descriptor's target template filled from keys (and, in request mode, the request).
ClassMethod Target(descriptor As %DynamicObject, keys As %DynamicObject, ctx As %DynamicObject = "") As %String
{
	set text = descriptor.target
	if $isobject(keys) {
		set iter = keys.%GetIterator()
		while iter.%GetNext(.param, .value) { set text = $replace(text, "{"_param_"}", value) }
	}
	if $isobject(ctx) && $isobject(ctx.request) set text = $replace(text, "{path}", ctx.request.path)
	quit text
}

/// Checks the typed confirmation against the grade. Returns "" when satisfied, else the reason.
ClassMethod Unsatisfied(resolved As %DynamicObject, confirmation As %String, acknowledged As %Boolean) As %String
{
	if resolved.grade = "simple" quit ""
	if confirmation '= resolved.confirmText quit "Type "_resolved.confirmText_" exactly to confirm."
	if (resolved.grade = "maximum") && 'acknowledged quit "Acknowledge the consequence to confirm."
	quit ""
}

}
