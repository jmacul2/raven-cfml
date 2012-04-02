<cfcomponent extends="mxunit.framework.TestCase">

	<!--- this will run before every single test in this test case --->
	<!---<cffunction name="setUp" returntype="void" access="public" hint="put things here that you want to run before each test">
	</cffunction>--->

	<!--- this will run after every single test in this test case --->
	<!---<cffunction name="tearDown" returntype="void" access="public" hint="put things here that you want to run after each test">
	</cffunction>--->

        <!--- this will run once after initialization and before setUp() --->
	<cffunction name="beforeTests" returntype="void" access="public" hint="put things here that you want to run before all tests">
		<cfset ravenCFC = createObject("component", "lib.client")>
	</cffunction>

	<!--- this will run once after all tests have been run --->
	<!---<cffunction name="afterTests" returntype="void" access="public" hint="put things here that you want to run after all tests">
	</cffunction>--->

	<cffunction name="testHmacSha1" returntype="void" access="public">
		<cfset var result = ravenCFC.hmac_sha1('foo', 'bar')>
		<cfset assertEquals("46b4ec586117154dacd49d664e5d63fdc88efb51", result, "foo")>
	</cffunction>

	<cffunction name="testJsonEncodeStruct" returntype="void" access="public">
		<cfset var resultStruct = structNew()>
		<cfset var result = ''>
		<cfset resultStruct.foo = structNew()>
		<cfset resultStruct.foo.bar = 1>
		<cfset result = ravenCFC.jsonEncode(resultStruct)>
		<cfset assertEquals('{"foo":{"bar":1}}', result)>
	</cffunction>

	<cffunction name="testJsonEncodeNumeric" returntype="void" access="public">
		<cfset var result = ravenCFC.jsonEncode(123456)>
		<cfset assertEquals('123456', result)>
	</cffunction>

	<cffunction name="testJsonEncodeArray" returntype="void" access="public">
		<cfset var resultArray = arrayNew(1)>
		<cfset var result = ''>
		<cfset resultArray[1] = 3>
		<cfset resultArray[2] = 'foobar'>	
		<cfset var result = ravenCFC.jsonEncode(resultArray)>
		<cfset assertEquals('[3,"foobar"]', result)>
	</cffunction>

</cfcomponent>
