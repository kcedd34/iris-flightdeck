/// Which SysAdmin API dialect the instance exposes: "v2" (IRIS 2026.2+), "v1" (IRIS 2026.1), "none",
/// or "unknown" when the caller cannot read %SYS and v2 is absent (such a caller holds no
/// administrative privilege). Selected once per IRIS session (once per process outside a web
/// request) and read only by FlightDeck.Admin.Client. Constitution I, dialect note.
Class FlightDeck.Admin.Dialect [ Abstract ]
{

ClassMethod Current() As %String
{
	if $data(%session)#2, $isobject(%session) {
		set dialect = $get(%session.Data("fd.api.dialect"))
		if dialect = "" {
			set dialect = ..Detect()
			if dialect '= "unknown" set %session.Data("fd.api.dialect") = dialect
		}
		quit dialect
	}
	if $get(^||FlightDeck.Dialect) '= "" quit ^||FlightDeck.Dialect
	set dialect = ..Detect()
	if dialect '= "unknown" set ^||FlightDeck.Dialect = dialect
	quit dialect
}

/// The dispatcher class the instance ships for a dialect.
ClassMethod Dispatcher(dialect As %String) As %String
{
	quit $case(dialect, "v2":"%Api.Admin", "v1":"Api.Admin", :"")
}

/// Reads apiVersion from the instance's own /info. When /info cannot be read (for example a user
/// without any %Admin privilege), falls back to which versioned dispatcher the instance ships.
/// The v2 dispatcher is a percent class, visible from any namespace; the v1 dispatcher lives only
/// in %SYS, which a caller without privileges cannot read.
ClassMethod Detect() As %String
{
	set version = ""
	for candidate = "%Api.Admin", "Api.Admin" {
		continue:..ClassExistsInSys(candidate)'=1
		set sc = ##class(FlightDeck.Admin.Client).Dispatch(candidate, "/info", "GET", "", "", .status, .json)
		if $$$ISOK(sc), status = 200, $isobject(json) {
			set version = +json.result.apiVersion
			quit
		}
	}
	if version >= 2 quit "v2"
	if version = 1 quit "v1"
	if ##class(%Dictionary.CompiledClass).%ExistsId("%Api.Admin.Dispatch.v2") quit "v2"
	set v1 = ..ClassExistsInSys("Api.Admin.v1.Dispatch")
	quit $case(v1, 1:"v1", -1:"unknown", :"none")
}

/// 1 when the class exists in %SYS, 0 when it does not, -1 when %SYS cannot be read.
/// Api.Admin (v1) is not a percent class, so it is visible only in %SYS.
ClassMethod ClassExistsInSys(name As %String) As %Integer
{
	new $namespace
	try {
		set $namespace = "%SYS"
		set exists = ##class(%Dictionary.CompiledClass).%ExistsId(name)
	} catch ex {
		set exists = $select(ex.Name="<PROTECT>":-1, 1:0)
	}
	quit exists
}

/// Clears the cached selection (tests, and the session after sign-out).
ClassMethod Reset()
{
	if $data(%session)#2, $isobject(%session) kill %session.Data("fd.api.dialect")
	kill ^||FlightDeck.Dialect
}

}
