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
  fn:concat( $dynamicRouteDelimiter, "([\w|\-|_|\s|:]+)" ) ;
declare variable $dynamicRouteRegExpReplacement := "([\\w|\\-|_|\\s|:|\\.]+)" ;

declare function r:selectedRoute( $routesCfg ) {
  r:selectedRoute( $routesCfg, xdmp:get-request-url(), 
    xdmp:get-request-method() ) };

declare function r:selectedRoute( $routesCfg, $defaultCfg ) {
  r:selectedRoute( $routesCfg, xdmp:get-request-url(), 
    xdmp:get-request-method(), $defaultCfg ) };

declare function r:selectedRoute( $routesCfg, $url, $method ) { 
 r:selectedRoute( $routesCfg, $url, $method, () ) };

declare function r:selectedRoute( $routesCfg, $url, $method, $defaultCfg ) {
  let $_        := r:setDefaults( $defaultCfg )
  let $tokens   := fn:tokenize( $url, '\?' )
  let $route    := $tokens [1]
  let $args     := $tokens [2]
  let $req      := fn:string-join( ( $method, $route ), " " )
  let $mappings := r:mappings ( $routesCfg )
  let $selected := $mappings //mapping [ fn:matches( $req, @regexp ) ] [1]
  return
    if ($selected) (: found a match, using the first :)
    then 
      let $route       := $selected/@key
      let $regexp      := $selected/@regexp
      let $labels      := r:extractLabels( $route )
      let $labelValues := fn:analyze-string( $req, $regexp ) 
        //s:match/s:group/fn:string(.)    
      let $dispatchTo  := 
        if ( $selected/@value = "" ) (: dynamic route, couldn't calculate :)
        then
          let $r := fn:index-of($labels, 'resource')
          let $a := fn:index-of($labels, 'action')
          return r:resourceActionPath( $labelValues[$r], $labelValues[$a] )
        else $selected/@value 
      let $params := fn:string-join( (
        if ( $labelValues ) 
        then
          for $match at $p in $labelValues
          let $label := $labels[$p]
          where $label != 'resource' and $label != 'action'
          return 
            fn:concat( $label, "=", xdmp:url-encode( $match ) )
         else (), $args ), "&amp;" )
      return fn:concat( $dispatchTo, 
        if ($params) then fn:concat("&amp;", $params) else "")
    else (: didn't find a match so let's try the static folder :)
      fn:concat( fn:replace($staticDirectory, "/$", ""), $route ) } ;

declare function r:mappings( $routesCfg ) { 
  <mappings> { for $e in $routesCfg/* return r:transform($e) } </mappings> } ;

declare function r:transform( $node ) {
  typeswitch ( $node )
    case element( root )      return r:root( $node )
    case element( resources ) return r:resources( $node )
    case element( resource )  return r:resource( $node )
    case element( get )       return r:verb( 'GET',    $node )
    case element( put )       return r:verb( 'PUT',    $node )
    case element( post )      return r:verb( 'POST',   $node )
    case element( delete )    return r:verb( 'DELETE', $node )
    case element( head )      return r:verb( 'HEAD',   $node )
    default                   return () (: ignored :) } ;

declare function r:root( $node ) { 
  r:mappingForHash( "GET /", $node ) } ;

declare function r:verb( $verb, $node ) { 
  let $req := fn:concat( $verb, " ", $node/@path )
  return 
    if ( $node/to ) (: if there's a place to go :)
    then r:mappingForHash( $req, $node/to )
    else if ( $node/redirect-to ) (: if theres a redirect :) 
    then r:mappingForRedirect( $req, $node/redirect-to )
    else r:mappingForDynamicRoute( $node ) (: purely dynamic route we need to figure it out :) 
} ;

declare function r:resources( $node ) {
  let $resource   := $node/@name
  let $webservice := $node/@webservice
  let $index      := r:mapping( fn:concat('GET /', $resource),
    r:resourceActionPath( $resource, 'index' ) )
  let $verbs      := for $verb in ('GET', 'PUT', 'DELETE')
    return r:mapping( fn:concat( $verb, ' /', $resource, '/:id' ), 
      r:resourceActionPath( $resource, fn:lower-case($verb) ) )
  let $post       := if ($webservice) then () else
    r:mapping( fn:concat( 'POST /', $resource ), 
      r:resourceActionPath( $resource, 'post' ) )
  let $new        := if ($webservice) then () else
    r:mapping( fn:concat( 'GET /', $resource, '/new' ), 
      r:resourceActionPath( $resource, 'new' ) )
  let $edit       := if ($webservice) then () else
    r:mapping( fn:concat( 'GET /', $resource, '/:id/edit' ), 
      r:resourceActionPath( $resource, 'edit' ) )
  let $memberInc  := r:includes( $resource, $node/member, fn:true() )
  let $setInc     := r:includes( $resource, $node/set, fn:false() )
  return ( $edit, $new, $memberInc, $setInc, $verbs, $post, $index ) };

declare function r:resource( $node ) {
  let $resource   := $node/@name
  let $webservice := $node/@webservice
  let $verbs      := for $verb in ('GET', 'PUT', 'DELETE')
    return r:mapping( fn:concat( $verb, ' /', $resource ), 
      r:resourceActionPath( $resource, fn:lower-case($verb) ) )
  let $post       := if ($webservice) then () else
    r:mapping( fn:concat( 'POST /', $resource ), 
      r:resourceActionPath( $resource, 'post' ) )
  let $edit       := if ($webservice) then () else
    r:mapping( fn:concat( 'GET /', $resource, '/edit' ), 
      r:resourceActionPath( $resource, 'edit' ) )
  let $memberInc  := r:includes( $resource, $node/member, fn:false() )
  return ( $edit, $memberInc, $verbs, $post ) };

declare function r:mappingForRedirect( $req, $node ) { () };
declare function  r:mappingForDynamicRoute( $node ) { 
  let $path       := $node/@path
  let $resource   := fn:matches($path, ":resource")
  let $action     := fn:matches($path, ":action")
  return 
    if ( $resource and $action )
    then let $_ := xdmp:log('fddfdfdf') return
      r:mapping( fn:concat( 'GET ', $path ), () )
    else () } ;

declare function r:includes( $resource, $includes, $member ){
  for $include in $includes
    let $action := fn:data( $include/@action )
    let $verbs  := fn:tokenize($include/@for, ',')
    for $verb in (if($verbs) then $verbs else 'GET')
      return r:mapping( fn:concat( $verb, " /", $resource, 
        if( $member ) then "/:id/" else "/", $action ), 
        r:resourceActionPath( $resource, $action ) ) };

declare function r:mappingForHash( $req, $node ) { 
  let $resource   := r:resourceActionPair( $node ) [1]
  let $action     := r:resourceActionPair( $node ) [2]
  return 
    r:mapping( $req, r:resourceActionPath( $resource, $action ) ) } ;

declare function r:resourceActionPair( $node ) {
  fn:tokenize ( fn:normalize-space( $node ), $resourceActionSeparator )  } ;

declare function r:resourceActionPath( $resource, $action ) {
  fn:concat( r:resourceDirectory(), 
    fn:replace( $resource, $dynamicRouteDelimiter, "" ), ".", 
    r:xqyExtension(), "?action=", $action ) } ;

declare function r:mapping( $k, $v ) { 
  r:mapping( $k, $v, r:generateRegularExpression( $k ) ) };

declare function r:mapping( $k, $v, $r ) {
  <mapping key="{ $k }" 
    regexp="{ $r }" value="{ $v }"/> };

declare function r:generateRegularExpression( $node ) {
  let $path := fn:normalize-space($node)
  return 
    fn:concat(
      fn:replace( $path ,  $dynamicRouteRegExp, $dynamicRouteRegExpReplacement ), 
      (: Fixing trailing slashes for everything but root node :)
      if ( fn:tokenize( $path, " " ) [2] = "/" ) then "(\?.*)?$" else "/?" ) };

declare function r:extractLabels( $node ) {
  fn:analyze-string($node,  $dynamicRouteRegExp) //s:match/s:group/fn:string(.) } ;

declare function r:setDefaults( $defaultCfg ) { 
  let $resourceDirectoryOverride   := $defaultCfg //resourceDirectory   [1]
  let $staticDirectoryOverride     := $defaultCfg //staticDirectory     [1]
  let $xqyExtensionOverride        := $defaultCfg //xqyExtension        [1]
  return 
    ( if ( $resourceDirectoryOverride ) 
      then xdmp:set( $resourceDirectory, $resourceDirectoryOverride/fn:string() )
      else (),
      if ( $staticDirectoryOverride ) 
      then xdmp:set( $staticDirectory, $staticDirectoryOverride/fn:string() )
      else (),
      if ( $xqyExtensionOverride ) 
      then xdmp:set( $xqyExtension, $xqyExtensionOverride/fn:string() )
      else () ) } ;

declare function r:resourceDirectory()   { $resourceDirectory } ;
declare function r:staticDirectory()     { $staticDirectory } ;
declare function r:xqyExtension()        { $xqyExtension } ;