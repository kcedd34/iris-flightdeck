/// FlightDeck code never sets $ROLES to a non-empty value (feature 002 T062, spike T-EXEC-1 finding
/// 2): for an ordinary user it raises <PROTECT>, and for a user with IRISSYS write it can add any
/// role, up to %All. The only allowed form is clearing to login roles, SET $ROLES = "".
/// Test classes are excluded: they reproduce FlightDeck requests on purpose.
Class FlightDeck.Test.NoRolesAssignment Extends %UnitTest.TestCase
{

Method TestNoNonEmptyRolesAssignment()
{
	set offenders = "", scanned = 0
	set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT parent, Name FROM %Dictionary.MethodDefinition WHERE parent %STARTSWITH 'FlightDeck.' AND NOT parent %STARTSWITH 'FlightDeck.Test.'")
	while rs.%Next() {
		set method = ##class(%Dictionary.MethodDefinition).%OpenId(rs.parent_"||"_rs.Name)
		continue:'$isobject(method)
		set scanned = scanned + 1
		set code = $zconvert(method.Implementation.Read(1000000), "L")
		set start = 1
		for {
			set start = $find(code, "$roles", start)
			quit:start=0
			set rest = $zstrip($extract(code, start, start + 20), "<W")
			continue:$extract(rest)'="="
			set value = $zstrip($extract(rest, 2, *), "<W")
			if $extract(value, 1, 2) '= """""" set offenders = offenders _ " " _ rs.parent _ ":" _ rs.Name
		}
	}
	do $$$AssertTrue(scanned > 100, scanned_" FlightDeck methods scanned")
	do $$$AssertEquals(offenders, "", "non-empty $ROLES assignment in"_offenders)
}

}
