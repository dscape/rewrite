# rewrite

The purpose of `rewrite` is to eliminate the 1-to-1 mapping between files and MarkLogic App Servers by introducing an intermediate layer that recognizes URLs and dispatches them to application code.

This way you can map a route like `/users/17` to an internal file uri like `/users.xqy?action=show&id=17`.

The way we define the routes is with a XML domain specific language (DSL) intended to make routing logic simple and easy to maintain:

      <routes>
        <root> users#list </root>
        <get path="/users/:id">
          <to> users#show </to>
        </get>
      </routes>

This project also allows you to make security part of this process by introducing XQuery constraints in the DSL.

`rewrite` is designed to work with [MarkLogic][2] Server only. However it can easily be ported to another product that understands XQuery and has similar capabilities.

`rewrite` is heavily inspired in the [Rails 3.0 routing][4]. For a brief introduction to how rewriting works in MarkLogic please refer to MarkLogic's official guide on [Setting Up URL Rewriting for an HTTP App Server][11]

## Basics

`rewrite` algorithm is:

1. Check the routes that match a specific request
2. Get the first that matched and redirect according to the rule
3. If none matched redirect to a directory with static files. This way you can still serve your css and javascript files by placing them in the /static/ directory.

Routes are matched in the order they are specified, so if you have these routes:

     <routes>
       <get path="/:user">
       <get path="/about">
     </routes>

the get route for the `/:user` will be matched before the get `/about`. To fix this, move the `/about` line above the `:user` so that it is matched first:

     <routes>
       <get path="/about">
       <get path="/:user">
     </routes>

## Usage

Start by creating an HTTP Application Server in MarkLogic. Put `rewrite.xqy` in the `rewrite` input.

In your application `root` folder place a file named `rewrite.xqy` with the following contents:

     xquery version "1.0-ml" ;
     
     (: assuming you stored the routes.xqy library in /lib/ :)
     import module namespace r = "routes.xqy" at "/lib/routes.xqy" ;
     
     declare variable $routesCfg := 
       <routes>
         <root> users#list </root>
         <get path="/users/:id">
           <to> users#show </to>
         </get>
       </routes> ;
     
     declare variable $pathsCfg :=
       <paths>
         <resourceDirectory>/</resourceDirectory>
         <xqyExtension>xq</xqyExtension>
         <staticDirectory>/public/</staticDirectory>
         <redirect>dispatcher</redirect>
       </paths> ;
     
     r:selectedRoute( $routesCfg, $pathsCfg )

If you do a request against your server for `/` your will de redirected to `/users.xqy?action=list`. If you request `/users/dscape` you will be dispatched to `/users.xqy?action=show&id=dscape`.

If you want to save your routing & path configuration in a file you can use the [xdmp:document-get][9] function to retrieve the file:

     xquery version "1.0-ml" ;
     
     import module namespace r = "routes.xqy" at "/lib/routes.xqy" ;
     
     declare function local:documentGet( $path ) { 
       xdmp:document-get( fn:concat( xdmp:modules-root(), $path ) ) } ;
     
     declare variable $routesCfg := 
       local:documentGet( "config/routes.xml" ) ;
     
     r:selectedRoute( $routesCfg )

You're done. Check "Supported Features" for a description of what the `routes.xml` file translates to. 

Just don't forget to create your resource XQuery files. Here's an example of how your `users.xqy` might look like:

     xquery version "1.0-ml";
     
     import module namespace u = "user.xqy" at "/lib/user.xqy";
     import module namespace h = "helper.xqy" at "/lib/helper.xqy";
     
     declare function local:list() { u:list() };
     declare function local:get()  { u:get( h:id() ) } ;
     
     try          { xdmp:apply( h:function() ) } 
     catch ( $e ) { h:error( $e ) }

This assumes a hypothetical `users.xqy` file that actually does the work of listing users and retrieving information about a user. 

It also contains a `helper.xqy` module. The `helper.xqy` module is contained in lib as an example but is not part of `rewrite`, so you can/should modify it to fit your needs or even create your fully fledged [MVC][10] framework.

This section doesn't cover how to set up an HTTP Application Server in MarkLogic. If you are a beginner I suggest you start by browsing the [MarkLogic Developer Community site][7] or sign up for some [training][8].

## paths.xml
You can use a `paths.xml` file to override the defaults for:

1. Resource path (which defaults to /resource/), 
2. xqy extension (which defaults to xqy)
3. Static path (defaults to /static/). 
4. Redirect resource name (defaults to redirect)

To do so you can simply call the `r:selectedRoute\2` function:

     r:selectedRoute( $routesCfg, $defaultCfg )

Here's an example of what a `paths.xml` might look like:

     <paths>
       <resourceDirectory>/lib/</resourceDirectory>
       <xqyExtension>xq</xqyExtension>
       <staticDirectory>/public/</staticDirectory>
       <redirect>dispatcher</redirect>
     </paths>

## Sample Application

Not yet. Include redirect-to because it can't be proven without an extra file.

## Supported Functionality

In this section we describe the DSL that you can use to map your routes
to where they should be dispatched. This is meant to give you overall understanding of the functionality without having to read the code.

### 1. Routes

###  ✔ 1.1. root 
     Request       : GET /
     routes.xml    : <routes> <root> server#version </root> </routes> 
     Dispatches to : /resource/server.xqy?action=ping

###  ✔ 1.2. verbs
Let's start by defining some properties that are common amongst all verbs: get, put, post, delete, and head.

### 1.2.1.1. dynamic paths
If you think about a website like twitter.com the first level path is given to users, e.g. `twitter.com/dscape`. This means that we need to route all our first levels display user information.

`rewrite` exposes that functionality with dynamic paths. For the twitter example we would have something like:

     Request       : GET /dscape
     routes.xml    : <routes> 
                       <get path="/:user">
                         <to> user#get </to>
                       </get>
                     </routes>
     Dispatches to : /resource/user.xqy?action=get&user=dscape

The colon in `:user` lets the routing algorithm know that `:user` shouldn't be evaluated as a string but rather as a dynamic resource. You can even combine dynamic resources with static paths:

     Request       : GET /user/dscape
     routes.xml    : <routes> 
                       <get path="/user/:id">
                         <to> user#get </to>
                       </get>
                     </routes>
     Dispatches to : /resource/user.xqy?action=get&id=dscape

###  1.2.1.2. bound parameters
There are two symbols that are special `:resource` maps to the name of a controller in your application, and `:action` maps to the name of an action within that controller. When you supply both in a route it will be evaluated by calling that action on the specified resource. Everything else will be passed as field values and can be retrieve by invoking the [xdmp:get-request-field][12] function.

The following example is a route with bound parameters that will match `/users/get/1` to resource `users`, action `get`, id `1`:

     Request       : GET /users/get/1
     routes.xml    : <routes> 
                       <get path="/:resource/:action/:id"/>
                     </routes>
     Dispatches to : /resource/users.xqy?action=get&id=1

###  1.2.1.3 redirect-to
You can specify a redirect by using the `redirect-to` element inside your route:

     Request       : GET /google
     routes.xml    : <routes> 
                       <get path="/google">
                         <redirect-to> http://www.google.com </redirect-to> 
                       </get>
                     </routes>
     paths.xml     : <paths>
                       <resourceDirectory>/</resourceDirectory>
                       <redirect>dispatcher</redirect>
                     </paths>
     Dispatches to : /dispatcher.xqy?url=http%3a//www.google.com

The `rewriter` script cannot process re-directs natively in MarkLogic Server 4.2, as the output of any rewrite script must be a xs:string.

The current implementation of `rewrite` sends all redirects to a `redirect` dispatcher with an url-encoded option `url` that contains the url. 

The dispatcher can have any logic you like. Here is an example of a possible `redirect.xqy` dispatcher:

     let $url := xdmp:get-request-field( "url" )
     return if ( $url )
            then xdmp:redirect-response( xdmp:url-decode( $url ) )
            else fn:error()

If you are using `redirect-to` don't forget to place a `redirect.xqy` in the resource directory. If you don't you will start to get 404 errors every-time a user tries to do a redirect.

###  ✔ 1.2.2. get 
     Request       : GET /list
     routes.xml    : <routes> 
                       <get path="/list"> <to> article#list </to> </get>
                     </routes>
     Dispatches to : /resource/article.xqy?action=list

###  ✔ 1.2.3. put 
     Request       : PUT /upload
     routes.xml    : <routes>
                       <put path="/upload"> <to> file#upload </to> </put>
                     </routes>
     Dispatches to : /resource/file.xqy?action=upload

###  ✔ 1.2.4. post
     Request       : POST /upload
     routes.xml    : <routes>
                       <post path="/upload"> <to> file#upload </to> </post>
                     </routes>
     Dispatches to : /resource/file.xqy?action=upload

###  ✔ 1.2.5. delete 
     Request       : DELETE /all-dbs
     routes.xml    : <routes>
                       <delete path="/all-dbs"> 
                         <to> database#delete-all </to>
                       </delete>
                     </routes>
     Dispatches to : /resource/database.xqy?action=delete-all

###  ✔ 1.2.6. head 
     Request       : HEAD /
     routes.xml    : <routes> <head> <to> server#ping </to> </head> </routes>
     Dispatches to : /resource/server.xqy?action=ping

###  ✔ 1.3. resources
It's often the case when you want to perform all CRUD (Create, Read, Update, Delete) actions on a single resource, e.g. you want to create, read, update and delete users. RESTful architectures normally map those actions to HTTP verbs such as GET, PUT, POST and DELETE.

When you create a resource in `rewrite` you expose these actions:

<table>
  <tr>
    <th>Verb</th>
    <th>Path</th>
    <th>Action</th>
    <th>Used in</th>
    <th>Notes</th>
  </tr>
  <tr>
    <td>GET</td>
    <td>/users</td>
    <td>index</td>
    <td>Web-Services, Web-Applications</td>
    <td>Displays a list of all users</td>
  </tr>
  <tr>
    <td>GET</td>
    <td>/users/:id</td>
    <td>get</td>
    <td>Web-Services, Web-Applications</td>
    <td>Display information about a specific user</td>
  </tr>
  <tr>
    <td>PUT</td>
    <td>/users/:id</td>
    <td>put</td>
    <td>Web-Services, Web-Applications</td>
    <td>Creates or updates a user</td>
  </tr>
  <tr>
    <td>DELETE</td>
    <td>/users/:id</td>
    <td>delete</td>
    <td>Web-Services, Web-Applications</td>
    <td>Deletes a user</td>
  </tr>
  <tr>
    <td>POST</td>
    <td>/users</td>
    <td>post</td>
    <td>Web-Applications</td>
    <td>No special meaning</td>
  </tr>
  <tr>
    <td>GET</td>
    <td>/users/new</td>
    <td>new</td>
    <td>Web-Applications</td>
    <td>Return a form for creating a user.</td>
  </tr>
  <tr>
    <td>GET</td>
    <td>/users/:id/edit</td>
    <td>edit</td>
    <td>Web-Applications</td>
    <td>Return a form for editing the user.</td>
  </tr>
</table>

By default post, new and edit actions are created. If you are creating a web-service and have no interest in them you can change this behavior by simply passing a `webservice="true"` attribute to the resources specification.

The following example explains a single match against one of the multiple routes a resource creates. Please explore further examples (or try it out yourself) if you want to have a better understanding of resources.

     Request       : PUT /users/1
     routes.xml    : <routes> 
                       <resources name="users" webservice="true"/> 
                     </routes>
     Dispatches to : /resource/users.xqy?action=put&id=1

### 1.3.1. includes
Resources are really great cause they save you all the trouble of writing all those routes all the time (especially when order matters and you have to make sure you get it right).

### 1.3.1.1. member
Sometimes you will need to include one or more actions that are not part of the default resource, e.g. you might want to create a enable or disable one of your users. 

For this you need the resource to respond to `PUT /users/dscape/enabled` and understand that should re-enable the user. This action runs against a specific user - that's why we call it `member` include. Here's an example of how you can express that in `rewrite`:

     Request       : PUT /users/dscape/enabled
     routes.xml    : <routes> 
                       <resources name="users">
                         <member action="enabled" for="PUT,DELETE"/>
                       </resources>
                     </routes>
     Dispatches to : /resource/users.xqy?action=enabled&id=dscape

If you are curious about the DELETE - it's simply there to allow you to disable a user the RESTful way. If you don't pass the `for` attribute then  GET will be the default.

###  1.3.1.2. set
Another type of action you might need to add are global actions, e.g. searching all users in full text. 

We call this a set include and express it as follows:

     Request       : PUT /users/search?q=foo
     routes.xml    : <routes> 
                       <resources name="users">
                         <member action="enabled" for="PUT,DELETE"/>
                         <set action="search"/>
                       </resources>
                     </routes>
     Dispatches to : /resource/users.xqy?action=search&q=foo

Member and set includes are not exclusive of each other and you can use as many as you want in your resources.

###  ✔ 1.4. resource
Some resource only expose a single item, e.g. your about page. While you might want to be able to perform CRUD actions on a about page there is only one about page so using `resources` (plural) would be useless.

When you create a `resource` in `rewrite` you expose these actions:

<table>
  <tr>
    <th>Verb</th>
    <th>Path</th>
    <th>Action</th>
    <th>Used in</th>
    <th>Notes</th>
  </tr>
  <tr>
    <td>GET</td>
    <td>/about</td>
    <td>get</td>
    <td>Web-Services, Web-Applications</td>
    <td>Display about section</td>
  </tr>
  <tr>
    <td>PUT</td>
    <td>/about</td>
    <td>put</td>
    <td>Web-Services, Web-Applications</td>
    <td>Creates or updates the about section</td>
  </tr>
  <tr>
    <td>DELETE</td>
    <td>/about</td>
    <td>delete</td>
    <td>Web-Services, Web-Applications</td>
    <td>Deletes the about section</td>
  </tr>
  <tr>
    <td>POST</td>
    <td>/about</td>
    <td>post</td>
    <td>Web-Applications</td>
    <td>No special meaning</td>
  </tr>
  <tr>
    <td>GET</td>
    <td>/about/edit</td>
    <td>edit</td>
    <td>Web-Applications</td>
    <td>Return a form to create/edit the about section</td>
  </tr>
</table>

By default post, and edit actions are created. If you are creating a web-service and have no interest in them you can change this behavior by simply passing a `webservice="true"` attribute to the resources specification.

The following example illustrates a resource:

     Request       : GET /about
     routes.xml    : <routes> 
                       <resource name="about"/> 
                     </routes>
     Dispatches to : /resource/about.xqy?action=get

### 1.4.1. dynamic resource
As with `get`, `put`, etc, you can also create a dynamic resource by prefixing the name with `:`. Here's an example of using this to create a database:

     Request       : PUT /documents
     routes.xml    : <routes> 
                       <resource name=":database"/> 
                     </routes>
     Dispatches to : /resource/database.xqy?action=put&database=Documents

### 1.4.2. member

      Request       : PUT /car/ignition
      routes.xml    : <routes> 
                        <resources name="car">
                          <include action="ignition" for="PUT,DELETE"/>
                        </resources>
                      </routes>
      Dispatches to : /resource/users.xqy?action=ignition

### 2. Extras

###  ✔ 2.1. mixed paths
     Request       : GET /user/43
     routes.xml    : <routes> 
                       <get path="/user/:id">
                         <to> user#show </to>
                       </get>
                     </routes>
     Dispatches to : /resource/user.xqy?action=show&id=43

###  ✔ 2.2. static
If no match is found `rewrite` will dispatch your query to a /static/ folder where you should keep all your static files. This way you don't have to create routing rules for static files.

     Request       : GET /css/style.css
     routes.xml    : <routes> <root> server#version </root> </routes> 
     Dispatches to : /static/css/style.css

###  ✕ 2.3. constraints

### 2.3.1 bound parameters
When you bound parameters you sometime need to validate that they are valid. For our twitter example we would want to validate that `dscape` is indeed a proper `:user` using a [regular expression][13]. In a simpler case you might want to check that an `:id` is a decimal number.

### 2.3.2 permissions

### 2.3.3. xquery lambdas
The most flexible way of ensuring constraints is to run an XQuery lambda function. An example usage for a lambda in a contraint would be:

1. Only show the user information that pertains to the currently logged-in user

###  ✕ content negotiation and other mvc goodies
Content negotiations and other MVC goodies are deliberately not bundled in `rewrite`. 

The objective of `rewrite` is to simplify the mapping between external URLs and internal file paths. If you are curious about content negotiation and other topics you can look at some of my on-going work at the [dxc][5] project.

For example, this is how content negotiation is currently implemented in the [http.xqy][6] library:

     (: uses a default content type, no 406 errors :)
     declare function local:negotiateContentType( $accept, 
       $supported-content-types, $default-content-type ) {
       let $ordered-accept-types :=
         for $media-range in fn:tokenize($accept, "\s*,\s*")
              let $l := fn:tokenize($media-range, "\s*;\s*")
              let $type   := $l [1]
              let $params := fn:subsequence($l, 2)
              let $quality := (for $p in $params
                              let $q-or-ext := fn:tokenize($p, "\s*=\s*") 
                              where $q-or-ext [1] = "q"
                              return fn:number($q-or-ext[2]), 1.0) [1]
              order by $quality descending
              return $type
       return (for $sat in $ordered-accept-types
                let $match := (for $sct in $supported-content-types
                where fn:matches($sct, fn:replace($sat, "\*", ".*"))
                return $sct) [1]
                return $match, $default-content-type) [1] } ;

For your convenience this (and some other) functions that might be necessary to run an application with `rewrite` have be placed in the `/lib/helper.xqy` library.

## Contribute

Everyone is welcome to contribute. 

1. Fork rewrite in github
2. Create a new branch - `git checkout -b my-branch`
3. Test your changes
4. Commit your changes
5. Push to your branch - `git push origin my-branch`
6. Create an pull request

The documentation is severely lacking. Feel free to contribute to the wiki if 
you think something could be improved.

### Running the tests

To run the tests simply point an MarkLogic HTTP AppServer to the root of `rewrite`

You can run the tests by accessing:
(assuming 127.0.0.1 is the host and 8090 is the port)

    http://127.0.0.1:8090/test/

Make sure all the tests pass before sending in a pull request!

### Report a bug

If you want to contribute with a test case please file a [issue][1] and attach 
the following information:

* Request Method
* Request Path
* routes.xml
* Request Headers (if relevant)
* paths.xml (if relevant)

This will help us be faster fixing the problem.

This is not the actual test that we run (you can see a list of those in test/index.html) but it's all the information we need from a bug report.

## Roadmap

If you are interested in any of these (or other) feature and don't want to wait just read the instructions on "Contribute" and send in your code. I'm also very inclined to implement these features myself so it might be that a simple email is enough to motivation for me to get it done.

* Generating Paths and URLs from code
* Make singular resources map to plural controllers
* Extend constraints for <resource/>
* Translated Paths
* Route Globbing
* Namespaces & Scopes, e.g. /admin/user/1/edit
* Nested Resources
* Restricting Resource(s) Routes

### Known Limitations

In this section we have the know limitations:

### Dynamic paths

When using dynamic paths it is impractical to keep separate files for each user you have. So in the `/:user` example you map them to `user.xqy` and pass the username as a parameter, e.g. `user.xqy?user=dscape`. 

Please keep this in mind when developing your web applications. Other request fields can have the same name and your users can even inject fields, e.g. `user.xqy?user=dscape&user=hkstirman`. This framework will always give you the dynamic path as the first parameter so a safe way of avoiding people tampering with your logic is to get the first field only:

     xdmp:get-request-field( 'user' ) [1]

In the `user.xqy?user=dscape&user=hkstirman` this would return:

     dscape

On previous versions of `rewrite` dynamic paths where prefixed by `_`, so `user` would be `_user`. I choose to make it explicit so people stumble upon it faster and realize they still need to carefully protect themselves against  hacks like this.

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