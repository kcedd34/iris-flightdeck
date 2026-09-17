/// Task class used only by FlightDeck demonstration tasks. It does nothing, or fails on purpose so
/// the Tasks screens have a failed run to show.
Class FlightDeck.Demo.NoopTask Extends %SYS.Task.Definition
{

Parameter TaskName = "FlightDeck demo no-op";

/// When true, the task reports a failure (expected, for demonstration).
Property Fail As %Boolean [ InitialExpression = 0 ];

Method OnTask() As %Status
{
	if ..Fail {
		quit $$$ERROR($$$GeneralError, "FlightDeck demo task failure (expected)")
	}
	quit $$$OK
}

}
