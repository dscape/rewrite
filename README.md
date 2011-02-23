# rewrite

The purpose of the rewrite script is to eliminate the 1-to-1 mapping between files and MarkLogic 
App Servers by introducing a intermediate layer that recognizes URLs and dispatches them
to application code.

This project also tries to help you to make security part of this process by introducing
XQuery constraints.

rewrite is designed to work with [MarkLogic][2] Server only. However it can easily be ported 
to another product that understands XQuery and has similar capabilities.

## Usage

Not yet

* Install
* Point app Server to rewrite
* Makes routes and supporting XQuery
* Done

Check features for a description of what the `routes.xml` file translates to.

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

    http://127.0.0.1:8090/tests

Make sure all the tests pass before sending in your pull request!

### Report a bug

If you want to contribute with a test case please file a [issue][1] and attach 
the following information:

* Not yet

This will help us be faster fixing the problem.

An example for a Hello World test would be:

      Not yet

This is not the actual test that we run (you can see a list of those in test/index.xqy) but it's all the information we need for a bug report.

## Supported Functionality

Not yet

### Roadmap

If you are interested in any of these (or other) feature and don't want to wait just read the instructions
on "Contribute" and send in your code

* Not yet.

### Known Limitations

In this section we have the know limitations excluding the features that are not supported. 
To better understand what is supported refer to the Supported Features section

* Not yet

## Meta

* Code: `git clone git://github.com/dscape/rewrite.git`
* Home: <http://github.com/dscape/rewrite>
* Discussion: <http://convore.com/marklogic>
* Bugs: <http://github.com/dscape/rewrite/issues>

(oO)--',- in [caos][3]

[1]: http://github.com/dscape/rewrite/issues
[2]: http://marklogic.com
[3]: http://caos.di.uminho.pt