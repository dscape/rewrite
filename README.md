# rewrite

The purpose of `rewrite` is to eliminate the 1-to-1 mapping between files and MarkLogic App Servers by introducing a intermediate layer that recognizes URLs and dispatches them to application code.

This way you can map a easy to write route like `/users/17` to an internal file uri like `/users.xqy?action=show&id=17`.

The way we define the routes is with a XML domain specific language (DSL) for routing intended to make routing logic simple and easy to maintain:

      <routes>
        <root> users#list </root>
        <get path="/users/:id">
          <to> users#show </to>
        </get>
      </routes>

This project also tries to help you to make security part of this process by introducing XQuery constraints in the DSL.

`rewrite` is designed to work with [MarkLogic][2] Server only. However it can easily be ported to another product that understands XQuery and has similar capabilities.

`rewrite` is heavily inspired in the [Rails 3.0 routing][4].

## Basics

`rewrite` algorithm is:

1. Check the routes that match a specific request
2. Get the first that matched and redirect according to the rule
3. If none matched redirect to a directory with static files. This way you can still serve your css and javascript files by placing them in the /static/ directory.

Routes are matched in the order they are specified, so if you have a routes like this:

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

Not yet, hello world app

* Install
* Point app Server to rewrite
* Makes routes and supporting XQuery
* Done

Check features for a description of what the `routes.xml` file translates to. 

## paths.xml
You can use a `paths.xml` file to override the defaults for:

1. Resource path (which defaults to /resource/), 
2. xqy extension (which defaults to xqy)
3. Static path (defaults to /static/). 

To do so you can simply call the `r:selectedRoute\2` function:

     r:selectedRoute( $routesCfg, $defaultCfg )

Here's an example of what a `paths.xml` might look like:

     <paths>
       <resourceDirectory>/lib/</resourceDirectory>
       <xqyExtension>xq</xqyExtension>
       <staticDirectory>/public/</staticDirectory>
     </paths>

## Sample Application

Not yet.

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

Make sure all the tests pass before sending in your pull request!

### Report a bug

If you want to contribute with a test case please file a [issue][1] and attach 
the following information:

* Request Method
* Request Path
* routes.xml
* Request Headers (if relevant)
* paths.xml (if relevant)

This will help us be faster fixing the problem.

This is not the actual test that we run (you can see a list of those in test/index.html) but it's all the information we need for a bug report.

## Supported Functionality

In this section we describe the DSL that you can use to define your routes
and what is generated based on it.

### 1. Routes

####  ✔ 1.1. root 
     Request       : GET /
     routes.xml    : <routes> <root> server#version </root> </routes> 
     Dispatches to : /resource/server.xqy?action=ping

####  ✔ 1.2. verbs
Let's start by defining some properties that are common amongst all verbs: get, put, post, delete, and head.

#### 1.2.1.1. dynamic paths
If you think about website like twitter.com the first level path is given to users, e.g. `twitter.com/dscape`. This means that if no other route matches we need to route all our first levels display user information.

`rewrite` exposes that functionality with dynamic paths. For the twitter example we would have something like:

     Request       : GET /dscape
     routes.xml    : <routes> 
                       <get path="/:user">
                         <to> user#get </to>
                       </get>
                     </routes>
     Dispatches to : /resource/user.xqy?action=get&user=dscape

The colon in `:user` lets the routing algorithm know that it shouldn't be evaluated as a string but rather as a dynamic resource. You can even combine dynamic and static paths:

     Request       : GET /user/dscape
     routes.xml    : <routes> 
                       <get path="/user/:id">
                         <to> user#get </to>
                       </get>
                     </routes>
     Dispatches to : /resource/user.xqy?action=get&id=dscape

####  1.2.1.2. bound parameters
Two symbols are special `:resource` maps to the name of a controller in your application, and `:action` maps to the name of an action within that controller. When you supply both in a route it will be evaluated by calling that action on the specified resource. Everything else will be passed as field values and can be retrieve by invoking the `xdmp:get-request-value\1` function.

This is a route that will match `/users/get/1` to resource `users` action `get` id `1`:

     Request       : GET /users/get/1
     routes.xml    : <routes> 
                       <get path="/:resource/:action/:id"/>
                     </routes>
     Dispatches to : /resource/users.xqy?action=get&id=1

####  1.2.1.3 redirect-to
You can redirect any simple request by using the `redirect-to` element inside your route.

####  ✔ 1.2.2. get 
     Request       : GET /list
     routes.xml    : <routes> 
                       <get path="/list"> <to> article#list </to> </get>
                     </routes>
     Dispatches to : /resource/article.xqy?action=list

####  ✔ 1.2.3. put 
     Request       : PUT /upload
     routes.xml    : <routes>
                       <put path="/upload"> <to> file#upload </to> </put>
                     </routes>
     Dispatches to : /resource/file.xqy?action=upload

####  ✔ 1.2.4. post
     Request       : POST /upload
     routes.xml    : <routes>
                       <post path="/upload"> <to> file#upload </to> </post>
                     </routes>
     Dispatches to : /resource/file.xqy?action=upload

####  ✔ 1.2.5. delete 
     Request       : DELETE /all-dbs
     routes.xml    : <routes>
                       <delete path="/all-dbs"> 
                         <to> database#delete-all </to>
                       </delete>
                     </routes>
     Dispatches to : /resource/database.xqy?action=delete-all

####  ✔ 1.2.6. head 
     Request       : HEAD /
     routes.xml    : <routes> <head> <to> server#ping </to> </head> </routes>
     Dispatches to : /resource/server.xqy?action=ping

####  ✔ 1.3. resources
So far all the features have been for handling a single case. However it's often the case when you want to perform all CRUD (Create, Read, Update, Delete) actions on a single resource, e.g. you want to create, read, update and delete users. RESTful architectures normally map those actions to HTTP verbs such as GET, PUT, POST and DELETE.

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

#### 1.3.1. includes
Resources are really great cause they save you all the trouble of writing all those routes all the same (especially when order matters and you have to make sure you get it right).

#### 1.3.1.1. member
Sometimes you will need to include one or more actions that are not part of the default, e.g. you might want to create a enable or disable one of your users. 

So you need the resource to respond to `PUT /users/dscape/enabled` and understand that should re-enable the user. This action runs against a specific user is that's why we call it member include. Here's an example of how you can express that in `rewrite`:

     Request       : PUT /users/dscape/enabled
     routes.xml    : <routes> 
                       <resources name="users">
                         <member action="enabled" for="PUT,DELETE"/>
                       </resources>
                     </routes>
     Dispatches to : /resource/users.xqy?action=enabled&id=dscape

If you are curious about the DELETE - it's simply there to allow you to disable a user the RESTful way. If you don't pass the `for` attribute then  GET will be created.

####  1.3.1.2. set
Another type of action you might ned to add are global actions, e.g. searching all users in full text. 

We call this a set include and express it as follows:

     Request       : PUT /users/search?q=foo
     routes.xml    : <routes> 
                       <resources name="users">
                         <member action="enabled" for="PUT,DELETE"/>
                         <set action="search"/>
                       </resources>
                     </routes>
     Dispatches to : /resource/users.xqy?action=search&q=foo

Member and set includes are not exclusive of each other and you can use as many as you want in your resources as you can see in the above example.

####  ✔ 1.4. resource
Some resource only expose a single item, e.g. your about page. While you might want to be able to perform CRUD actions on a about page there is only one about page so using resources would be useful.

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

The following example illustrate a resource

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

####  ✔ 2.1. mixed paths
     Request       : GET /user/43
     routes.xml    : <routes> 
                       <get path="/user/:id">
                         <to> user#show </to>
                       </get>
                     </routes>
     Dispatches to : /resource/user.xqy?action=show&id=43

####  ✔ 2.2. static
If no match is found `rewrite` will dispatch your query to a /static/ folder where you should keep all your static files. This way you don't have to create routing rules for static files.

     Request       : GET /css/style.css
     routes.xml    : <routes> <root> server#version </root> </routes> 
     Dispatches to : /static/css/style.css

####  ✔ 2.3. paths
By default the application will look for resources in `/resource/`, static in `/static/` and will use the `.xqy` extension for XQuery files. You can change this by providing a `paths.xml` file:

     Request       : GET /
     routes.xml    : <routes> <root> server#version </root> </routes> 
     paths.xml     : <paths> <resourceDirectory>/</resourceDirectory> </paths>
     Dispatches to : /server.xqy?action=ping


####  ✕ content negotiation
####  ✕ redirect
redirect to

####  ✕ constraints
You can run constraints against your routes to ensure they:

1. are of a certain datatype, e.g. :id is of type xs:integer
2. match a certain regular expression, e.g. :id is [0-9]+
3. will only be selected if an XQuery expression yielded fn:true()
4. user has the right permissions

Not yet, need more routes

### Roadmap

If you are interested in any of these (or other) feature and don't want to wait just read the instructions
on "Contribute" and send in your code

* Generating Paths and URLs from code
* Make singular resources map to plural controllers
* Nested Resources
* Namespaces & Scopes, e.g. /admin/user/1/edit

### Known Limitations

In this section we have the know limitations excluding the features that are not supported. 
To better understand what is supported refer to the Supported Features section

* Special handlers like :id and :database are passed as normal parameters. This means your if your user/form provides an id as well you will have two :ids, one for the request and another for what comes from the post. The first one is always the special :id and the subsequent ones are whatever the user gave you. Need to write this up a little better


#### Important Technicality 

We don't want to map each user to a file, just like we do for other requests. It's impractical to keep separate files for each user you have. So you map them  to `user.xqy` and pass the username as a parameter, e.g. `user.xqy?user=dscape`. Please keep this in mind when developing your webapps as other request fields can exist with the same name and your users can even inject other users in the field, e.g. `user.xqy?user=dscape&user=hkstirman`. This framework will always give you what was generated as the first parameter so a safe way of avoiding this is to simply get the first field named user:

    xdmp:get-request-field( 'user' ) [1]

On previous versions of `rewrite` dynamic routes where prefixed by `_`, so `user` would be `_user`. I choose to make it explicit so people stumble upon it faster and realize they still need to carefully protect themselves against  tricks like this.

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