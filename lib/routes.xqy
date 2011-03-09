xquery version "1.0-ml" ;

module  namespace r  = "routes.xqy" ;
declare namespace 
  s  = "http://www.w3.org/2009/xpath-functions/analyze-string" ;

declare variable $resourceDirectory   := 'resource' ;
declare variable $staticDirectory     := 'static' ;
declare variable $xqyExtension        := 'xqy' ;
declare variable $redirectResource    := 'redirect' ;
declare variable $staticPath          := '/:static/:remainder' ;
declare variable $redirectPath        := '/:dir/:redirect.:ext?url=:url' ;
declare variable $defaultPath         := 
  '/:dir/:resource.:ext?action=:action' ;


declare variable $resourceActionSeparator          := "#" ;
declare variable $dynamicRouteDelimiter            := ':' ;
declare variable $methodSeparator                  := "-" ;
declare variable $dynamicRouteRegExp               := 
  fn:concat( $dynamicRouteDelimiter, "([\w|\-|_|\s|:|@]+)" ) ;
declare variable $dynamicRouteRegExpReplacement    := 
  "([\\w|\\-|_|\\s|:|\\.|@]+)" ;

declare function r:selectedRoute( $routesCfg ) {
  r:selectedRoute( $routesCfg, xdmp:get-request-url(), 
    xdmp:get-request-method() ) };

declare function r:selectedRoute( $routesCfg, $defaultCfg ) {
  r:selectedRoute( $routesCfg, xdmp:get-request-url(), 
    xdmp:get-request-method(), $defaultCfg ) };

declare function r:selectedRoute( $routesCfg, $url, $method ) { 
 r:selectedRoute( $routesCfg, $url, $method, () ) };

declare function r:selectedRoute( $routesCfg, $url, $method, $defaultCfg ) {
  let $_            := r:setDefaults( $defaultCfg )
  let $tokens       := fn:tokenize( $url, '\?' )
  let $route        := $tokens [1]
  let $args         := $tokens [2]
  let $req          := fn:string-join( ( $method, $route ), " " )
  let $mappings     := r:mappings ( $routesCfg )
  let $errorHandler := $routesCfg /@useErrorHandler = 'Yes'
  let $selected     := (
    for $mapping in $mappings //mapping [ fn:matches( $req, @regexp ) ] 
    let $regexp      := $mapping/@regexp
    let $labels      := fn:tokenize( $mapping/@labels, ";" )
    let $labelValues := fn:analyze-string( $req, $regexp ) 
      //s:match/s:group/fn:string(.)
    let $constraints := $mapping/constraints
    let $privileges  := $mapping/privileges
    let $lambdas     := $mapping/lambda
    where 
      r:boundParameterConstraints( $labels, $labelValues, $constraints)
      and r:privilegeConstraints( $privileges )
      and r:lamdaConstraints( $labels, $labelValues, $lambdas )
    return $mapping ) [1]
  return
    if ( $selected ) (: found a match, using the first :)
    then 
      if ( $errorHandler and $selected/@type = 'redirect' )
      then fn:error( xs:QName( 'REWRITE-REDIRECT' ), '301', 
        $selected/@url/fn:string() )
      else
        let $route       := $selected/@key
        let $regexp      := $selected/@regexp
        let $labels      := fn:tokenize( $selected/@labels, ";" )
        let $labelValues := fn:analyze-string( $req, $regexp ) 
          //s:match/s:group/fn:string(.)   
        let $dispatchTo  := 
          if ( $selected/@value = "" ) (: dynamic route, couldn't calculate :)
          then
            let $r := fn:index-of($labels, 'resource')
            let $a := fn:index-of($labels, 'action')
            return r:resourceActionPath( $labelValues[$r], $labelValues[$a] )
          else $selected/@value 
        let $separator := 
          if( fn:contains($dispatchTo, "?" ) )
          then "&amp;" else "?"
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
          if ($params) then fn:concat($separator, $params) else "")
    else (: didn't find a match so let's try the static folder :)
      fn:replace( fn:replace( r:staticPath(), 
        ":static",      r:staticDirectory() ),
        ":remainder", fn:replace( $route, "^/", "" ) ) } ;

declare function r:boundParameterConstraints($keys, $values, $constraints) { 
  every $c in $constraints/* 
  satisfies r:singleBPConstraint($keys, $values, $c) };

declare function r:singleBPConstraint( $keys, $values, $constraint ) {
  let $name  := fn:name( $constraint )
  let $type  := $constraint/@type
  let $match := $constraint/@match
  let $pos   := fn:index-of( $keys, $name )
  return
    if ( $pos )
    then
      let $value := $values [ $pos ]
      return 
        if ( $type and $match )
        then ( fn:matches( $value, $match ) 
               and r:castableAs( $value, $type ) )
        else if ($type)
        then r:castableAs( $value, $type )
        else if ($match)
        then fn:matches($value, $match) 
        else fn:true() (: no type or match? then its ok! :)
    else fn:true() (: if :key is not in the route then its valid :) };

declare function r:privilegeConstraints( $privileges ) { 
  let $user     := 
    if ( $privileges/@for )
    then fn:normalize-space( $privileges/@for )
    else xdmp:get-current-user()
  let $executes := for $e in  $privileges/execute 
                   return fn:normalize-space( $e )
  let $uris     := for $u in  $privileges/uri 
                   return fn:normalize-space( $u )
  return 
    ( 
      ( every $e in $executes 
        satisfies r:singlePrivilegeConstraint( $e, $user, 'execute' ) )
    and 
      ( every $u in $uris 
        satisfies r:singlePrivilegeConstraint( $u, $user, 'uri' ) ) ) } ;

declare function r:singlePrivilegeConstraint( $action, $user, $type ) {
  let $userRoles  := xdmp:user-roles( $user )
  let $privExists := try          { xdmp:privilege( $action, $type ) }
                     catch ( $e ) { fn:false() }
  let $privRoles  := xdmp:privilege-roles( $action, $type )
  return 
    if ( $privExists )
    then
      if ( $userRoles = $privRoles )
      then fn:true()
      else fn:false()
    else fn:true() (: consistent with behavior of xdmp:has-privilege :) };

declare function r:lamdaConstraints( $labels, $labelValues, $lambdas ) {
  let $prolog :=
    fn:string-join( 
      for $match at $p in $labelValues
      let $label := $labels[$p]
      return 
        fn:concat("declare variable $", $label, ' := "', $match, '" ; ' )  
    , "&#x0a;" )
  return 
    every $l in $lambdas 
    satisfies r:singleLambdaConstraint( 
      fn:concat( $prolog, " &#x0a;", $l ) ) };

declare function r:singleLambdaConstraint( $lambda ) {
  try { xdmp:eval( $lambda ) } catch ( $e ) { fn:false() } } ;

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
    case element( scope )     return r:scope( $node )
    default                   return () (: ignored :) } ;

declare function r:scope( $node ) {
let $aditional := r:aditional( $node )
return 
  for $n in $node/* 
  return r:transform(
    element { fn:node-name( $n ) } { $n/@*, $aditional, $n/* } ) } ;

declare function r:root( $node ) { 
  r:mappingForHash( "GET /", $node, () ) } ;

declare function r:verb( $verb, $node ) { 
  let $req := fn:concat( $verb, " /", $node/@path )
  return 
    if ( $node/to ) (: if there's a place to go :)
    then r:mappingForHash( $req, $node/to, r:aditional( $node ) )
    else if ( $node/redirect-to ) (: if theres a redirect :) 
    then r:mappingForRedirect( $req, $node )
    (: purely dynamic route we need to figure it out :) 
    else r:mappingForDynamicRoute( $node ) } ;


declare function r:resources( $node ) { r:resources( $node, '' ) } ;
declare function r:resources( $node, $ac ) {
  let $resource    := $node/@name
  let $webservice  := $node/@webservice
  let $aditional   := r:aditional( $node )
  let $rpath       := fn:concat( $ac, '/', $resource )
  let $ridpath     := fn:concat( $rpath,  '/:id' )
  let $index       := r:mapping( fn:concat('GET ', $rpath ),
    r:resourceActionPath( $resource, 'index' ), $aditional )
  let $verbs       := for $verb in ('GET', 'PUT', 'DELETE')
    return r:mapping( fn:concat( $verb, ' ', $ridpath ), 
      r:resourceActionPath( $resource, fn:lower-case($verb) ), $aditional )
  let $post        := if ($webservice) then () else
    r:mapping( fn:concat( 'POST ', $rpath ), 
      r:resourceActionPath( $resource, 'post' ), $aditional )
  let $new         := if ($webservice) then () else
    r:mapping( fn:concat( 'GET ', $rpath, '/new' ), 
      r:resourceActionPath( $resource, 'new' ), $aditional )
  let $edit        := if ($webservice) then () else
    r:mapping( fn:concat( 'GET ', $ridpath, '/edit' ), 
      r:resourceActionPath( $resource, 'edit' ), $aditional )
  let $memberInc   := 
    r:includes( $resource, $ridpath, $node/member, $aditional )
  let $setInc      := r:includes( $resource, $rpath, $node/set, $aditional )
  let $descendants := r:descendantResources( $node, $ridpath )
  return ( $edit, $new, $memberInc, $setInc, $verbs, $post, $index, 
           $descendants ) };

declare function r:resource( $node ) { r:resource( $node, '' ) } ;
declare function r:resource( $node, $ac ) {
  let $resource   := $node/@name
  let $webservice := $node/@webservice
  let $aditional  := r:aditional( $node )
  let $rpath      := fn:concat( $ac, '/', $resource )
  let $verbs      := for $verb in ('GET', 'PUT', 'DELETE')
    return r:mapping( fn:concat( $verb, ' ', $rpath ), 
      r:resourceActionPath( $resource, fn:lower-case($verb) ), $aditional )
  let $post       := if ($webservice) then () else
    r:mapping( fn:concat( 'POST ', $rpath ), 
      r:resourceActionPath( $resource, 'post' ), $aditional )
  let $edit       := if ($webservice) then () else
    r:mapping( fn:concat( 'GET ', $rpath, '/edit' ), 
      r:resourceActionPath( $resource, 'edit' ), $aditional )
  let $memberInc  := r:includes( $resource, $rpath, $node/member, $aditional )
  let $descendants := r:descendantResources( $node, $rpath )
  return ( $edit, $memberInc, $verbs, $post, $descendants ) };

declare function r:mappingForRedirect( $req, $node ) {
  let $redirect-to := fn:normalize-space( $node/redirect-to )
  let $aditional  := r:aditional( $node )
  return r:mapping( $req, r:redirectToBasePath( $redirect-to ),  
    ( attribute url { $redirect-to }, attribute type { 'redirect' }, 
      $aditional ) ) };

declare function  r:mappingForDynamicRoute( $node ) { 
  let $path       := fn:concat( "/", $node/@path )
  let $aditional  := r:aditional( $node )
  let $resource   := fn:matches($path, ":resource")
  let $action     := fn:matches($path, ":action")
  return 
    if ( $resource and $action )
    then 
      r:mapping( fn:concat( 'GET ', $path ), (), $aditional )
    else () } ;

declare function r:includes( $resource, $rpath, $includes, $aditional ){
  for $include in $includes
    let $action := fn:data( $include/@action )
    let $verbs  := fn:tokenize($include/@for, ',')
    for $verb in (if($verbs) then $verbs else 'GET')
      return r:mapping( fn:concat( $verb, " ", $rpath, "/", $action ), 
        r:resourceActionPath( $resource, $action ), $aditional ) };

declare function r:mappingForHash( $req, $node, $extraNodes ) { 
  let $resource   := r:resourceActionPair( $node ) [1]
  let $action     := r:resourceActionPair( $node ) [2]
  return 
    r:mapping( $req, 
      r:resourceActionPath( $resource, $action ), $extraNodes ) } ;

declare function r:resourceActionPair( $node ) {
  fn:tokenize ( fn:normalize-space( $node ), $resourceActionSeparator )  } ;

declare function r:resourceActionPath( $resource, $action ) {
  fn:replace( fn:replace( fn:replace( fn:replace( r:defaultPath() ,
    ":dir",        r:resourceDirectory() ), 
    ":resource", fn:replace( $resource, $dynamicRouteDelimiter, "" ) ), 
    ":ext",       r:xqyExtension() ), 
    ":action",    r:determineAction( $action ) ) } ;

declare function r:mapping( $k, $v ) { 
  r:mapping( $k, $v, r:generateRegularExpression( $k ), () ) };

declare function r:mapping( $k, $v, $extraNodes ) { 
  r:mapping( $k, $v, r:generateRegularExpression( $k ), $extraNodes ) } ;

declare function r:mapping( $k, $v, $r, $extraNodes ) {
  element mapping {
    attribute key    { $k },   attribute regexp { $r },
    attribute value  { $v }, 
    attribute labels { fn:string-join( r:extractLabels( $k ), ";" ) },
    $extraNodes } } ;

declare function r:generateRegularExpression( $node ) {
  let $path := fn:normalize-space($node)
  return 
    fn:concat(
      fn:replace( $path , 
        $dynamicRouteRegExp, $dynamicRouteRegExpReplacement ), 
      (: Fixing trailing slashes for everything but root node, args are in :)
      if ( fn:tokenize( $path, " " ) [2] = "/" ) 
      then "(\?.*)?$" 
      else "/?(\?.*)?$" ) };

declare function r:extractLabels( $node ) {
  fn:analyze-string($node,  $dynamicRouteRegExp) 
    //s:match/s:group/fn:string(.) } ;

declare function r:setDefaults( $defaultCfg ) { 
  let $resourceDirectoryOverride   := $defaultCfg //resourceDirectory   [1]
  let $staticDirectoryOverride     := $defaultCfg //staticDirectory     [1]
  let $xqyExtensionOverride        := $defaultCfg //xqyExtension        [1]
  let $redirectResourceOverride    := $defaultCfg //redirect            [1]
  let $defaultPathOverride         := $defaultCfg //pathFormat          [1]
  let $redirectPathOverride        := $defaultCfg //redirectPathFormat  [1]
  let $staticPathOverride          := $defaultCfg //staticPathFormat    [1]
  return ( 
    if ( $redirectResourceOverride ) 
    then xdmp:set( $redirectResource, $redirectResourceOverride/fn:string() )
    else (),
    if ( $redirectPathOverride ) 
    then xdmp:set( $redirectPath, $redirectPathOverride/fn:string() )
    else (),
    if ( $staticPathOverride ) 
    then xdmp:set( $staticPath, $staticPathOverride/fn:string() )
    else (),
    if ( $defaultPathOverride ) 
    then xdmp:set( $defaultPath, $defaultPathOverride/fn:string() )
    else (),
    if ( $resourceDirectoryOverride ) 
    then xdmp:set( $resourceDirectory, $resourceDirectoryOverride/fn:string())
    else (),
    if ( $staticDirectoryOverride ) 
    then xdmp:set( $staticDirectory, $staticDirectoryOverride/fn:string() )
    else (),
    if ( $xqyExtensionOverride ) 
    then xdmp:set( $xqyExtension, $xqyExtensionOverride/fn:string() )
    else () ) } ;

declare function r:redirectToBasePath( $redirectTo ) {
  fn:replace( fn:replace( fn:replace( fn:replace( r:redirectPath(),
    ":dir",      r:resourceDirectory() ),
    ":redirect", r:redirectResource() ),
    ":ext",      r:xqyExtension() ),
    ":url",   xdmp:url-encode( $redirectTo ) ) } ;

declare function r:descendantResources( $node, $rpath ) { 
  for $r in $node/resources return r:resources( $r, $rpath ),
  for $r in $node/resource  return r:resource(  $r, $rpath ) };

declare function r:determineAction ( $action ) {
  let $paths       := fn:tokenize( $action, "/" )
  let $firstAction := fn:replace( $paths [ 1 ], $dynamicRouteDelimiter, '' )
  let $rest        := 
    $paths [ 2 to fn:last() ] 
      [ fn:not( fn:matches( . , $dynamicRouteRegExp ) ) ]
  return fn:string-join( ( $firstAction, $rest ), $methodSeparator ) } ;

declare function r:redirectPath()        { $redirectPath      } ;
declare function r:staticPath()          { $staticPath        } ; 
declare function r:defaultPath()         { $defaultPath       } ;
declare function r:resourceDirectory()   { $resourceDirectory } ;
declare function r:staticDirectory()     { $staticDirectory   } ;
declare function r:xqyExtension()        { $xqyExtension      } ;
declare function r:redirectResource()    { $redirectResource  } ;
declare function r:aditional( $node ) { 
  ( $node/constraints, $node/privileges, $node/lambda ) } ;

declare function r:castableAs( $value, $type ) {
  xdmp:castable-as( "http://www.w3.org/2001/XMLSchema", $type, $value ) } ;