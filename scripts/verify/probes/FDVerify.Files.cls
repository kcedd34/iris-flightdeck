/// Day-1 probe 7. Temporary: loaded, run and deleted by scripts/verify/verify_platform.py.
/// Reports where log sources live and whether the interoperability event log is queryable.
Class FDVerify.Files [ Abstract ]
{

ClassMethod Report()
{
	set out = {}
	set mgr = $system.Util.ManagerDirectory()
	set msg = ##class(%File).NormalizeFilename("messages.log", mgr)
	set out.messagesLog = {"path":(msg), "exists":(##class(%File).Exists(msg)), "lastLine":""}
	if out.messagesLog.exists {
		set f = ##class(%Stream.FileCharacter).%New()
		do f.LinkToFile(msg)
		set last = ""
		while 'f.AtEnd { set line = f.ReadLine() set:line'="" last = line }
		set out.messagesLog.lastLine = last
	}
	set alerts = ##class(%File).NormalizeFilename("alerts.log", mgr)
	set out.alerts = {"path":(alerts), "exists":(##class(%File).Exists(alerts))}
	set interop = {"queryClassExists":0, "namespacesWithInterop":[]}
	set ns = ""
	set rs = ##class(%ResultSet).%New("%SYS.Namespace:List")
	if $$$ISOK(rs.Execute()) {
		while rs.Next() {
			set name = rs.Get("Nsp")
			try {
				if ##class(%Library.EnsembleMgr).IsEnsembleNamespace(name) {
					do interop.namespacesWithInterop.%Push(name)
					new $namespace
					set $namespace = name
					if ##class(%Dictionary.CompiledClass).%ExistsId("Ens.Util.Log") set interop.queryClassExists = 1
				}
			} catch {}
		}
	}
	set out.interop = interop
	write "FDVERIFY-JSON:", out.%ToJSON(), !
}

}
