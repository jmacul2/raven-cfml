raven-cfml
==========

raven-cfml is an experimental CFML client for `Sentry <http://aboutsentry.com/>`_.

Installation
------------

Install source from GitHub
~~~~~~~~~~~~~~~~~~~~~~~~~~

To install the source code:

::

    $ git clone git://github.com/jmacul2/raven-cfml.git

And instantiate the object:

::

    <cfset ravenConfig = structNew()>
    <cfset ravenConfig.publicKey = "[your_public_key]">
    <cfset ravenConfig.privateKey = "[your_private_key]">
    <cfset ravenConfig.sentryUrl = "[http://sentry_url]">
    <cfset ravenConfig.projectID = [numeric_project_id]>
    <cfset ravenClient = createObject('component', '[path.to.raven].lib.client').init(argumentCollection=ravenConfig)>

Usage
-----

Using Application.cfc
~~~~~~~~~~~~~~~~~~~~~

::

   <cffunction name="OnError" access="public" returntype="void" output="false">
      <cfargument name="exception" type="any" required="true">
      <cfargument name="eventName" type="string" required="false" default="">
   
      <cfset ravenClient.captureException(exception)>
   
   </cffunction>


Inside a CFML Page
~~~~~~~~~~~~~~~~~~

::

   <cftry>
      <!--- Code to execute --->

      <cfcatch>
         <!--- Capture a exception --->
         <cfset ravenClient.captureException(cfcatch)>
      
         <!--- Capture a message --->
         <cfset ravenClient.captureException("This is a message.")>
      </cfcatch>
   </cftry>
   
Threading
~~~~~~~~~

It maybe helpful to wrap the capture calls inside cfthread to isolate the api
call to sentry for performance.

::

   <cftry>
      <!--- Code to execute --->

      <cfcatch>
         <cfthread action="run" name="ravenThread" exception="#cfcatch#" cgiVars="#CGI#" httpRequestData="#getHttpRequestData()#">
            <cfset ravenConfig = structNew()>
            <cfset ravenConfig.publicKey = "[your_public_key]">
            <cfset ravenConfig.privateKey = "[your_private_key]">
            <cfset ravenConfig.sentryUrl = "[http://sentry_url]">
            <cfset ravenConfig.projectID = [numeric_project_id]>
            <cfset ravenConfig.cgiVars = cgiVars>
            <cfset ravenConfig.httpRequestData = httpRequestData>
            <cfset ravenClient = createObject('component', '[path.to.raven].lib.client').init(argumentCollection=ravenConfig)>
                  
            <cfset ravenClient.captureException(cfcatch)>
         </cfthread>
      </cfcatch>
   </cftry>

Resources
---------

* `Bug Tracker <http://github.com/jmacul2/raven-cfml/issues>`_
* `Code <http://github.com/jmacul2/raven-cfml>`_