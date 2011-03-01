xquery version "1.0-ml" ;

import module 
  namespace r = "routes.xqy"
  at "/lib/routes.xqy" ;

declare variable $uri    := xdmp:get-request-field( 'uri'    )  ;
declare variable $method := xdmp:get-request-field( 'method' )  ;
declare variable $routes := 
  fn:replace( fn:replace(
    xdmp:get-request-field( 'routes' ), "%2B", "+"
  ), "%2A", "*" )  ;
declare variable $paths  := xdmp:get-request-field( 'paths'  )  ;

xdmp:log( fn:string-join( ("async >>", $method, $uri), " ") ),
if ( $routes and $uri and $method )
then 
  let $r-xml := <routes> { xdmp:unquote( $routes ) } </routes>
  let $r-uri := $uri
  return 
    if ($paths and fn:not($paths="undefined")) 
    then
      let $p-xml := <paths>  { xdmp:unquote( $paths )  } </paths> 
      return r:selectedRoute( $r-xml, $r-uri, $method, $p-xml )
    else r:selectedRoute( $r-xml, $r-uri, $method )
else fn:error()