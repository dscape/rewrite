xquery version "1.0-ml" ;

import module namespace r = "routes.xqy" at "/lib/routes.xqy" ;
declare namespace wl = "http://marklogic.com/mlu/world-leaders" ;

declare variable $routesCfg := 
  <routes>
    <root> index </root>
    <get path="search"> <to> search </to> </get>
    <get path="country"> <to> bycountry </to> </get>
    <get path="country/:country"> <to> bycountry </to> </get>
  </routes> ;

declare variable $pathsCfg :=
  <paths> 
    <resourceFormat>/:resource.:ext</resourceFormat>
    <staticFormat>/:remainder</staticFormat>
  </paths> ;

declare function local:load-files(){
  let $path := fn:concat( xdmp:modules-root(), "xml" )
  let $_    := xdmp:log( $path )
  for $d in xdmp:filesystem-directory( $path ) //dir:entry
  return xdmp:document-load( $d //dir:pathname, 
    <options xmlns="xdmp:document-load">
      <uri>/{fn:string($d//dir:filename)}</uri>
    </options>) } ;

if ( xdmp:exists( /wl:leader ) )
then ()
else local:load-files() ,
r:selectedRoute( $routesCfg, $pathsCfg )