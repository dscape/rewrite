xquery version "1.0-ml" ;

import module 
  namespace r = "routes.xqy"
  at "/lib/routes.xqy" ;

declare variable $uri    := xdmp:get-request-field( 'uri' ) ;
declare variable $method := xdmp:get-request-field( 'method' ) ;
declare variable $routes := <routes>
    { xdmp:unquote( xdmp:get-request-field( 'routes' ) ) } </routes> ;

r:selectedRoute( $routes, $uri, $method )