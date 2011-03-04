# rewrite
`rewrite` is an implementation of [MarkLogic's URL Rewriter for HTTP Application Servers][11]. `rewrite` aims to provide an expressive language that allows you to specify REST applications. This is intended to make your routing logic simple and easy to maintain:

      <routes>
        <root> dashboard#show </root> 
        <resource name="inbox"> <!-- no users named inbox --> 
          <member action="sent"/> 
        </resource> 
        <resource name=":user"> 
          <constraints>  
            <user type="string" match="^[a-z]([a-z]|[0-9]|_|-)*$"/> 
          </constraints> 
          <member action="followers"/> <!-- no repo named followers --> 
          <resource name=":repo"> 
            <constraints>  
              <repo match="^[a-z]([a-z]|[0-9]|_|-|\.)*$"/> 
            </constraints> 
            <member action="commit/:commit"> 
              <constraints>  
                <commit type="string" match="[a-zA-Z0-9]+"/> 
              </constraints> 
            </member> 
            <member action="tree/:tag" /> 
            <member action="forks" /> 
            <member action="pulls" /> 
            <member action="graphs/impact" /> 
            <member action="graphs/language" /> 
          </resource> 
        </resource>
      </routes>

Routes are [matched in the order you specified][17] and they can be [nested][18]. Then they are dispatched to a action according to what's described in [Mapping to Function][26]. `rewrite` also enables you to hide specific routes from users given specific constraints.

`rewrite` is designed to work with [MarkLogic][2] Server only. However it can easily be ported to another product that understands XQuery and has similar capabilities. `rewrite` is heavily inspired in the [Rails 3.0 routing][4].

## Usage

In your HTTP Application Server configuration make `rewrite.xqy` the default rewriter script.

*This section doesn't cover how to set up an HTTP Application Server in MarkLogic. If you are a beginner I suggest you start by browsing the [MarkLogic Developer Community site][7] or sign up for [training][8].*

Place the `lib` folder of `rewrite` in your application `root`. Still in the `root`  create a new file named `rewrite.xqy` with the following contents:

     xquery version "1.0-ml" ;
     
     import module namespace r = "routes.xqy" at "/lib/routes.xqy" ;
     
     declare variable $routesCfg := 
       <routes>
         <root> users#list </root>
         <get path="users/:id">
           <to> users#show </to>
         </get>
       </routes> ;
     
     r:selectedRoute( $routesCfg )

Now with the `rewrite` in place:

* Request `/` will be dispatched to `/resource/users.xqy?action=list`
* Request `/users/dscape`  will be dispatched to `/resource/users.xqy?action=show&id=dscape`

You can [customize the file path][19] and / or  [store configurations in a file][20]. If you are curious on how the translation from path to file is done refer to "Supported Features". 

Here's an example of how your `users.xqy` might look like:

     xquery version "1.0-ml";
     
     import module namespace u = "user.xqy" at "/lib/user.xqy";
     import module namespace h = "helper.xqy" at "/lib/helper.xqy";
     
     declare function local:list() { u:list() };
     declare function local:get()  { u:get( h:id() ) } ;
     
     try          { xdmp:apply( h:function() ) } 
     catch ( $e ) { h:error( $e ) }

A centralized [error handler][14] can also be used removing the need for a `try catch` statement. Refer to the wiki section on [using an error handler][21] for instructions.

*This assumes a hypothetical `users.xqy` XQuery library that actually does the work of listing users and retrieving information about a user. It also contains a `helper.xqy` module. The `helper.xqy` module is contained in lib as an example but is not part of `rewrite`, so you can/should modify it to fit your needs; or even create your fully fledged [MVC][10] framework.*

## Sample Application

Not yet. Include redirect-to because it can't be proven without an extra file. Include errors.xqy as well!

## Supported Functionality

In this section we describe the rules that you can use to map your routes
to where they should be dispatched. This is meant to give you overall understanding of the functionality without having to read the code.

<table>
  <tr>
    <th>Element</th>
    <th>Type</th>
    <th>Meaning</th>
    <th>More Info</th>
  </tr>
  <tr>
    <td>Root</td>
    <td>Route</td>
    <td>Responds to GET requests to the root of the application</td>
    <td>[Wiki][23]</td>
  </tr>
  <tr>
    <td>Get</td>
    <td>Route</td>
    <td>Responds to GET requests for a given path</td>
    <td>[Wiki][23]</td>
  </tr>
  <tr>
    <td>Put</td>
    <td>Route</td>
    <td>Responds to PUT requests for a given path</td>
    <td>[Wiki][23]</td>
  </tr>
  <tr>
    <td>Delete</td>
    <td>Route</td>
    <td>Responds to DELETE requests for a given path</td>
    <td>[Wiki][23]</td>
  </tr>
  <tr>
    <td>Post</td>
    <td>Route</td>
    <td>Responds to POST requests for a given path</td>
    <td>[Wiki][23]</td>
  </tr>
  <tr>
    <td>Head</td>
    <td>Route</td>
    <td>Responds to HEAD requests for a given path</td>
    <td>[Wiki][23]</td>
  </tr>
  <tr>
    <td>Resources</td>
    <td>Multiple Routes</td>
    <td>Creates a RESTful Resource addressable by :id</td>
    <td>[Wiki][24]</td>
  </tr>
  <tr>
    <td>Resource</td>
    <td>Multiple Routes</td>
    <td>Creates a singleton RESTful Resource</td>
    <td>[Wiki][25]</td>
  </tr>
  <tr>
    <td>Static Files</td>
    <td>Static</td>
    <td>Serving static files</td>
    <td>[Wiki][27]</td>
  </tr>
  <tr>
    <td>Constraints</td>
    <td>Constraint</td>
    <td>Makes rules invisible given constraints</td>
    <td>[Wiki][28]</td>
  </tr>
  <tr>
    <td>Scopes</td>
    <td>Scope</td>
    <td>Propagates environment, e.g. constraints.</td>
    <td>[Wiki][29]</td>
  </tr>
</table>

## Contribute

Everyone is welcome to contribute. 

1. Fork rewrite in github
2. Create a new branch - `git checkout -b my-branch`
3. Test your changes
4. Commit your changes
5. Push to your branch - `git push origin my-branch`
6. Create an pull request

### Running the tests

To run the tests simply point an MarkLogic HTTP AppServer to the root of `rewrite`

You can run the tests by accessing:
(assuming 127.0.0.1 is the host and 8090 is the port)

    http://127.0.0.1:8090/test/

**Make sure all the tests pass before sending in a pull request!**

### Report a bug

If you want to contribute with a test case please file a [issue][1] and attach 
the following information:

* Request method, request path, and other parts of the request that are relevant (e.g. request headers)
* routes.xml
* paths.xml (if relevant)

This will help us be faster fixing the problem.

This is not the actual test that we run (you can see a list of those in test/index.html) but it's all the information we need from a bug report.

## Roadmap

If you are interested in any of these (or other) feature and don't want to wait just read the instructions on "Contribute" and send in your code. I'm also very inclined to implement these features myself so it might be that a simple email is enough to motivation for me to get it done.

v0.1

* Improve read-me, re-factor all notes to wiki
* Sample app

v0.2

* Translated Paths for resources
* Generating Paths and URLs from code
* Route Globbing
* Namespaces, e.g. /admin/user/1/edit
* Make singular resources map to plural controllers
* Restricting Resource(s) Routes
* Make redirect-to flexible
* Allows bound constraints containing / in the values (test exists)
* Allow further customization of file path

### Known Limitations

In this section we have the know limitations:

* Bound parameters containing / are not supported.
* Nested Sections don't propagate constraints between levels.

## Meta

* Code: `git clone git://github.com/dscape/rewrite.git`
* Home: <http://github.com/dscape/rewrite>
* Discussion: <http://convore.com/marklogic>
* Bugs: <http://github.com/dscape/rewrite/issues>

(oO)--',- in [caos][3]

[1]: http://github.com/dscape/rewrite/issues
[2]: http://marklogic.com
[3]: http://caos.di.uminho.pt
[4]: http://edgeguides.rubyonrails.org/routing.html
[5]: http://github.com/dscape/dxc
[6]: https://github.com/dscape/dxc/blob/master/http/http.xqy#L27
[7]: http://developer.marklogic.com
[8]: http://www.marklogic.com/services/training.html
[9]: http://xqzone.marklogic.com/pubs/4.2/apidocs/Ext-7.html#xdmp:document-get
[10]: http://en.wikipedia.org/wiki/Model–View–Controller
[11]: http://docs.marklogic.com/4.2doc/docapp.xqy#display.xqy?fname=http://pubs/4.2doc/xml/dev_guide/appserver-control.xml%2313050
[12]: http://developer.marklogic.com/pubs/4.2/apidocs/AppServerBuiltins.html#xdmp:get-request-field
[13]: http://en.wikipedia.org/wiki/Regular_expression
[14]: http://docs.marklogic.com/4.2doc/docapp.xqy#display.xqy?fname=http://pubs/4.2doc/xml/dev_guide/appserver-control.xml
[15]: http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
[16]: http://www.w3.org/TR/xmlschema-2
[17]: https://github.com/dscape/rewrite/wiki/Routes-are-ordered
[18]: https://github.com/dscape/rewrite/wiki/Nested-Routes
[19]: https://github.com/dscape/rewrite/wiki/Customize-File-Path
[20]: https://github.com/dscape/rewrite/wiki/Loading-Configuration-from-Files
[21]: https://github.com/dscape/rewrite/wiki/Using-an-Error-Handler
[22]: https://github.com/dscape/rewrite/wiki/How-Verbs-Work
[23]: https://github.com/dscape/rewrite/wiki/Simple-Routes
[24]: https://github.com/dscape/rewrite/wiki/Resources
[25]: https://github.com/dscape/rewrite/wiki/Resource
[26]: https://github.com/dscape/rewrite/wiki/Mapping-to-Functions
[27]: https://github.com/dscape/rewrite/wiki/Static-Files
[28]: https://github.com/dscape/rewrite/wiki/Constraints
[29]: https://github.com/dscape/rewrite/wiki/Scopes