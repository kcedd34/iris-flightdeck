/// Native provider for database disk usage, used only where the instance's SysAdmin API has no
/// database-dir operations (the v1 dialect, IRIS 2026.1). Constitution I v2.1.0 native gap
/// "Disk usage per database, v1 dialect only"; on v2, GET /v2/database-dirs and
/// POST /v2/database-dir/info stay in use.
/// <p>The figures are the ones database-dir/info reports, read from the same sources:
/// Size, MaxSize (MB), AvailableSpace (MB free inside the database) and DiskFree (MB on the volume).
/// Verified equal to the API's values on IRIS 2026.2 (verification/v1-native-gaps-2026.1.md).
/// <p>Callers must check <method>FlightDeck.Capability.Map.CurrentUserMay</method> for
/// "POST /v2/database-dir/info" first: the provider requires what the official operation declares.
Class FlightDeck.Native.Databases [ Abstract ]
{

Parameter UNREADABLE = "Database metrics are not readable for this user.";

/// One row per mounted local database: Name, Directory, Size, AvailableSpace, MaxSize, DiskFree
/// (all MB) and PercentUsed. Remote and dismounted databases are skipped, like the API vital.
ClassMethod Usage(Output rows As %DynamicArray) As %Status
{
	set rows = [], sc = $$$OK
	try {
		new $namespace
		set $namespace = "%SYS"
		set seen = ""
		set list = ##class(%ResultSet).%New("Config.Databases:List")
		set sc = list.Execute("*")
		quit:$$$ISERR(sc)
		while list.Next() {
			continue:list.Get("Server")'=""
			set dir = list.Get("Directory")
			continue:(dir="")||$data(seen(dir))
			set seen(dir) = ""
			set db = ##class(SYS.Database).%OpenId(dir, , .openSc)
			continue:'$isobject(db)
			continue:'db.Mounted
			set free = "", diskFree = ""
			continue:$$$ISERR(##class(SYS.Database).GetFreeSpace(dir, .free))
			continue:$$$ISERR(##class(%File).GetDirectorySpace(dir, .diskFree, .diskTotal, 1))
			set row = {"Name":(list.Get("Name")), "Directory":(dir)}
			do row.%Set("Size", +db.Size, "number")
			do row.%Set("AvailableSpace", +free, "number")
			do row.%Set("MaxSize", +db.MaxSize, "number")
			do row.%Set("DiskFree", +diskFree, "number")
			do row.%Set("PercentUsed", ..PercentUsed(+db.Size, +free, +db.MaxSize, +diskFree), "number")
			do rows.%Push(row)
		}
	} catch ex {
		// A user who cannot read IRISSYS gets <PROTECT>: report it, never break the caller.
		set sc = ex.AsStatus()
	}
	quit sc
}

/// used / capacity, capacity = MaxSize when > 0, else Size + DiskFree (same rule as the API vital).
ClassMethod PercentUsed(size As %Numeric, available As %Numeric, maxSize As %Numeric, diskFree As %Numeric) As %Numeric
{
	set used = size - available
	set capacity = $select(maxSize>0:maxSize, 1:size + diskFree)
	quit $select(capacity>0:100 * used / capacity, 1:0)
}

/// Fullest mounted local database, in percent.
ClassMethod MaxPercentUsed(Output percent As %Numeric, Output asOf As %String) As %Status
{
	set percent = "", asOf = ""
	set sc = ..Usage(.rows)
	quit:$$$ISERR(sc) sc
	set iter = rows.%GetIterator()
	while iter.%GetNext(, .row) {
		set:(percent="")||(row.PercentUsed>percent) percent = row.PercentUsed
	}
	if percent = "" quit $$$ERROR($$$GeneralError, "No mounted local database was found.")
	set asOf = $translate($zdatetime($ztimestamp, 3, 1, 3), " ", "T") _ "Z"
	quit $$$OK
}

/// Installer bootstrap only (plan Complexity Tracking): the resource protecting the routine
/// database of a namespace, where the instance has no namespace/database operations (v1 dialect).
ClassMethod CodeDatabaseResource(namespace As %String, Output resource As %String, Output database As %String) As %Status
{
	set resource = "", database = "", sc = $$$OK
	try {
		new $namespace
		set $namespace = "%SYS"
		set sc = ##class(Config.Namespaces).Get(namespace, .ns)
		quit:$$$ISERR(sc)
		set database = $get(ns("Routines"))
		set sc = ##class(Config.Databases).Get(database, .props)
		quit:$$$ISERR(sc)
		set db = ##class(SYS.Database).%OpenId($get(props("Directory")), , .sc)
		quit:'$isobject(db)
		set resource = db.ResourceName
	} catch ex {
		set sc = ex.AsStatus()
	}
	quit sc
}

}
