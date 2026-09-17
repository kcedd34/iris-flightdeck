/// Live verification of the 28 SysAdmin API v1 translations (scripts/build/v1-translations.json).
/// Each test calls the v2 operation through FlightDeck.Admin.Client, which translates it on the v1
/// dialect, and verifies the EFFECT from a source outside the SysAdmin API whenever one exists
/// (SQL security, %SYS.Task, %SYS.TaskSuper, %SYS.ProcessQuery, %Wallet.Collection,
/// $SYSTEM.Encryption, $system.external, OAuth2.Server.AccessToken). HTTP 200 alone never passes a test.
/// <p>Runs only on an instance whose dialect is v1 (IRIS 2026.1); on v2 every test logs a skip.
/// Test tooling may read platform classes to verify effects; the portal itself may not.
Class FlightDeck.Test.V1Translations Extends %UnitTest.TestCase
{

Parameter GRANTEE = "fdt_grantee";

Parameter TABLE = "FDTest.Orders";

Property IsV1 As %Boolean;

Method OnBeforeAllTests() As %Status
{
	do ##class(FlightDeck.Admin.Dialect).Reset()
	set ..IsV1 = (##class(FlightDeck.Admin.Dialect).Current() = "v1")
	quit:'..IsV1 $$$OK
	do ##class(%SQL.Statement).%ExecDirect(, "DROP TABLE IF EXISTS FDTest.Orders")
	set rs = ##class(%SQL.Statement).%ExecDirect(, "CREATE TABLE FDTest.Orders (ID INT PRIMARY KEY, Amount NUMERIC(10,2), Note VARCHAR(50))")
	if rs.%SQLCODE < 0 quit $$$ERROR($$$GeneralError, "fixture table: "_rs.%Message)
	do ..Api("DELETE", "/v2/security/user", {"name":(..#GRANTEE)})
	set st = ..Api("POST", "/v2/security/user", {"name":(..#GRANTEE)}, {"Password":"Fdt-Grantee-2026", "User":{"Enabled":true, "ChangePassword":false, "Roles":[]}})
	if st '= 201 quit $$$ERROR($$$GeneralError, "fixture user: HTTP "_st)
	quit $$$OK
}

Method OnAfterAllTests() As %Status
{
	quit:'..IsV1 $$$OK
	do ..Api("DELETE", "/v2/security/user", {"name":(..#GRANTEE)})
	do ##class(%SQL.Statement).%ExecDirect(, "DROP TABLE IF EXISTS FDTest.Orders")
	quit $$$OK
}

/// Calls a v2 operation through the adapter. Returns the HTTP status.
Method Api(method As %String, path As %String, query As %DynamicObject = "", body As %DynamicAbstractObject = "", Output json As %DynamicAbstractObject, Output raw As %String, Output headers As %String) As %Integer
{
	set sc = ##class(FlightDeck.Admin.Client).Call(method, path, query, body, .status, .json, .raw, .headers)
	if $$$ISERR(sc) set raw = $system.Status.GetErrorText(sc), status = 500
	quit status
}

Method Skip() As %Boolean
{
	if '..IsV1 do $$$LogMessage("skipped: instance dialect is not v1")
	quit '..IsV1
}

Method Evidence(text As %String)
{
	do $$$LogMessage("effect: "_text)
}

// ---- general ---------------------------------------------------------------------------------

Method TestInfo()
{
	quit:..Skip()
	do $$$AssertEquals(..Api("GET", "/info", , , .json), 200)
	do $$$AssertEquals(json.result.apiVersion, 1, "v1 dispatcher answered")
	do $$$AssertEquals(json.result.username, $username, "identity is the calling user")
	do ..Evidence("apiVersion=1, username="_json.result.username_" equals $username")
}

// ---- wallet ----------------------------------------------------------------------------------

Method TestWalletCollectionPutGetListDelete()
{
	quit:..Skip()
	set name = "FDT_Vault"
	do ..Api("DELETE", "/v2/wallet/collection", {"name":(name)})
	set st = ..Api("PUT", "/v2/wallet/collection", {"name":(name)}, {"UseResource":"%DB_USER", "EditResource":"%DB_USER"}, , .raw)
	do $$$AssertTrue(st < 300, "PUT collection: "_st_" "_raw)
	set exists = ##class(%Wallet.Collection).Exists(name, .obj)
	do $$$AssertTrue(exists, "PUT /v2/wallet/collection created it (%Wallet.Collection.Exists)")
	do ..Evidence("PUT: %Wallet.Collection.Exists("_name_")="_exists_", UseResource="_$select($isobject($get(obj)):obj.UseResource, 1:"?"))

	do $$$AssertEquals(..Api("GET", "/v2/wallet/collection", {"name":(name)}, , .json), 200)
	do $$$AssertEquals(json.result.UseResource, obj.UseResource, "GET /v2/wallet/collection returns the stored UseResource")
	do ..Evidence("GET: UseResource "_json.result.UseResource_" equals stored "_obj.UseResource)

	do $$$AssertEquals(..Api("GET", "/v2/wallet/collections", , , .json), 200)
	set found = 0
	set iter = json.result.%GetIterator()
	while iter.%GetNext(, .item) { set:(item.Name=name) found = 1 }
	do $$$AssertTrue(found, "GET /v2/wallet/collections lists the stored collection")
	do ..Evidence("LIST: "_name_" present in list of "_json.result.%Size())

	set st = ..Api("DELETE", "/v2/wallet/collection", {"name":(name)}, , , .raw)
	do $$$AssertTrue(st < 300, "DELETE collection: "_st_" "_raw)
	do $$$AssertNotTrue(##class(%Wallet.Collection).Exists(name), "DELETE /v2/wallet/collection removed it")
	do ..Evidence("DELETE: %Wallet.Collection.Exists("_name_")=0")
}

// ---- encryption ------------------------------------------------------------------------------

Method TestDataElementKeys()
{
	quit:..Skip()
	set file = ##class(%File).TempFilename("key")
	do ##class(%File).Delete(file)
	set st = ..Api("POST", "/v2/security/encryption/file", , {"File":(file), "AdminName":"fdtkeyadmin", "AdminPassword":"Fdt-Key-2026", "KeyLen":256, "Description":"FlightDeck adapter test"}, , .raw)
	do $$$AssertTrue(st < 300, "fixture key file: "_st_" "_raw)
	set nativeBefore = $SYSTEM.Encryption.ListEncryptionKeys()
	set st = ..Api("POST", "/v2/security/encryption/file/activate", {"file":(file)}, {"Action":"ActivateMK", "AdminName":"fdtkeyadmin", "AdminPassword":"Fdt-Key-2026"}, , .raw)
	do $$$AssertTrue(st < 300, "fixture activate: "_st_" "_raw)
	set native = $SYSTEM.Encryption.ListEncryptionKeys()
	set newKey = ""
	for i=1:1:$length(native, ",") { set k = $piece(native, ",", i) if (k '= "") && ((","_nativeBefore_",") '[ (","_k_",")) set newKey = k }
	do $$$AssertTrue(newKey '= "", "control: activation added a key to $SYSTEM.Encryption.ListEncryptionKeys()")
	do $$$AssertEquals(..Api("GET", "/v2/security/encryption/data-element-keys", , , .json, .raw), 200, raw)
	do $$$AssertTrue(json.result.%Size() > 0, "at least the activated key is listed")
	set allNative = 1
	set iter = json.result.%GetIterator()
	set listedNew = 0
	while iter.%GetNext(, .key) { set:(native'[key.Id) allNative = 0  set:(key.Id=newKey) listedNew = 1 }
	do $$$AssertTrue(listedNew, "the key activated by this test ("_newKey_") is listed")
	do $$$AssertTrue(allNative, "every listed key id is activated per $SYSTEM.Encryption.ListEncryptionKeys()")
	do ..Evidence("listed "_json.result.%Size()_" key(s) including newly activated "_newKey_"; all present in $SYSTEM.Encryption.ListEncryptionKeys()")
	if newKey '= "" do ..DeactivateKey(newKey)
	do ##class(%File).Delete(file)
}

Method DeactivateKey(keyId As %String)
{
	new $namespace
	set $namespace = "%SYS"
	do $SYSTEM.Encryption.DeactivateEncryptionKey(keyId)
}

// ---- SQL privileges --------------------------------------------------------------------------

Method TestSqlPrivilegeGrantAndRevoke()
{
	quit:..Skip()
	set q = {"namespace":($namespace), "grantee":(..#GRANTEE), "type":"TABLE", "object":(..#TABLE), "action":"SELECT"}
	do $$$AssertEquals(..Api("POST", "/v2/security/sql-privilege/grant", q, , , .raw), 200, raw)
	set after = $SYSTEM.SQL.Security.CheckPrivilege(..#GRANTEE, 1, ..#TABLE, "s", $namespace)
	do $$$AssertEquals(after, 1, "grant: CheckPrivilege SELECT = 1")
	do ..Evidence("grant: $SYSTEM.SQL.Security.CheckPrivilege(SELECT)="_after)
	do $$$AssertEquals(..Api("POST", "/v2/security/sql-privilege/revoke", q, , , .raw), 200, raw)
	set after = $SYSTEM.SQL.Security.CheckPrivilege(..#GRANTEE, 1, ..#TABLE, "s", $namespace)
	do $$$AssertEquals(after, 0, "revoke: CheckPrivilege SELECT = 0")
	do ..Evidence("revoke: $SYSTEM.SQL.Security.CheckPrivilege(SELECT)="_after)
}

Method AdminPrivilegeHeld(privilegeProperty As %String) As %Boolean
{
	new $namespace
	set ns = $namespace
	set $namespace = "%SYS"
	set set = ##class(Security.SQLAdminPrivilegeSet).%OpenId(ns_"||"_..#GRANTEE)
	quit $select($isobject(set):+$property(set, privilegeProperty), 1:0)
}

Method TestSqlAdminPrivilegeGrantListRevoke()
{
	quit:..Skip()
	set q = {"namespace":($namespace), "grantee":(..#GRANTEE), "privilege":"%CREATE_TABLE"}
	do $$$AssertEquals(..Api("POST", "/v2/security/sql-admin-privilege/grant", q, , , .raw), 200, raw)
	do $$$AssertTrue(..AdminPrivilegeHeld("CreateTable"), "grant: Security.SQLAdminPrivilegeSet.CreateTable = 1")
	do ..Evidence("grant: Security.SQLAdminPrivilegeSet("_$namespace_"||"_..#GRANTEE_").CreateTable=1")

	do $$$AssertEquals(..Api("GET", "/v2/security/sql-admin-privileges", {"namespace":($namespace), "grantee":(..#GRANTEE)}, , .json, .raw), 200, raw)
	set listed = 0
	set iter = json.result.%GetIterator()
	while iter.%GetNext(, .item) { set:(item.Privilege="%CREATE_TABLE") listed = 1 }
	do $$$AssertTrue(listed, "list: %CREATE_TABLE listed while the stored set holds it")
	do ..Evidence("list: %CREATE_TABLE present, matching the stored privilege set")

	do $$$AssertEquals(..Api("POST", "/v2/security/sql-admin-privilege/revoke", q, , , .raw), 200, raw)
	do $$$AssertNotTrue(..AdminPrivilegeHeld("CreateTable"), "revoke: CreateTable = 0")
	do ..Evidence("revoke: Security.SQLAdminPrivilegeSet.CreateTable=0")
}

Method ColumnPrivilegeHeld(column As %String, action As %String) As %Boolean
{
	set held = 0
	set rs = ##class(%ResultSet).%New("%SQL.Manager.CatalogPriv:UserColumnPrivs")
	do rs.Execute(..#GRANTEE, $piece(..#TABLE, ".", 1), $piece(..#TABLE, ".", 2))
	while rs.Next() {
		set row = ""
		for i=1:1:rs.GetColumnCount() { set row = row _ "|" _ rs.GetData(i) }
		if (row [ ("|"_column_"|")) && ($zconvert(row, "U") [ action) set held = 1
	}
	quit held
}

Method TestSqlColumnPrivilegeGrantListRevoke()
{
	quit:..Skip()
	set q = {"namespace":($namespace), "grantee":(..#GRANTEE), "type":"TABLE", "object":(..#TABLE), "column":"Amount", "action":"UPDATE"}
	do $$$AssertEquals(..Api("POST", "/v2/security/sql-column-privilege/grant", q, , , .raw), 200, raw)
	do $$$AssertTrue(..ColumnPrivilegeHeld("Amount", "UPDATE"), "grant: %SQL.Manager.CatalogPriv:UserColumnPrivs shows Amount UPDATE")
	do ..Evidence("grant: UserColumnPrivs(fdt_grantee, FDTest, Orders) contains Amount/UPDATE")

	do $$$AssertEquals(..Api("GET", "/v2/security/sql-column-privileges", {"namespace":($namespace), "grantee":(..#GRANTEE), "object":(..#TABLE)}, , .json, .raw), 200, raw)
	set listed = 0
	set iter = json.result.%GetIterator()
	while iter.%GetNext(, .item) { set:((item.Column="Amount")&&(item.Action="UPDATE")) listed = 1 }
	do $$$AssertTrue(listed, "list: Amount UPDATE listed while the catalog holds it")
	do ..Evidence("list: Amount/UPDATE present, matching the catalog")

	do $$$AssertEquals(..Api("POST", "/v2/security/sql-column-privilege/revoke", q, , , .raw), 200, raw)
	do $$$AssertNotTrue(..ColumnPrivilegeHeld("Amount", "UPDATE"), "revoke: catalog no longer shows Amount UPDATE")
	do ..Evidence("revoke: UserColumnPrivs no longer contains Amount/UPDATE")
}

// ---- OAuth2 ----------------------------------------------------------------------------------

Method TestOAuth2RevokeUserTokens()
{
	quit:..Skip()
	set user = "fdt_oauth_user"
	// Fixture: a token record for the user. No OAuth2 authorization server is configured in the
	// container, so the token is inserted directly; the revoke operation must remove it.
	new $namespace
	set ns = $namespace
	set $namespace = "%SYS"
	set token = ##class(OAuth2.Server.AccessToken).%New()
	set token.Username = user, token.AuthorizationCode = "fdt-code-"_$random(1E9), token.AccessToken = "fdt-token-"_$random(1E9), token.ClientId = "fdt-client"
	set sc = token.%Save()
	set id = token.%Id()
	set existedBefore = ##class(OAuth2.Server.AccessToken).%ExistsId(id)
	set $namespace = ns
	do $$$AssertStatusOK(sc, "fixture token saved")
	do $$$AssertTrue(existedBefore, "control: the token exists before revoke")
	do $$$AssertEquals(..Api("POST", "/v2/security/oauth2/revoke", {"user":(user)}, , , .raw), 200, raw)
	set $namespace = "%SYS"
	set stillThere = ##class(OAuth2.Server.AccessToken).%ExistsId(id)
	if stillThere do ##class(OAuth2.Server.AccessToken).%DeleteId(id)
	set $namespace = ns
	do $$$AssertNotTrue(stillThere, "revoke removed the user's token (OAuth2.Server.AccessToken.%ExistsId)")
	do ..Evidence("OAuth2.Server.AccessToken id "_id_" for "_user_" exists before/after revoke = "_existedBefore_"/"_stillThere)
}

// ---- tasks -----------------------------------------------------------------------------------

Method CreateTask(name As %String) As %Integer
{
	set tasks = ##class(FlightDeck.Admin.Client).Get("/v2/tasks", {"filter":(name)}, .status)
	if $isobject(tasks) {
		set iter = tasks.%GetIterator()
		while iter.%GetNext(, .t) { do:(t.Name=name) ..Api("DELETE", "/v2/task", {"id":(t.Id)}) }
	}
	set body = {"Name":(name), "Description":"FlightDeck adapter test", "TaskClass":"FlightDeck.Demo.NoopTask", "NameSpace":($namespace), "RunAsUser":($username), "TimePeriod":"Daily", "TimePeriodEvery":1, "TimePeriodDay":"", "DailyFrequency":"Once", "DailyFrequencyTime":"", "DailyIncrement":"", "DailyStartTime":"04:30:00", "DailyEndTime":"04:30:00", "StartDate":($zdate($horolog + 1, 3)), "EndDate":"", "Priority":"Normal", "MirrorStatus":"Any", "RunAfterGUID":"", "EmailOnCompletion":[], "EmailOnError":[], "EmailOnExpiration":[], "EmailOutput":false, "Expires":false, "ExpiresDays":"", "ExpiresHours":"", "ExpiresMinutes":"", "OpenOutputFile":false, "OutputDirectory":"", "OutputFilename":"", "OutputFileIsBinary":false, "SuspendOnError":false, "SuspendTerminated":false, "IsBatch":false, "RescheduleOnStart":true, "Settings":{}}
	set st = ..Api("POST", "/v2/task", , body, , .raw, .headers)
	do $$$AssertEquals(st, 201, "fixture task: "_raw)
	quit +$piece($get(headers("location")), "id=", 2)
}

Method TaskSuspended(id As %Integer) As %Integer
{
	new $namespace
	set $namespace = "%SYS"
	set task = ##class(%SYS.Task).%OpenId(id)
	quit $select($isobject(task):task.Suspended, 1:-1)
}

Method TestTaskSuspendAndResume()
{
	quit:..Skip()
	set id = ..CreateTask("FDT adapter task")
	do $$$AssertTrue(id > 0, "task id")
	// LeaveInQueue defaults to true -> v1 Action Suspend -> %SYS.Task.Suspended = 1
	do $$$AssertEquals(..Api("POST", "/v2/task/suspend", {"id":(id)}, , , .raw), 200, raw)
	do $$$AssertEquals(..TaskSuspended(id), 1, "suspend (default LeaveInQueue): %SYS.Task.Suspended = 1")
	do ..Evidence("suspend default: %SYS.Task("_id_").Suspended="_..TaskSuspended(id))
	do $$$AssertEquals(..Api("POST", "/v2/task/resume", {"id":(id)}, , , .raw), 200, raw)
	do $$$AssertEquals(..TaskSuspended(id), 0, "resume: %SYS.Task.Suspended = 0")
	do ..Evidence("resume: %SYS.Task("_id_").Suspended="_..TaskSuspended(id))
	// LeaveInQueue false -> v1 Action SuspendAndReschedule -> Suspended = 2
	do $$$AssertEquals(..Api("POST", "/v2/task/suspend", {"id":(id)}, {"LeaveInQueue":false}, , .raw), 200, raw)
	do $$$AssertEquals(..TaskSuspended(id), 2, "suspend LeaveInQueue=false: %SYS.Task.Suspended = 2 (SuspendAndReschedule)")
	do ..Evidence("suspend LeaveInQueue=false: %SYS.Task("_id_").Suspended="_..TaskSuspended(id))
	do ..Api("POST", "/v2/task/resume", {"id":(id)})
	do ..Api("DELETE", "/v2/task", {"id":(id)})
}

Method TestTaskManagerSuspendResumeRun()
{
	quit:..Skip()
	do $$$AssertEquals(..Api("POST", "/v2/task/manager/suspend", , , , .raw), 200, raw)
	set flag = ..ManagerSuspended()
	do $$$AssertEquals(flag, 1, "manager suspend: %SYS.TaskSuper.SuspendGet() = 1")
	do ..Evidence("manager suspend: %SYS.TaskSuper.SuspendGet()="_flag)
	do $$$AssertEquals(..Api("POST", "/v2/task/manager/resume", , , , .raw), 200, raw)
	set flag = ..ManagerSuspended()
	do $$$AssertEquals(flag, 0, "manager resume: SuspendGet() = 0")
	do ..Evidence("manager resume: %SYS.TaskSuper.SuspendGet()="_flag)

	// Run starts TASKMGR when it is not running (409 "TASKMGR is already running" otherwise).
	set pid = ..StopTaskManager()
	do $$$AssertTrue(pid '= "", "fixture: TASKMGR process found and stopped")
	set before = ..ManagerRunning()
	do $$$AssertEquals(before, 0, "fixture: TASKMGRStatus() = 0 before run")
	do $$$AssertEquals(..Api("POST", "/v2/task/manager/run", , , , .raw), 200, raw)
	set after = 0
	for i=1:1:20 { set after = ..ManagerRunning() quit:after  hang 0.5 }
	do $$$AssertEquals(after, 1, "manager run: TASKMGRStatus() = 1")
	do ..Evidence("manager run: TASKMGRStatus() "_before_" -> "_after_" (TASKMGR pid "_pid_" had been stopped)")
}

Method ManagerSuspended() As %Integer
{
	new $namespace
	set $namespace = "%SYS"
	quit +##class(%SYS.TaskSuper).SuspendGet()
}

Method ManagerRunning() As %Integer
{
	new $namespace
	set $namespace = "%SYS"
	quit +##class(%SYS.TaskSuper).TASKMGRStatus()
}

Method StopTaskManager() As %String
{
	new $namespace
	set $namespace = "%SYS"
	set found = ""
	set rs = ##class(%ResultSet).%New("%SYS.ProcessQuery:ListPids")
	do rs.Execute()
	while rs.Next() {
		set p = ##class(%SYS.ProcessQuery).%OpenId(rs.Get("Pid"))
		if $isobject(p), p.Routine [ "TaskSuper" set found = p.Pid quit
	}
	if found '= "" {
		do $system.Process.Terminate(found)
		for i=1:1:20 { quit:'##class(%SYS.ProcessQuery).%ExistsId(found)  hang 0.5 }
	}
	quit found
}

// ---- processes -------------------------------------------------------------------------------

ClassMethod Sleep(seconds As %Integer = 300)
{
	hang seconds
}

Method ProcessState(pid As %Integer) As %String
{
	new $namespace
	set $namespace = "%SYS"
	set p = ##class(%SYS.ProcessQuery).%OpenId(pid)
	quit $select($isobject(p):p.State, 1:"(gone)")
}

Method TestProcessSuspendResumeTerminate()
{
	quit:..Skip()
	job ##class(FlightDeck.Test.V1Translations).Sleep(300)
	set pid = $zchild
	hang 1
	set start = ..ProcessState(pid)
	do $$$AssertTrue(start '= "(gone)", "fixture process "_pid_" state "_start)
	do $$$AssertEquals(..Api("POST", "/v2/process/suspend", {"id":(pid)}, , , .raw), 200, raw)
	set suspended = ..ProcessState(pid)
	do $$$AssertTrue($zconvert(suspended, "U") [ "SUSP", "suspend: %SYS.ProcessQuery.State shows suspended ("_suspended_")")
	do ..Evidence("suspend: %SYS.ProcessQuery("_pid_").State "_start_" -> "_suspended)
	do $$$AssertEquals(..Api("POST", "/v2/process/resume", {"id":(pid)}, , , .raw), 200, raw)
	set resumed = ..ProcessState(pid)
	do $$$AssertNotTrue($zconvert(resumed, "U") [ "SUSP", "resume: State no longer suspended ("_resumed_")")
	do ..Evidence("resume: %SYS.ProcessQuery("_pid_").State -> "_resumed)
	set st = ..Api("POST", "/v2/process/terminate", {"id":(pid)}, , , .raw)
	do $$$AssertTrue(st < 300, "terminate: "_st_" "_raw)
	set gone = 0
	for i=1:1:20 { if ..ProcessState(pid) = "(gone)" { set gone = 1 quit } hang 0.5 }
	do $$$AssertTrue(gone, "terminate: process no longer exists in %SYS.ProcessQuery")
	do ..Evidence("terminate: %SYS.ProcessQuery("_pid_") exists after terminate = "_('gone))
}

// ---- async results ---------------------------------------------------------------------------

Method AsyncState(guid As %String) As %String
{
	new $namespace
	set $namespace = "%SYS"
	set state = "(missing)"
	set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT State FROM Api_Admin_v1_Util.AsyncTask WHERE GUID = ?", guid)
	if rs.%Next() set state = rs.State
	quit state
}

/// Submits async audit listings until one is still Queued (the async work queue is saturated),
/// and returns its id. The stored state is read, never the HTTP answer.
Method QueuedAsyncTask(Output submitted As %Integer) As %String
{
	set submitted = 0, found = ""
	for i=1:1:40 {
		do ..Api("POST", "/v2/security/audit/records", {"maxRows":100000}, {}, , , .headers)
		set submitted = submitted + 1
		set guid = $piece($get(headers("location")), "id=", 2)
		if (guid '= "") && (..AsyncState(guid) = "Queued") { set found = guid quit }
	}
	quit found
}

Method TestAsyncResultCancel()
{
	quit:..Skip()
	// A queued task can start between the state read and the cancel; a 409 is accepted only
	// when the stored state proves the task had left Queued, and the next queued task is tried.
	set cancelled = 0, attempts = 0
	while ('cancelled) && (attempts < 5) {
		set attempts = attempts + 1
		set guid = ..QueuedAsyncTask(.submitted)
		continue:guid=""
		set st = ..Api("POST", "/v2/async-result/cancel", {"id":(guid)}, , , .raw)
		set state = ..AsyncState(guid)
		if st = 200 {
			do $$$AssertEquals(state, "Canceled", "cancel: stored AsyncTask.State = Canceled")
			do ..Evidence("cancel: Api.Admin.v1.Util.AsyncTask("_guid_").State Queued -> "_state_" (attempt "_attempts_", queued after "_submitted_" submissions)")
			set cancelled = 1
		} else {
			do $$$AssertTrue((st = 409) && (state '= "Queued"), "race only: 409 while stored state is "_state_" ("_$extract(raw, 1, 120)_")")
		}
	}
	do $$$AssertTrue(cancelled, "a queued task was cancelled within "_attempts_" attempts")
}

/// Pause and resume only succeed for background database tasks (database-dir compact, defragment,
/// and similar), which do not exist on the v1 dialect; every other async task answers 409 on both
/// dialects. The effect verified here is that the translated request reaches the async task's own
/// Pause/Resume (its specific error id, not a validator error) and leaves the stored state unchanged.
Method TestAsyncResultPauseResume()
{
	quit:..Skip()
	// A Finished task: its state is terminal, so an unchanged state is attributable to the call.
	do ..Api("POST", "/v2/security/audit/records", {"maxRows":10}, {}, , , .headers)
	set guid = $piece($get(headers("location")), "id=", 2)
	for i=1:1:40 { quit:..AsyncState(guid)="Finished"  hang 0.25 }
	do $$$AssertEquals(..AsyncState(guid), "Finished", "fixture: a Finished async task")
	for action = "pause", "resume" {
		set expected = $select(action="pause":"CannotPauseAsyncTask", 1:"CannotResumeAsyncTask")
		set before = ..AsyncState(guid)
		set st = ..Api("POST", "/v2/async-result/"_action, {"id":(guid)}, , .json, .raw)
		set id = ""
		try { set id = json.status.errors.%Get(0).id } catch {}
		do $$$AssertEquals(st, 409, action_": HTTP 409 from the task, "_$extract(raw, 1, 200))
		do $$$AssertEquals(id, expected, action_": error id "_expected_" proves AsyncTask."_$zconvert(action, "W")_" ran")
		do $$$AssertEquals(..AsyncState(guid), before, action_": stored state unchanged")
		do ..Evidence(action_": "_st_" "_id_"; AsyncTask.State "_before_" -> "_..AsyncState(guid))
	}
}

// ---- external language servers ---------------------------------------------------------------

Method TestExternalLanguageServerStartStop()
{
	quit:..Skip()
	set name = "%Java Server"
	if $system.external.isServerRunning(name) do ..Api("POST", "/v2/ext-lang-server/stop", {"name":(name)})
	do $$$AssertNotTrue($system.external.isServerRunning(name), "fixture: stopped")
	set st = ..Api("POST", "/v2/ext-lang-server/start", {"name":(name)}, , , .raw)
	do $$$AssertEquals(st, 200, "start: "_$extract(raw, 1, 300))
	do $$$AssertTrue($system.external.isServerRunning(name), "start: $system.external.isServerRunning = 1")
	do ..Evidence("start: $system.external.isServerRunning("""_name_""")="_$system.external.isServerRunning(name))
	do $$$AssertEquals(..Api("POST", "/v2/ext-lang-server/stop", {"name":(name)}, , , .raw), 200, $extract(raw, 1, 300))
	do $$$AssertNotTrue($system.external.isServerRunning(name), "stop: isServerRunning = 0")
	do ..Evidence("stop: $system.external.isServerRunning("""_name_""")="_$system.external.isServerRunning(name))
}

// ---- coverage guard --------------------------------------------------------------------------

/// Every different-shape translation in the table is exercised above. Keep in sync.
Method TestAllTranslationsCovered()
{
	quit:..Skip()
	set covered = $listbuild("GET /info", "GET /v2/wallet/collections", "GET /v2/wallet/collection", "PUT /v2/wallet/collection", "DELETE /v2/wallet/collection", "GET /v2/security/encryption/data-element-keys", "GET /v2/security/sql-admin-privileges", "GET /v2/security/sql-column-privileges", "POST /v2/security/sql-privilege/grant", "POST /v2/security/sql-privilege/revoke", "POST /v2/security/sql-admin-privilege/grant", "POST /v2/security/sql-admin-privilege/revoke", "POST /v2/security/sql-column-privilege/grant", "POST /v2/security/sql-column-privilege/revoke", "POST /v2/security/oauth2/revoke", "POST /v2/task/suspend", "POST /v2/task/resume", "POST /v2/task/manager/suspend", "POST /v2/task/manager/resume", "POST /v2/task/manager/run", "POST /v2/process/suspend", "POST /v2/process/resume", "POST /v2/process/terminate", "POST /v2/async-result/cancel", "POST /v2/async-result/pause", "POST /v2/async-result/resume", "POST /v2/ext-lang-server/start", "POST /v2/ext-lang-server/stop")
	do $$$AssertEquals($listlength(covered), 28)
	set table = ##class(FlightDeck.Admin.V1Routes).Table()
	set ptr = 0
	while $listnext(covered, ptr, op) {
		do $$$AssertTrue($isobject(table.%Get(op)), "translation exists: "_op)
		do $$$AssertTrue(##class(FlightDeck.Admin.V1Dialect).IsAvailable(op), "available: "_op)
	}
}

}
