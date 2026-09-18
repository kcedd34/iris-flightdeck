/// Composed list reads (feature 004 data-model §3).
/// <p>A list is composed when one official operation does not answer what the screen must show. The
/// composition is declared by the entity type ("compose"), performed once for the whole list, and
/// never assembled by a screen.
Class FlightDeck.Domain.Compose [ Abstract ]
{

/// Enriches the list in place. Returns 1 when something was composed, and sets <var>note</var> when
/// a part could not be read, so the screen can say what is missing instead of showing an absence.
ClassMethod Apply(type As %DynamicObject, items As %DynamicArray, Output note As %String) As %Boolean
{
	set note = ""
	quit:'type.%IsDefined("compose") 0
	if type.compose = "task-history" quit ..TaskHistory(items, .note)
	quit 0
}

/// Enriches one object, for the detail read. The inspector must see what the list saw: a task's
/// runs are what make a failed run's message and the jump to its logs possible (feature 004 FR-004).
ClassMethod ApplyOne(type As %DynamicObject, object As %DynamicObject, keys As %DynamicObject = "") As %Boolean
{
	quit:'type.%IsDefined("compose") 0
	quit:'$isobject(object) 0
	if type.compose = "task-history" {
		// The official detail read does not return the task's own id, so the key the caller asked
		// with is what identifies it. Reading it from the object would silently join nothing.
		set id = $select(object.%IsDefined("Id") && (object.Id '= ""):object.Id, $isobject(keys):keys.%Get("id"), 1:"")
		quit:id="" 0
		set bands = ##class(FlightDeck.Tasks.History).Bands(.complete)
		if complete do object.%Set("FDHistory", ##class(FlightDeck.Tasks.History).Band(bands, id))
		// What the platform knows about this task beyond its definition: the id it runs under, and
		// whether it is running right now. Absent on a version that does not offer it, and the
		// screen then simply has less to show, which is stated rather than filled in.
		if ##class(FlightDeck.Admin.Client).Has("GET /v2/task/info") {
			set info = ##class(FlightDeck.Admin.Client).Get("/v2/task/info", {"id":(id)}, .infoStatus)
			if (infoStatus = 200) && $isobject(info) do object.%Set("FDInfo", info)
		}
		quit complete
	}
	quit 0
}

/// Joins the recent run history onto each task, from one read of the instance's history.
ClassMethod TaskHistory(items As %DynamicArray, Output note As %String) As %Boolean
{
	set bands = ##class(FlightDeck.Tasks.History).Bands(.complete, .reason)
	if 'complete {
		set note = "The run history could not be read, so no task shows one: " _ reason
		quit 0
	}
	set iter = items.%GetIterator()
	while iter.%GetNext(, .item) {
		continue:'$isobject(item)
		do item.%Set("FDHistory", ##class(FlightDeck.Tasks.History).Band(bands, item.Id))
	}
	quit 1
}

}
