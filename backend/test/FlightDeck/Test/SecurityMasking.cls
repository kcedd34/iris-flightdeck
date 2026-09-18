/// Constitution VI on the security domain (feature 003 T050): a secret reaches the official API and
/// nothing else. Not the preview, not the applied result, not the trail, not an error text.
Class FlightDeck.Test.SecurityMasking Extends %UnitTest.TestCase
{

Parameter COLLECTION = "FDT_MaskCollection";

Parameter VALUE = "fdt-secret-value-2026";

Method OnBeforeAllTests() As %Status
{
	do ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/wallet/collection", {"name":(..#COLLECTION)}, {"UseResource":"FD_Demo_Reports:READ", "EditResource":"FD_Demo_Reports:WRITE"}, .status)
	quit $$$OK
}

Method OnAfterAllTests() As %Status
{
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/wallet/secret", {"name":(..#COLLECTION_".fdt_token")}, , .status)
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/wallet/collection", {"name":(..#COLLECTION)}, , .status)
	quit $$$OK
}

/// A wallet secret: previewed, applied, and read back — the value appears in none of them.
Method TestWalletSecretNeverComesBack()
{
	set request = {
		"operationId": "PUT /v2/wallet/secret",
		"keys": {"name": (..#COLLECTION_".fdt_token")},
		"params": {"name": (..#COLLECTION_".fdt_token"), "collection": (..#COLLECTION), "type": "%Wallet.KeyValue", "secret": (..#VALUE)}
	}
	set preview = ##class(FlightDeck.Mutation.Service).DoPreview(request, .status)
	if status = 501 {
		// Where FlightDeck declines the write (this version shapes the secret body differently), the
		// refusal is what the screen gets, and it must carry the reason and no value.
		do $$$AssertNotTrue(preview.%ToJSON() [ ..#VALUE, "no value in the refusal")
		do $$$AssertTrue(preview.error.message [ "wallet API", "the refusal states why: "_preview.error.message)
		quit
	}
	do $$$AssertEquals(status, 200, "preview: "_preview.%ToJSON())
	do $$$AssertNotTrue(preview.%ToJSON() [ ..#VALUE, "no value in the preview")
	set request.fingerprint = preview.fingerprint
	set response = ##class(FlightDeck.Mutation.Service).DoApply(request, .applyStatus)
	do $$$AssertNotTrue(response.%ToJSON() [ ..#VALUE, "no value in the result, the trail or the platform's error")
	if applyStatus '= 200 {
		// This version's API wants another configuration shape for %Wallet.KeyValue (IRIS 2026.1),
		// so FlightDeck declines the write (501) rather than guess it; where it tried and the
		// platform refused, the platform's own message is reported (502). Either way the refusal
		// carries no value, which is what this test is about.
		do $$$AssertTrue((applyStatus = 501) || (applyStatus = 502), "the refusal is reported: "_applyStatus_" "_$extract(response.%ToJSON(), 1, 200))
		quit
	}
	// The listing knows the secret exists; the platform offers no operation that reads its value.
	set secrets = ##class(FlightDeck.Admin.Client).Get("/v2/wallet/secrets", {"collection":(..#COLLECTION)}, .readStatus)
	do $$$AssertEquals(readStatus, 200)
	do $$$AssertNotTrue(secrets.%ToJSON() [ ..#VALUE, "no value in the official listing")
	do $$$AssertTrue(secrets.%ToJSON() [ "fdt_token", "the secret is there by name")
}

/// Every descriptor that carries secret material declares it, so the mask covers it.
Method TestEverySecretFieldIsDeclared()
{
	set mutations = ##class(FlightDeck.Domain.Descriptor).Mutations()
	set iter = mutations.%GetIterator(), checked = 0
	while iter.%GetNext(.op, .mutation) {
		continue:'mutation.%IsDefined("body")
		set fields = mutation.body.%GetIterator()
		while fields.%GetNext(.field) {
			continue:'((field [ "Password") || (field [ "Secret") || (field [ "Token"))
			set checked = checked + 1
			do $$$AssertTrue(##class(FlightDeck.Mutation.Mask).IsSecret(mutation.secretFields, field), op_" declares "_field_" secret")
		}
	}
	do $$$AssertTrue(checked > 0, "some operation carries secret material in its body")
}

/// An official error that echoes the input is masked before it leaves the server.
Method TestErrorTextIsMasked()
{
	set masked = ##class(FlightDeck.Mutation.Mask).Text("ERROR: value " _ ..#VALUE _ " rejected", {"secret": (..#VALUE)}, ["secret"])
	do $$$AssertNotTrue(masked [ ..#VALUE, "the value is masked in an error text")
}

}
