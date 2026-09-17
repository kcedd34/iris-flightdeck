/// Server-side self-protection (Constitution VII, RN-FD-12, feature 002 research R7). Evaluated from
/// the descriptor's rules against the state re-read before writing; a match blocks the operation
/// with docs/prd.md §9 message 4, whatever the client sent.
Class FlightDeck.Mutation.SelfProtection [ Abstract ]
{

/// §9 message 4.
Parameter MESSAGE = "This web application serves FlightDeck. Disabling it would lock you out.";

/// Returns the block message, or "" when no rule matches.
ClassMethod Evaluate(descriptor As %DynamicObject, ctx As %DynamicObject) As %String
{
	quit:'descriptor.%IsDefined("selfProtection") ""
	set iter = descriptor.selfProtection.%GetIterator(), message = ""
	while iter.%GetNext(, .rule) {
		if ##class(FlightDeck.Domain.Predicate).Eval(rule.when, ctx) {
			set message = $select(rule.%IsDefined("message"):rule.message, 1:..#MESSAGE)
			quit
		}
	}
	quit message
}

}
