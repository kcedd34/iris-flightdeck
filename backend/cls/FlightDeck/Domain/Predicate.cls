/// Evaluates the small, declarative predicates used by entity-type and mutation descriptors
/// (feature 002 data-model §1). A predicate is JSON data, never code: there is no XECUTE and no
/// indirection over request input.
/// <p>Paths are dotted names into the context object, for example "proposed.Enabled",
/// "object.AuthenticationMethods", "facts.system". Operators:
/// <ul>
/// <li><code>{"op":"true"}</code>, <code>{"op":"and","all":[...]}</code>,
/// <code>{"op":"or","any":[...]}</code>, <code>{"op":"not","expr":{...}}</code></li>
/// <li><code>{"op":"equals","path":..,"value":..}</code>, <code>{"op":"in","path":..,"values":[..]}</code></li>
/// <li><code>{"op":"defined","path":..}</code>, <code>{"op":"empty","path":..}</code> (undefined, "" or [])</li>
/// <li><code>{"op":"contains","path":..,"value":..}</code>: array membership, or substring of a string</li>
/// <li><code>{"op":"changed","fields":[..]}</code>: any of the fields is in context "changedFields"</li>
/// <li><code>{"op":"bitsCleared","path":..,"bitsPath":..}</code>: the integer at path is defined and
/// lacks at least one bit of the integer at bitsPath</li>
/// <li><code>{"op":"lacksTargetRole","path":..,"rolePath":..}</code>: the MatchRoles array at path is
/// defined and no entry's TargetRoles contains the role at rolePath</li>
/// </ul>
Class FlightDeck.Domain.Predicate [ Abstract ]
{

Parameter OPERATORS = "true,and,or,not,equals,in,defined,empty,contains,changed,bitsCleared,lacksTargetRole";

ClassMethod Eval(expr As %DynamicObject, ctx As %DynamicObject) As %Boolean
{
	if '$isobject(expr) quit 0
	set op = expr.op
	if op = "true" quit 1
	if op = "and" {
		set iter = expr.all.%GetIterator(), result = 1
		while iter.%GetNext(, .part) { if '..Eval(part, ctx) { set result = 0 quit } }
		quit result
	}
	if op = "or" {
		set iter = expr.any.%GetIterator(), result = 0
		while iter.%GetNext(, .part) { if ..Eval(part, ctx) { set result = 1 quit } }
		quit result
	}
	if op = "not" quit '..Eval(expr.expr, ctx)
	if op = "changed" {
		set changed = ctx.changedFields, result = 0
		quit:'$isobject(changed) 0
		set iter = expr.fields.%GetIterator()
		while iter.%GetNext(, .field) { if ..ArrayHas(changed, field) { set result = 1 quit } }
		quit result
	}
	set defined = ..Resolve(ctx, expr.path, .value)
	if op = "defined" quit defined
	if op = "empty" quit 'defined || (value = "") || ($isobject(value) && (value.%Size() = 0))
	quit:'defined 0
	if op = "equals" quit ..Same(value, expr.%Get("value"))
	if op = "in" {
		set iter = expr.values.%GetIterator(), result = 0
		while iter.%GetNext(, .candidate) { if ..Same(value, candidate) { set result = 1 quit } }
		quit result
	}
	if op = "contains" {
		if $isobject(value) quit ..ArrayHas(value, expr.%Get("value"))
		quit value [ expr.%Get("value")
	}
	if op = "bitsCleared" {
		quit:'..Resolve(ctx, expr.bitsPath, .bits) 0
		quit $zboolean(+value, +bits, 1) '= +bits
	}
	if op = "lacksTargetRole" {
		quit:'..Resolve(ctx, expr.rolePath, .role) 0
		quit:'$isobject(value) 1
		set iter = value.%GetIterator(), found = 0
		while iter.%GetNext(, .match) {
			if $isobject(match) && $isobject(match.TargetRoles) && ..ArrayHas(match.TargetRoles, role) { set found = 1 quit }
		}
		quit 'found
	}
	$$$ThrowStatus($$$ERROR($$$GeneralError, "Unknown predicate operator: "_op))
}

/// Resolves a dotted path. Returns 1 and the value when every segment is defined.
ClassMethod Resolve(ctx As %DynamicObject, path As %String, Output value) As %Boolean
{
	set value = "", node = ctx
	for i=1:1:$length(path, ".") {
		set key = $piece(path, ".", i)
		if '$isobject(node) || 'node.%IsDefined(key) quit
		set node = node.%Get(key)
		if i = $length(path, ".") set value = node return 1
	}
	quit 0
}

ClassMethod ArrayHas(array As %DynamicArray, item) As %Boolean
{
	quit:'$isobject(array) 0
	set iter = array.%GetIterator(), found = 0
	while iter.%GetNext(, .element) { if ..Same(element, item) { set found = 1 quit } }
	quit found
}

/// JSON-aware equality: booleans and numbers compare by value, strings exactly.
ClassMethod Same(a, b) As %Boolean
{
	if $isobject(a) || $isobject(b) quit 0
	if ($isvalidnum(a) && $isvalidnum(b)) quit +a = +b
	quit a = b
}

/// Structural validation used by FlightDeck.Domain.Descriptor: every operator is known and every
/// path starts with one of the allowed roots. Returns "" or the first problem found.
ClassMethod Problem(expr As %DynamicObject, roots As %String) As %String
{
	if '$isobject(expr) quit "predicate is not an object"
	set op = expr.op
	if '$listfind($listfromstring(..#OPERATORS), op) quit "unknown operator '"_op_"'"
	if (op = "and") || (op = "or") {
		set list = $select(op="and":expr.all, 1:expr.any)
		if '$isobject(list) quit op_" needs a list"
		set iter = list.%GetIterator(), problem = ""
		while iter.%GetNext(, .part) { set problem = ..Problem(part, roots) quit:problem'="" }
		quit problem
	}
	if op = "not" quit ..Problem(expr.expr, roots)
	for key = "path", "bitsPath", "rolePath" {
		continue:'expr.%IsDefined(key)
		set root = $piece(expr.%Get(key), ".", 1)
		if '$listfind($listfromstring(roots), root) return "path '"_expr.%Get(key)_"' is outside "_roots
	}
	quit ""
}

}
