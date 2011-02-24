xquery version "1.0-ml" ;

import module 
  namespace r = "routes.xqy"
  at "/lib/routes.xqy" ;

declare variable $uri    := xdmp:get-request-field( 'uri'    )  ;
declare variable $method := xdmp:get-request-field( 'method' )  ;
declare variable $routes := xdmp:get-request-field( 'routes' )  ;
declare variable $paths  := xdmp:get-request-field( 'paths'  )  ;

if ( $routes and $uri and $method )
then 
  let $r-xml := <routes> { xdmp:unquote( $routes ) } </routes>
  return 
    if ($paths and fn:not($paths="undefined")) 
    then
      let $p-xml := <paths>  { xdmp:unquote( $paths )  } </paths> 
      return r:selectedRoute( $r-xml, $uri, $method, $p-xml )
    else r:selectedRoute( $r-xml, $uri, $method )
else fn:error()