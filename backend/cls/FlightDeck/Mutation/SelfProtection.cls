/// Server-side self-protection (Constitution VII, RN-FD-12, feature 002 research R7). Evaluated from
/// the descriptor's rules against the state re-read before writing; a match blocks the operation
/// with docs/prd.md §9 message 4, whatever the client sent.
Class FlightDeck.Mutation.SelfProtection [ Abstract ]
{

/// §9 message 4.
Parameter MESSAGE = "This web application serves FlightDeck. Disabling it would lock you out.";

/// Feature 004 (RN-FD-12, spec FR-031). Terminating the process that serves this session would stop
/// the portal mid-request: the administrator would see a page that stopped answering, which reads as
/// a crash rather than as a choice. The comparison is exact, so the block is affirmative.
Parameter MSGOWNSESSION = "This is the process running your own session. Terminating it would end your session mid-request, and FlightDeck would stop answering. Terminate it from another session if you mean to.";

/// Feature 004 (spec FR-007). A system task belongs to the platform; suspending it is offered,
/// deleting it is not.
Parameter MSGSYSTEMTASK = "This is a system task. FlightDeck suspends and resumes system tasks but does not delete them: the platform recreates or depends on them.";

/// Returns the block message, or "" when no rule matches.
ClassMethod Evaluate(descriptor As %DynamicObject, ctx As %DynamicObject) As %String
{
	quit:'descriptor.%IsDefined("selfProtection") ""
	set iter = descriptor.selfProtection.%GetIterator(), message = ""
	while iter.%GetNext(, .rule) {
		if ##class(FlightDeck.Domain.Predicate).Eval(rule.when, ctx) {
			set message = $select(rule.%IsDefined("message"):rule.message, 1:..#MESSAGE)
			// A rule may name a message the evaluator composes, because only it knows what it counted.
			if message = "last-administrator" set message = ##class(FlightDeck.Mutation.LastAdmin).Message(ctx)
			if message = "own-session" set message = ..#MSGOWNSESSION
			if message = "system-task" set message = ..#MSGSYSTEMTASK
			quit
		}
	}
	quit message
}

}
