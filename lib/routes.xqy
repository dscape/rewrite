xquery version "1.0-ml" ;

module  namespace r  = "routes.xqy" ;
declare namespace 
  s  = "http://www.w3.org/2009/xpath-functions/analyze-string" ;

declare variable $resourceDirectory   := "/resource/" ;
declare variable $staticDirectory     := '/static/' ;
declare variable $xqyExtension        := 'xqy' ;

declare variable $resourceActionSeparator       := "#" ;
declare variable $dynamicRouteDelimiter         := ':' ;
declare variable $dynamicRouteRegExp            := 
  fn:concat( $dynamicRouteDelimiter, "([\w|\-|_]+)" ) ;
declare variable $dynamicRouteRegExpReplacement := "([\\w|\\-|_|\\.]+)" ;

declare function r:selectedRoute( $routesCfg ) {
  r:selectedRoute( $routesCfg, xdmp:get-request-url(), 
    xdmp:get-request-method() ) };

declare function r:selectedRoute( $routesCfg, $defaultCfg ) {
  r:selectedRoute( $routesCfg, xdmp:get-request-url(), 
    xdmp:get-request-method(), $defaultCfg ) };

declare function r:selectedRoute( $routesCfg, $url, $method ) { 
 r:selectedRoute( $routesCfg, $url, $method, () ) };

declare function r:selectedRoute( $routesCfg, $url, $method, $defaultCfg ) {
  let $tokens   := fn:tokenize( $url, '\?' )
  let $route    := $tokens [1]
  let $args     := $tokens [2]
  let $req      := fn:string-join( ( $method, $route ), " " )
  let $mappings := r:mappings ( $routesCfg )
  let $_        := r:setDefaults( $defaultCfg )
  let $selected := $mappings //mapping [ fn:matches( $req, @regexp ) ] [1]
  return
    if ($selected) (: found a match, using the first :)
    then 
      let $route       := $selected/@key
      let $dispatchTo  := $selected/@value
      let $regexp      := $selected/@regexp
      let $labels      := r:extractLabels( $route )
      let $labelValues := fn:analyze-string( $req, $regexp ) 
        //s:match/s:group/fn:string(.)
      let $params := fn:string-join( (
        if ( $labelValues ) 
        then
          for $match at $p in $labelValues
          return 
            fn:concat( $labels[$p], "=", xdmp:url-encode( $match ) )
         else (), $args ), "&amp;" )
      return fn:concat( $dispatchTo, 
        if ($params) then fn:concat("?", $args) else "")
    else (: didn't find a match so let's try the static folder :)
      fn:concat( fn:replace($staticDirectory, "/$", ""), $route ) } ;

declare function r:mappings( $routesCfg ) { 
  <mappings> { for $e in $routesCfg/* return r:transform($e) } </mappings> } ;

declare function r:transform( $node ) {
  typeswitch ( $node )
    case element( root )     return r:root( $node )
    default                  return () } ;

declare function r:root( $node ) {
  let $resource   := r:resourceActionPair( $node ) [1]
  let $action     := r:resourceActionPair( $node ) [2]
  return 
    r:mapping( "GET /", r:resourceActionPath( $resource, $action ) ) } ;

declare function r:resourceActionPair( $node ) {
  fn:tokenize ( fn:normalize-space( $node ), $resourceActionSeparator )  } ;

declare function r:resourceActionPath( $resource, $action ) {
  fn:concat( r:resourceDirectory(), 
    fn:replace( $resource, $dynamicRouteDelimiter, "" ), ".", 
    r:xqyExtension(), "?action=", $action ) } ;

declare function r:mapping( $k, $v ) {
  <mapping key="{ $k }" 
    regexp="{ r:generateRegularExpression( $k ) }" value="{ $v }"/> };

declare function r:generateRegularExpression( $node ) {
  let $path := fn:normalize-space($node)
  return 
    fn:concat(
      fn:replace( $path ,  $dynamicRouteRegExp, $dynamicRouteRegExpReplacement ), 
      (: Fixing trailing slashes for everything but root node :)
      if ( fn:tokenize( $path, " " ) [2] = "/" ) then "" else "(/)?" ) };

declare function r:extractLabels( $node ) {
  fn:analyze-string($node,  $dynamicRouteRegExp) //s:match/s:group/fn:string(.) } ;

declare function r:setDefaults( $defaultCfg ) { 
  let $resourceDirectoryOverride := $defaultCfg //resourceDirectory [1]
  let $staticDirectoryOverride     := $defaultCfg //staticDirectory     [1]
  let $xqyExtensionOverride        := $defaultCfg //xqyExtension        [1]
  return 
    ( if ( $resourceDirectoryOverride ) 
      then xdmp:set( $resourceDirectory, $resourceDirectoryOverride )
      else (),
      if ( $staticDirectoryOverride ) 
      then xdmp:set( $staticDirectory, $staticDirectoryOverride )
      else (),
      if ( $xqyExtensionOverride ) 
      then xdmp:set( $xqyExtension, $xqyExtensionOverride )
      else ()
    ) } ;

declare function r:resourceDirectory()   { $resourceDirectory } ;
declare function r:staticDirectory()     { $staticDirectory } ;
declare function r:xqyExtension()        { $xqyExtension } ;