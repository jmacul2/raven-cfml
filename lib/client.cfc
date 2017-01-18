<cfcomponent displayname="sentry" output="false">

	<cfscript>
		/**
			* @customHttpInterface The path to a custom Http interface.
		*/
		function init(
			string DSN,
			string publicKey,
			string privateKey,
			numeric projectID,
			string sentryUrl = 'https://app.getsentry.com',
			string logger = 'raven-cfml',
			string serverName = CGI.SERVER_NAME,
			any cgiVars = CGI,
			any httpRequestData = getHttpRequestData(),
			string customHttpInterface = ''
		) {
			if (!isNull(DSN) && len(DSN)) {
				_parseDSN(DSN);
			} else if (
				!isNull(arguments.publicKey) &&
				!isNull(arguments.privateKey) &&
				!isNull(arguments.projectID)
			) {
				this.publicKey = arguments.publicKey;
				this.privateKey = arguments.privateKey;
				this.projectID = arguments.projectID;
				this.sentryUrl = arguments.sentryUrl;
			} else {
				throw(message = "Missing client keys");
			}

			this.ravenCFMLVersion = '0.1.0';
			this.sentryVersion = '2.0';
			this.errorList = '10,20,30,40,50';
			this.logger = arguments.logger;
			this.serverName = arguments.serverName;
			this.cgiVars = arguments.cgiVars;
			this.httpRequestData = arguments.httpRequestData;
			this.customHttpInterface = arguments.customHttpInterface;

			return this;
		}

		private void function _parseDSN(required string DSN) {
			var r = '^(?:(\w+):)?\/\/(\w+):(\w+)?@([\w\.-]+)\/(.*)';
			var Pattern = createObject('java', 'java.util.regex.Pattern');
			var p = Pattern.compile(r);
			var m = p.matcher(DSN);
			var res = [];
			if(m.find()) {
					var i = 1;
					while(i <= m.groupCount()) {
						res.add(m.group(i));
						i++;
					}
			}
			if (arrayLen(res) != 5) {
				throw(message = 'Error parsing DSN');
			}

			this.publicKey = res[2];
			this.privateKey = res[3];
			this.projectID = res[5];
			this.sentryUrl = res[1] & '://' & res[4];
		}
	</cfscript>


	<cffunction name="captureMessage" output="false" returntype="any">
		<cfargument name="message" type="string" required="true">
		<cfargument name="errorType" type="numeric" default="30">
		<cfargument name="params" type="any" default="">

		<cfset var sentryMessage = structNew()>

		<cfif listContains(this.errorList, arguments.errorType) EQ 0>
			<cfthrow message="Error Type must be one of the following: [#this.errorList#]">
		</cfif>

		<cfscript>
			sentryMessage['message'] = arguments.message;
			sentryMessage['level'] = arguments.errorType;

			sentryMessage['sentry.interfaces.Message'] = structNew();
			sentryMessage['sentry.interfaces.Message']['message'] = '#arguments.message#';
			if(isArray(arguments.params)) {
				sentryMessage['sentry.interfaces.Message']['params'] = arguments.params;
			}

			capture(sentryMessage);
		</cfscript>
	</cffunction>


	<cffunction name="captureException" output="false" returntype="any">
		<cfargument name="exception" type="any" required="true">
		<cfargument name="errorType" type="numeric" default="40">
		<cfargument name="oneLineStackTrace" type="boolean" default="false" hint="Set to true for improved performance. This will disable the full trace.">
		<cfargument name="showJavaStackTrace" type="boolean" default="false">
		<cfargument name="locals" type="any" default="" hint="A struct of local variables you might want to pas to be included in the stacktrace.">
		<cfargument name="additionalData" type="any">

		<cfscript>
			var sentryException = structNew();
			var file = '';
		    var fileArray = '';
		    var currentTemplate = '';
		    var tagContext = exception['TagContext'];
		</cfscript>

		<cfif listContains(this.errorList, arguments.errorType) EQ 0>
			<cfthrow message="Error Type must be one of the following: [#this.errorList#]">
		</cfif>

		<cfscript>
			sentryException['message'] = '#exception.type# Error: #exception.message# #exception.detail#';
			sentryException['level'] = arguments.errorType;
			sentryException['culprit'] = exception.message;

			var sentryExceptionExtra = structNew();
			if (arguments.showJavaStackTrace) {
				sentryExceptionExtra['Java StackTrace'] = listToArray(replace(exception['StackTrace'], chr(9), "", "All"), chr(10));
			}

				if (!isNull(arguments.additionalData)) {
					if (!IsArray(arguments.additionalData)) {
						arguments.additionalData = [arguments.additionalData];
					}
					if (arrayLen(arguments.additionalData)) {
						sentryExceptionExtra['Additional Data'] = arguments.additionalData;
					}
				}

			if (structCount(sentryExceptionExtra)) {
				sentryException['extra'] = sentryExceptionExtra;
			}

			sentryException['sentry.interfaces.Exception'] = structNew();
			sentryException['sentry.interfaces.Exception']['value'] = '#exception.message# #exception.detail#';
			sentryException['sentry.interfaces.Exception']['type'] = '#exception.type# Error';
			//sentryException['sentry.interfaces.Exception']['module'] = '__builtin__';

			if (arguments.oneLineStackTrace) {
				exception['TagContext'] = exception['TagContext'][1];
			}

			sentryException['sentry.interfaces.Stacktrace'] = structNew();
			sentryException['sentry.interfaces.Stacktrace']['frames'] = arrayNew(1);

			for (i=1; i LTE arrayLen(exception['TagContext']); i=i+1) {
				if (exception['TagContext'][i]['TEMPLATE'] NEQ currentTemplate) {
					fileArray = arrayNew(1);
					if (fileExists(exception['TagContext'][i]['TEMPLATE'])) {
						file = fileOpen(exception['TagContext'][i]['TEMPLATE'], "read");
						while (!fileIsEOF(file)) {
							arrayAppend(fileArray, fileReadLine(file));
						}
						fileClose(file);
					}
					currentTemplate = exception['TagContext'][i]['TEMPLATE'];
				}

				sentryException['sentry.interfaces.Stacktrace']['frames'][i] = structNew();
				sentryException['sentry.interfaces.Stacktrace']['frames'][i]['abs_path'] = exception['TagContext'][i]['TEMPLATE'];
				sentryException['sentry.interfaces.Stacktrace']['frames'][i]['filename'] = exception['TagContext'][i]['TEMPLATE'];
				sentryException['sentry.interfaces.Stacktrace']['frames'][i]['lineno'] = exception['TagContext'][i]['LINE'];
				if (i EQ 1) {
					sentryException['sentry.interfaces.Stacktrace']['frames'][i]['function'] = 'column #exception['TagContext'][i]['COLUMN']#';
				}
				else {
					sentryException['sentry.interfaces.Stacktrace']['frames'][i]['function'] = exception['TagContext'][i]['ID'];
				}
				sentryException['sentry.interfaces.Stacktrace']['frames'][i]['pre_context'] = arrayNew(1);
				if (exception['TagContext'][i]['LINE']-3 GTE 1) { sentryException['sentry.interfaces.Stacktrace']['frames'][i]['pre_context'][1] = fileArray[exception['TagContext'][i]['LINE']-3]; }
				if (exception['TagContext'][i]['LINE']-2 GTE 1) { sentryException['sentry.interfaces.Stacktrace']['frames'][i]['pre_context'][1] = fileArray[exception['TagContext'][i]['LINE']-2]; }
				if (exception['TagContext'][i]['LINE']-1 GTE 1) { sentryException['sentry.interfaces.Stacktrace']['frames'][i]['pre_context'][2] = fileArray[exception['TagContext'][i]['LINE']-1]; }
				if (arrayLen(fileArray)) {
					sentryException['sentry.interfaces.Stacktrace']['frames'][i]['context_line'] = fileArray[exception['TagContext'][i]['LINE']];
				}
				sentryException['sentry.interfaces.Stacktrace']['frames'][i]['post_context'] = arrayNew(1);
				if (arrayLen(fileArray) GTE exception['TagContext'][i]['LINE']+1) { sentryException['sentry.interfaces.Stacktrace']['frames'][i]['post_context'][1] = fileArray[exception['TagContext'][i]['LINE']+1]; }
				if (arrayLen(fileArray) GTE exception['TagContext'][i]['LINE']+2) { sentryException['sentry.interfaces.Stacktrace']['frames'][i]['post_context'][2] = fileArray[exception['TagContext'][i]['LINE']+2]; }

				if (i == 1 and isStruct(arguments.locals)) {
					sentryException['sentry.interfaces.Stacktrace']['frames'][i]['vars'] = structNew();
					for (j IN locals) {
						sentryException['sentry.interfaces.Stacktrace']['frames'][i]['vars'][j] = locals[j];
					}
				}
			}

			capture(sentryException);
		</cfscript>
	</cffunction>


	<cffunction name="capture" returntype="void" output="false">
		<cfargument name="captureStruct" type="any" required="true">
		<cfargument name="useSigniture" type="boolean" default="false">

		<cfscript>
			var captureStuct = arguments.captureStruct;
			var jsonCapture = '';
			var signiture = '';
			var header = '';
			var timeVars = getTimeVars();
			var appStruct = structNew();

			// Add global metadata
			captureStuct['event_id'] = lcase(replace(createUUID(), '-', '', 'all'));
			captureStuct['timestamp'] = timeVars.timeStamp;
			captureStuct['logger'] = this.logger;
			captureStuct['project'] = this.projectID;
			captureStuct['server_name'] = this.serverName;

			// Custom Interface for Coldfusion
			if (this.customHttpInterface NEQ "") {
				for (i in application) {
					if(NOT isStruct(application[i])){
						structInsert(appStruct, i, application[i]);
					}
					else {
						structInsert(appStruct, i, "struct(#structCount(application[i])#)");
					}
				}
				captureStuct[this.customHttpInterface] = structNew();
				captureStuct[this.customHttpInterface]['url_path'] = 'http://' & this.cgiVars.SERVER_NAME & this.cgiVars.SCRIPT_NAME;
				captureStuct[this.customHttpInterface]['query_string'] = this.cgiVars.QUERY_STRING;
				captureStuct[this.customHttpInterface]['method'] = this.cgiVars.REQUEST_METHOD;
				if (isStruct(this.httpRequestData) AND structKeyExists(this.httpRequestData, 'headers')) {
					captureStuct[this.customHttpInterface]['headers'] = this.httpRequestData.headers;
				}
				captureStuct[this.customHttpInterface]['cookies'] = COOKIE;
				captureStuct[this.customHttpInterface]['sessions'] = SESSION;
				captureStuct[this.customHttpInterface]['form'] = FORM;
				captureStuct[this.customHttpInterface]['url'] = URL;
				captureStuct[this.customHttpInterface]['application'] = appStruct;
				captureStuct[this.customHttpInterface]['cgi'] = this.cgiVars;
			}

			captureStuct['sentry.interfaces.Http'] = structNew();
			captureStuct['sentry.interfaces.Http']['url'] = 'http://' & this.cgiVars.SERVER_NAME & this.cgiVars.SCRIPT_NAME;
			captureStuct['sentry.interfaces.Http']['method'] = this.cgiVars.REQUEST_METHOD;
			captureStuct['sentry.interfaces.Http']['data'] = FORM;
			captureStuct['sentry.interfaces.Http']['query_string'] = this.cgiVars.QUERY_STRING;
			captureStuct['sentry.interfaces.Http']['cookies'] = COOKIE;
			if (isStruct(this.httpRequestData) AND structKeyExists(this.httpRequestData, 'headers')) {
				captureStuct['sentry.interfaces.Http']['headers'] = this.httpRequestData.headers;
			}
			captureStuct['sentry.interfaces.Http']['env'] = this.cgiVars;

			jsonCapture = jsonEncode(captureStruct);
			signiture = hmac_sha1(this.privateKey, '#timeVars.time# #jsonCapture#');
			if (arguments.useSigniture) {
				header = "Sentry sentry_version=#this.sentryVersion#, sentry_signature=#signiture#, sentry_timestamp=#timeVars.time#, sentry_key=#this.publicKey#, sentry_client=raven-cfml/#this.ravenCFMLVersion#";
			}
			else {
				header = "Sentry sentry_version=#this.sentryVersion#, sentry_timestamp=#timeVars.time#, sentry_key=#this.publicKey#, sentry_client=raven-cfml/#this.ravenCFMLVersion#";
			}
		</cfscript>

		<cfhttp url="#this.sentryUrl#/api/store/" method="post" timeout="2">
			<cfhttpparam type="header" name="X-Sentry-Auth" value="#header#">
			<cfhttpparam type="body" value="#jsonCapture#">
		</cfhttp>
	</cffunction>


	<cffunction name="getTimeVars" returntype="struct" output="false">
		<cfscript>
			var timeVars = structNew();
			var time = now();
			timeVars.time = time.getTime();
			timeVars.utcNowTime = dateConvert("Local2UTC", time);
			timeVars.timeStamp = '#dateformat(timeVars.utcNowTime, "yyyy-mm-dd")#T#timeFormat(timeVars.utcNowTime, "HH:mm:ss")#';
		</cfscript>

		<cfreturn timeVars>
	</cffunction>


	<cffunction name="jsonEncode" returntype="string" output="false" hint="Converts data from CF to JSON format the proper way, serializeJSON is crap in CF.">
	    <cfargument name="data" type="any" required="Yes">
	    <cfargument name="queryFormat" type="string" required="false" default="query">
	    <cfargument name="queryKeyCase" type="string" required="false" default="lower">
	    <cfargument name="stringNumbers" type="boolean" required="false" default="false">
	    <cfargument name="formatDates" type="boolean" required="false" default="false">
	    <cfargument name="columnListFormat" type="string" required="false" default="string">

	    <cfset var jsonString = "">
	    <cfset var tempVal = "">
	    <cfset var arKeys = "">
	    <cfset var colPos = 1>
	    <cfset var i = 1>
	    <cfset var column = "">
	    <cfset var datakey = "">
	    <cfset var recordcountkey = "">
	    <cfset var columnlist = "">
	    <cfset var columnlistkey = "">
	    <cfset var dJSONString = "">
	    <cfset var escapeToVals = "\\,\"",\/,\b,\t,\n,\f,\r">
	    <cfset var escapeVals = "\,"",/,#Chr(8)#,#Chr(9)#,#Chr(10)#,#Chr(12)#,#Chr(13)#">
		<cfset var _data = arguments.data>

	    <!--- BOOLEAN --->
	    <cfif IsBoolean(_data) AND NOT IsNumeric(_data) AND NOT ListFindNoCase("Yes,No", _data)>
	        <cfreturn LCase(ToString(_data))>

	    <!--- NUMBER --->
	    <cfelseif NOT stringNumbers AND IsNumeric(_data) AND NOT REFind("^0+[^\.]",_data)>
	        <cfreturn ToString(_data)>

	    <!--- DATE --->
	    <cfelseif IsDate(_data) AND arguments.formatDates>
	        <cfreturn '"#DateFormat(_data, "medium")# #TimeFormat(_data, "medium")#"'>

	    <!--- STRING --->
	    <cfelseif IsSimpleValue(_data)>
	        <cfreturn '"' & ReplaceList(_data, escapeVals, escapeToVals) & '"'>

	    <!--- ARRAY --->
	    <cfelseif IsArray(_data)>
	        <cfset dJSONString = createObject('java','java.lang.StringBuffer').init("")>
	        <cfloop from="1" to="#ArrayLen(_data)#" index="i">
	            <cfset tempVal = jsonencode( _data[i], arguments.queryFormat, arguments.queryKeyCase, arguments.stringNumbers, arguments.formatDates, arguments.columnListFormat )>
	            <cfif dJSONString.toString() EQ "">
	                <cfset dJSONString.append(tempVal)>
	            <cfelse>
	                <cfset dJSONString.append("," & tempVal)>
	            </cfif>
	        </cfloop>

	        <cfreturn "[" & dJSONString.toString() & "]">

	    <!--- STRUCT --->
	    <cfelseif IsStruct(_data)>
	        <cfset dJSONString = createObject('java','java.lang.StringBuffer').init("")>
	        <cfset arKeys = StructKeyArray(_data)>
	        <cfloop from="1" to="#ArrayLen(arKeys)#" index="i">
	            <cfset tempVal = jsonencode( _data[ arKeys[i] ], arguments.queryFormat, arguments.queryKeyCase, arguments.stringNumbers, arguments.formatDates, arguments.columnListFormat )>
	            <cfif dJSONString.toString() EQ "">
	                <cfset dJSONString.append('"' & arKeys[i] & '":' & tempVal)>
	            <cfelse>
	                <cfset dJSONString.append("," & '"' & arKeys[i] & '":' & tempVal)>
	            </cfif>
	        </cfloop>

	        <cfreturn "{" & dJSONString.toString() & "}">

	    <!--- QUERY --->
	    <cfelseif IsQuery(_data)>
	        <cfset dJSONString = createObject('java','java.lang.StringBuffer').init("")>

	        <!--- Add query meta data --->
	        <cfif arguments.queryKeyCase EQ "lower">
	            <cfset recordcountKey = "recordcount">
	            <cfset columnlistKey = "columnlist">
	            <cfset columnlist = LCase(_data.columnlist)>
	            <cfset dataKey = "data">
	        <cfelse>
	            <cfset recordcountKey = "RECORDCOUNT">
	            <cfset columnlistKey = "COLUMNLIST">
	            <cfset columnlist = _data.columnlist>
	            <cfset dataKey = "data">
	        </cfif>

	        <cfset dJSONString.append('"#recordcountKey#":' & _data.recordcount)>
	        <cfif arguments.columnListFormat EQ "array">
	            <cfset columnlist = "[" & ListQualify(columnlist, '"') & "]">
	            <cfset dJSONString.append(',"#columnlistKey#":' & columnlist)>
	        <cfelse>
	            <cfset dJSONString.append(',"#columnlistKey#":"' & columnlist & '"')>
	        </cfif>
	        <cfset dJSONString.append(',"#dataKey#":')>

	        <!--- Make query a structure of arrays --->
	        <cfif arguments.queryFormat EQ "query">
	            <cfset dJSONString.append("{")>
	            <cfset colPos = 1>

	            <cfloop list="#_data.columnlist#" delimiters="," index="column">
	                <cfif colPos GT 1>
	                    <cfset dJSONString.append(",")>
	                </cfif>
	                <cfif arguments.queryKeyCase EQ "lower">
	                    <cfset column = LCase(column)>
	                </cfif>
	                <cfset dJSONString.append('"' & column & '":[')>

	                <cfloop from="1" to="#_data.recordcount#" index="i">
	                    <!--- Get cell value; recurse to get proper format depending on string/number/boolean data type --->
	                    <cfset tempVal = jsonencode( _data[column][i], arguments.queryFormat, arguments.queryKeyCase, arguments.stringNumbers, arguments.formatDates, arguments.columnListFormat )>

	                    <cfif i GT 1>
	                        <cfset dJSONString.append(",")>
	                    </cfif>
	                    <cfset dJSONString.append(tempVal)>
	                </cfloop>

	                <cfset dJSONString.append("]")>

                <cfset colPos = colPos + 1>
            </cfloop>
            <cfset dJSONString.append("}")>
	        <!--- Make query an array of structures --->
	        <cfelse>
	            <cfset dJSONString.append("[")>
	            <cfloop query="_data">
	                <cfif CurrentRow GT 1>
	                    <cfset dJSONString.append(",")>
	                </cfif>
	                <cfset dJSONString.append("{")>
	                <cfset colPos = 1>
	                <cfloop list="#columnlist#" delimiters="," index="column">
	                    <cfset tempVal = jsonencode( _data[column][CurrentRow], arguments.queryFormat, arguments.queryKeyCase, arguments.stringNumbers, arguments.formatDates, arguments.columnListFormat )>

	                    <cfif colPos GT 1>
	                        <cfset dJSONString.append(",")>
	                    </cfif>

	                    <cfif arguments.queryKeyCase EQ "lower">
	                        <cfset column = LCase(column)>
	                    </cfif>
	                    <cfset dJSONString.append('"' & column & '":' & tempVal)>

	                    <cfset colPos = colPos + 1>
	                </cfloop>
	                <cfset dJSONString.append("}")>
	            </cfloop>
	            <cfset dJSONString.append("]")>
	        </cfif>

	        <!--- Wrap all query data into an object --->
	        <cfreturn "{" & dJSONString.toString() & "}">

	    <!--- FUNCTION --->
	    <cfelseif listFindNoCase(StructKeyList(getFunctionList()), _data) OR isDefined(_data) AND evaluate("IsCustomFunction(#_data#)")>
	    	<cfreturn '"' & "function()" & '"'>

	    <!--- UNKNOWN OBJECT TYPE --->
	    <cfelse>
	        <cfreturn '"' & "unknown-obj" & '"'>
	    </cfif>
	</cffunction>


	<cffunction name="hmac_sha1" returntype="string" output="false" hint="HMAC SHA1 signing function.">
	   <cfargument name="signKey" type="string" required="true">
	   <cfargument name="signMessage" type="string" required="true">

	   <cfset var jMsg = JavaCast("string",arguments.signMessage).getBytes("iso-8859-1")>
	   <cfset var jKey = JavaCast("string",arguments.signKey).getBytes("iso-8859-1")>

	   <cfset var key = createObject("java","javax.crypto.spec.SecretKeySpec")>
	   <cfset var mac = createObject("java","javax.crypto.Mac")>

	   <cfset key = key.init(jKey,"HmacSHA1")>

	   <cfset mac = mac.getInstance(key.getAlgorithm())>
	   <cfset mac.init(key)>
	   <cfset mac.update(jMsg)>

	   <cfreturn lcase(binaryEncode(mac.doFinal(), 'hex'))>
	</cffunction>

</cfcomponent>
