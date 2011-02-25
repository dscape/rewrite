# rewrite

The purpose of the rewrite script is to eliminate the 1-to-1 mapping between files and MarkLogic App Servers by introducing a intermediate layer that recognizes URLs and dispatches them to application code.

This project also tries to help you to make security part of this process by introducing XQuery constraints.

rewrite is designed to work with [MarkLogic][2] Server only. However it can easily be ported to another product that understands XQuery and has similar capabilities.

rewrite is heavily inspired in the [Rails 3.0 routing][4].

## Basics

rewrite is a small DSL to make routing logic simple and easy to maintain. The logic behind is is:

1. Check the routes that match a specific request
2. Get the first that matched and redirect according to the rule (refer to functionality for a description of these rules)
3. If none matched redirect to a directory with static files. This way if you can still serve your css and javascript files without having to create special rules for them. Simply place them in the /static/ directory of your application.

Routes order matters, if one rules comes before other and both match the first match will be used. 

Not all routes are born the same and some have dynamic names. For example when in twitter you want to match twitter.com/dscape to the user dscape. This is what we call a dynamic route and you write it like `/:user`. The colon lets the routing algorithm know that it shouldn't be evaluated as a string but rather as a dynamic resource. Neat right?

#### Important Technicality 

We don't want to map each user to a file, just like we do for other requests. It's impractical to keep separate files for each user you have. So you map them  to `user.xqy` and pass the username as a parameter, e.g. `user.xqy?user=dscape`. Please keep this in mind when developing your webapps as other request fields can exist with the same name and your users can even inject other users in the field, e.g. `user.xqy?user=dscape&user=hkstirman`. This framework will always give you what was generated as the first parameter so a safe way of avoiding this is to simply get the first field named user:

    xdmp:get-request-field( 'user' ) [1]

On previous versions of rewrite dynamic routes where prefixed by `_`, so `user` would be `_user`. I choose to make it explicit so people stumble upon it faster and realize they still need to carefully protect themselves against  tricks like this.

## Usage

Not yet

* Install
* Point app Server to rewrite
* Makes routes and supporting XQuery
* Done

Check features for a description of what the `routes.xml` file translates to. 

You can also define a `paths.xml` file where you store overrides for the resource path (which defaults to /resource/), xqy extension (which defaults to xqy) and static path (defaults to /static/). Here's an example of what a `paths.xml` might look like:

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

To run the tests simply point an MarkLogic HTTP AppServer to the root of rewrite

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

### Routes

####  ✔ root 
Root in an element for requests against the server root.

     Request       : GET /
     routes.xml    : <routes> <root> server#version </root> </routes> 
     Dispatches to : /resource/server.xqy?action=ping

####  ✔ get 
     Request       : GET /list
     routes.xml    : <routes> 
                       <get path="/list"> <to> article#list </to> </get>
                     </routes>
     Dispatches to : /resource/article.xqy?action=list

####  ✔ put 
     Request       : PUT /upload
     routes.xml    : <routes>
                       <put path="/upload"> <to> file#upload </to> </put>
                     </routes>
     Dispatches to : /resource/file.xqy?action=upload

####  ✕ post 

     Request       : 
     routes.xml    : 
     Dispatches to :

####  ✕ delete 

     Request       : 
     routes.xml    : 
     Dispatches to :

####  ✕ head 

     Request       : 
     routes.xml    : 
     Dispatches to :

### More

####  ✕ redirect
redirect to

####  ✕ dynamic resources

####  ✕ dynamic defaults
/:controller/:action/:id

####  ✕ constraints
You can run constraints against your routes to ensure they:

1. are of a certain datatype, e.g. :id is of type xs:integer
2. match a certain regular expression, e.g. :id is [0-9]+
3. will only be selected if an XQuery expression yielded fn:true()

Not yet, need more routes

####  ✔ static
If no match is found rewrite will dispatch your query to a /static/ folder where you should keep all your static files. This way you don't have to create routing rules for static files.

     Request       : GET /css/style.css
     routes.xml    : <routes> <root> server#version </root> </routes> 
     Dispatches to : /static/css/style.css

####  ✔ paths
By default the application will look for resources in `/resource/`, static in `/static/` and will use the `.xqy` extension for XQuery files. You can change this by providing a `paths.xml` file:

     Request       : GET /
     routes.xml    : <routes> <root> server#version </root> </routes> 
     paths.xml     : <paths> <resourceDirectory>/</resourceDirectory> </paths>
     Dispatches to : /server.xqy?action=ping

####  ✕ permissions
MarkLogic permissions support

####  ✕ content negotiation

### Roadmap

If you are interested in any of these (or other) feature and don't want to wait just read the instructions
on "Contribute" and send in your code

* Not yet.

### Known Limitations

In this section we have the know limitations excluding the features that are not supported. 
To better understand what is supported refer to the Supported Features section

* Special handlers like :id and :database are passed as normal parameters. This means your if your user/form provides an id as well you will have two :ids, one for the request and another for what comes from the post. The first one is always the special :id and the subsequent ones are whatever the user gave you. Need to write this up a little better

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