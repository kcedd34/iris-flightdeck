/// Glareshield vitals (data-model §8, research R8): host CPU and memory from the native provider,
/// IRIS shared memory and disk from the SysAdmin API. Disk is asynchronous: the last known value is
/// returned immediately with pending=true while a refresh runs.
Class FlightDeck.Vitals.Service [ Abstract ]
{

Parameter CAUTION = 75;

Parameter WARNING = 90;

ClassMethod Snapshot() As %DynamicArray
{
	set vitals = []
	set operate = $system.Security.Check("%Admin_Operate", "USE")
	do vitals.%Push(..Native("cpu", "CPU", operate))
	do vitals.%Push(..Native("memory", "Memory", operate))
	do vitals.%Push(..SharedMemory())
	do vitals.%Push(..Disk())
	quit vitals
}

ClassMethod Native(id As %String, label As %String, operate As %Boolean) As %DynamicObject
{
	set vital = ..Base(id, label, "native")
	do vital.%Set("scope", ##class(FlightDeck.Native.HostMetrics).Scope(), "string")
	if 'operate {
		quit ..Unavailable(vital, "Requires Use on %Admin_Operate.", "%Admin_Operate:U")
	}
	if id = "cpu" {
		set sc = ##class(FlightDeck.Native.HostMetrics).CPU(.value, .asOf)
	} else {
		set sc = ##class(FlightDeck.Native.HostMetrics).Memory(.value, .asOf)
	}
	if $$$ISERR(sc) quit ..Unavailable(vital, ##class(FlightDeck.Native.HostMetrics).#UNREADABLE)
	quit ..Value(vital, value, asOf)
}

ClassMethod SharedMemory() As %DynamicObject
{
	set vital = ..Base("shm", "Shared memory", "api")
	set rows = ##class(FlightDeck.Admin.Client).Get("/v2/monitor/system-usage/shared-memory", , .status, .raw)
	if status = 403 quit ..Unavailable(vital, "Requires Use on %Admin_Operate.", "%Admin_Operate:U")
	if (status '= 200) || '$isobject(rows) quit ..Unavailable(vital, ##class(FlightDeck.Admin.Client).ErrorText("", raw))
	set used = 0, allocated = 0
	set iter = rows.%GetIterator()
	while iter.%GetNext(, .row) {
		set used = used + row.SMHUsed
		set allocated = allocated + row.SMHAllocated
	}
	if allocated <= 0 quit ..Unavailable(vital, "Shared memory usage was not reported.")
	quit ..Value(vital, 100 * used / allocated, ..Now())
}

/// Fullest mounted local database: used / capacity, capacity = MaxSize when > 0, else
/// Size + DiskFree (verification/README.md, probe 4).
/// <p>Where the instance has no database-dir operations (v1 dialect), the native provider fills the
/// gap with the same figures (Constitution I v2.1.0).
ClassMethod Disk() As %DynamicObject
{
	if '##class(FlightDeck.Admin.Client).Has("GET /v2/database-dirs") || '##class(FlightDeck.Admin.Client).Has("POST /v2/database-dir/info") {
		quit ..NativeDisk()
	}
	set vital = ..Base("disk", "Disk", "api")
	set haveSession = ($data(%session)#2) && $isobject($get(%session))
	set last = $select(haveSession:$get(%session.Data("fd.vitals.disk")), 1:"")
	set tasks = $select(haveSession:$get(%session.Data("fd.vitals.disk.tasks")), 1:"")

	// Collect a finished refresh, if one is running.
	if tasks '= "" {
		set result = ..CollectDisk(tasks, .done, .error, .fullest)
		if error = 403 {
			if haveSession kill %session.Data("fd.vitals.disk.tasks")
			quit ..Unavailable(vital, "The SysAdmin API refused the database metrics for this user.")
		}
		if done {
			if haveSession {
				kill %session.Data("fd.vitals.disk.tasks")
				if result '= "" set %session.Data("fd.vitals.disk") = $listbuild(result, ..Now(), fullest)
			}
			if result '= "" set last = $listbuild(result, ..Now(), fullest)
			set tasks = ""
		}
	}
	// Start a refresh when none is running and the value is older than 30 s.
	set stale = (last = "") || ($system.SQL.Functions.DATEDIFF("s", $translate($extract($list(last, 2), 1, 19), "T", " "), $zdatetime($ztimestamp, 3)) >= 30)
	if (tasks = "") && stale {
		set started = ..StartDisk(.error)
		// The API refuses /v2/database-dirs to some users who hold a declared privilege
		// (verification/README.md): report the refusal itself, not a requirement the user already meets.
		if error = 403 quit ..Unavailable(vital, "The SysAdmin API refused the database list for this user.")
		if haveSession, started '= "" set %session.Data("fd.vitals.disk.tasks") = started
		set tasks = started
		// The API usually finishes within tens of milliseconds (probe 4): try once right away.
		if started '= "" {
			hang 0.1
			set result = ..CollectDisk(started, .done, .error, .fullest)
			if done {
				if haveSession kill %session.Data("fd.vitals.disk.tasks")
				if result '= "" {
					set last = $listbuild(result, ..Now(), fullest)
					if haveSession set %session.Data("fd.vitals.disk") = last
				}
				set tasks = ""
			}
		}
	}
	if last = "" {
		if tasks '= "" {
			do vital.%Set("pending", 1, "boolean")
			quit vital
		}
		quit ..Unavailable(vital, "Database metrics were not reported.")
	}
	set vital = ..Value(vital, $list(last, 1), $list(last, 2))
	do vital.%Set("pending", tasks '= "", "boolean")
	// Which database that percentage belongs to. The instrument shows it under the number, as
	// docs/design.md §5 does ("IRISAPP 72%"); a percentage with no owner says less than it seems.
	set directory = $listget(last, 3)
	do:directory'="" vital.%Set("detail", ..DatabaseName(directory) _ " " _ $normalize($list(last, 1), 0) _ "%", "string")
	quit vital
}

/// The database name a directory belongs to, or the directory itself when the instance does not name
/// one. Nothing is invented: an unnamed directory is shown as the directory.
ClassMethod DatabaseName(directory As %String) As %String
{
	set name = $piece($zstrip(directory, ">", "/"), "/", *)
	quit $select(name="":directory, 1:$zconvert(name, "U"))
}

/// Native disk vital: same privilege as POST /v2/database-dir/info, synchronous (no async task).
ClassMethod NativeDisk() As %DynamicObject
{
	set vital = ..Base("disk", "Disk", "native")
	set operation = "POST /v2/database-dir/info"
	if '##class(FlightDeck.Capability.Map).CurrentUserMay(operation) {
		set requires = ##class(FlightDeck.Capability.Map).Requires(operation)
		set text = ""
		for i=0:1:requires.%Size()-1 { set text = text _ $select(i:" or ", 1:"") _ requires.%Get(i) }
		quit ..Unavailable(vital, ##class(FlightDeck.API.Response).RequiresMessage(requires), text)
	}
	set sc = ##class(FlightDeck.Native.Databases).MaxPercentUsed(.value, .asOf)
	if $$$ISERR(sc) quit ..Unavailable(vital, ##class(FlightDeck.Native.Databases).#UNREADABLE)
	quit ..Value(vital, value, asOf)
}

/// Starts one database-dir/info task per mounted local database. Returns a $list of task ids.
ClassMethod StartDisk(Output error As %Integer) As %List
{
	set error = "", ids = ""
	set dirs = ##class(FlightDeck.Admin.Client).Get("/v2/database-dirs", {"maxRows":200}, .status, .raw)
	if status '= 200 set error = status quit ""
	set iter = dirs.%GetIterator()
	while iter.%GetNext(, .dir) {
		continue:dir.Status'["Mounted"
		set sc = ##class(FlightDeck.Admin.Client).Call("POST", "/v2/database-dir/info", {"dir":(dir.Directory)}, , .st, .json, .raw, .headers)
		if st = 403 set error = 403 quit
		continue:st'=202
		// The handle arrives in a header that names /v1 even on v2; only the dialect layer reads it
		// (feature 004 research R6). The directory travels with it so the fullest database can be
		// named on the instrument, as docs/design.md §5 shows it.
		set id = ##class(FlightDeck.Admin.Client).AsyncHandle(.headers, json)
		set:id'="" ids = ids _ $listbuild(id _ "|" _ dir.Directory)
	}
	quit ids
}

/// Returns the max percent used when every task has a result; done=0 while any is still running.
ClassMethod CollectDisk(tasks As %List, Output done As %Boolean, Output error As %Integer, Output fullest As %String) As %Numeric
{
	set done = 1, error = "", max = "", fullest = ""
	set ptr = 0
	while $listnext(tasks, ptr, entry) {
		set id = $piece(entry, "|", 1), directory = $piece(entry, "|", 2, *)
		set sc = ##class(FlightDeck.Admin.Client).Call("GET", "/v2/async-result", {"id":(id)}, , .status, .json, .raw)
		if status = 403 set error = 403 quit
		if (status '= 200) || '$isobject(json) continue
		set metrics = json.result.Result
		if '$isobject(metrics) || (metrics.Size = "") {
			set done = 0
			continue
		}
		set used = metrics.Size - metrics.AvailableSpace
		set capacity = $select(+metrics.MaxSize>0:+metrics.MaxSize, 1:metrics.Size + ..ToMB(metrics.DiskFree))
		continue:capacity<=0
		set percent = 100 * used / capacity
		if (max = "") || (percent > max) {
			set max = percent, fullest = directory
		}
	}
	quit max
}

ClassMethod ToMB(value As %String) As %Numeric
{
	set number = +value
	set unit = $zconvert($zstrip(value, "*N", "."), "U")
	quit $case(unit, "TB":number*1024*1024, "GB":number*1024, "MB":number, "KB":number/1024, :number)
}

ClassMethod Base(id As %String, label As %String, source As %String) As %DynamicObject
{
	set vital = {"id":(id), "label":(label), "source":(source), "state":"ok"}
	do vital.%Set("scope", "", "null")
	do vital.%Set("value", "", "null")
	do vital.%Set("asOf", "", "null")
	do vital.%Set("pending", 0, "boolean")
	do vital.%Set("reason", "", "null")
	do vital.%Set("requires", "", "null")
	quit vital
}

ClassMethod Value(vital As %DynamicObject, value As %Numeric, asOf As %String) As %DynamicObject
{
	set value = $normalize(value, 1)
	do vital.%Set("value", value, "number")
	do vital.%Set("asOf", asOf, "string")
	set vital.state = $select(value>=..#WARNING:"warning", value>=..#CAUTION:"caution", 1:"ok")
	quit vital
}

ClassMethod Unavailable(vital As %DynamicObject, reason As %String, requires As %String = "") As %DynamicObject
{
	set vital.state = "unavailable"
	do vital.%Set("value", "", "null")
	do vital.%Set("reason", reason, "string")
	if requires '= "" do vital.%Set("requires", requires, "string")
	quit vital
}

ClassMethod Now() As %String
{
	quit $translate($zdatetime($ztimestamp, 3, 1, 3), " ", "T") _ "Z"
}

}
