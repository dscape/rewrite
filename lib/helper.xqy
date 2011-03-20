xquery version "1.0-ml" ;

module  namespace h  = "helper.xqy" ;

(:
 : This file is for your reference only.
 : Rewrite is just responsible for dispatching requests to files.
 : This file is not considered as part of rewrite, neither it was tested.
 :)

(: http :)
declare function h:mustRevalidateCache() {
  xdmp:add-response-header('Cache-Control', 'must-revalidate') } ;

declare function h:noCache() {
  xdmp:add-response-header('Cache-Control', 'must-revalidate, no-cache'), 
  xdmp:add-response-header('Pragma', 'no-cache'), 
  xdmp:add-response-header('Expires', 'Fri, 01 Jan 1990 00:00:00 GMT'),
  h:etag( xdmp:request() ) } ;

declare function h:addCurrentDateToResponseHeaders() {
  xdmp:add-response-header( "Date", 
    xdmp:strftime( "%a, %d %b %Y %H:%M:%S %Z", fn:current-dateTime() ) ) } ;

declare function h:etag ( $id ) {
  h:etag( $id, fn:true() ) };

declare function h:weakEtag ( $id ) {
  h:etag( $id, fn:false() ) };

declare function h:etag( $id, $strong ) {
  let $str   := fn:concat( '"', xdmp:md5(fn:string($id)), '"' )
  let $etag := if ($strong) then $str else fn:concat("W/", $str)
  return xdmp:add-response-header('ETag', $etag) } ;

(: If you want content negotiation to fail when simply change the code to
 : to raise:
 :    fn:error( xs:QName( 'REWRITE-CNFAILED' ), '406', $defaultContentType ) 
 : if content negotiation fails.
 :
 : h:error/2 as been set to match this behavior
 :)
declare function h:negotiateContentType( $accept, 
  $supportedContentTypes, $defaultContentType ) {
  let $orderedAcceptTypes :=
    for $mediaRange in fn:tokenize($accept, "\s*,\s*")
    let $l := fn:tokenize($mediaRange, "\s*;\s*")
    let $type   := $l [1]
    let $params := fn:subsequence( $l, 2 )
    let $quality := (
      for $p in $params
      let $qOrExt := fn:tokenize($p, "\s*=\s*") 
      where $qOrExt [1] = "q"
      return fn:number( $qOrExt[2] ), 1.0 ) [1]
    order by $quality descending
    return $type
  return (
    for $sat in $orderedAcceptTypes
    let $match := (
      for $sct in $supportedContentTypes
      where fn:matches( $sct, fn:replace( $sat, "\*", ".*" ) )
      return $sct ) [1]
    return $match, $defaultContentType ) [1] } ;

(: basic getters :)
declare function h:action() { 
  xdmp:get-request-field( 'action' ) [1] } ;

declare function h:id() { 
  xdmp:get-request-field( 'id' ) [1] } ;

(: resource helpers :)
declare function h:function() {
  h:function( fn:lower-case( ( h:action(), 
        xdmp:get-request-method() ) [ . != "" ] [1] ) ) };

declare function h:function( $name ) {
  xdmp:function( xs:QName( fn:concat( "local:", $name ) ) ) } ;

declare function h:error ( $e ) { 
  if ( $e//*:code = 'XDMP-UNDFUN' )
  then h:error( 404, 'Not Found' )
  else if ( $e//*:code = '301' and $e//*:name = 'REWRITE-REDIRECT' )
  then h:redirectTo( 301, 'Moved Permantly', $e/*:data/*:datum/fn:string() )
  else if ( $e//*:code = '406' and $e//*:name = 'REWRITE-CNFAILED' )
  then h:error( 406, 'Not Acceptable', $e/*:data/*:datum/fn:string() )
  else ( h:error( 500, 'Internal Server Error', $e//error:message/fn:string() ), 
  xdmp:log( $e ) ) } ;

declare function h:error( $code, $msg ) {
  h:error( $code, $msg, () ) } ;

declare function h:error( $code, $msg, $reason ) {
  ( xdmp:set-response-code( $code, $msg )
  , h:addCurrentDateToResponseHeaders()
  , if ( $reason ) 
    then xdmp:add-response-header( "X-rewriteExceptionMessage", $reason )
    else () ) } ;

declare function h:redirectTo( $code, $msg, $url ) {
  ( xdmp:set-response-code( $code, $msg )
  , xdmp:add-response-header( "Date", fn:string( fn:current-dateTime() ) )
  , xdmp:redirect-response( $url ) ) } ;

declare function h:render( $view, $params ) {
  ( xdmp:set-response-content-type( "text/plain" )
  , h:addCurrentDateToResponseHeaders()
  , xdmp:invoke( fn:concat( "/views/", $view, ".xqy" ), 
      ( xs:QName("params"), $params ) ) ) };