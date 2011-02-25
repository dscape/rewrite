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

declare function h:etag ( $id ) {
  h:etag( $id, fn:true() ) };

declare function h:weakEtag ( $id ) {
  h:etag( $id, fn:false() ) };

declare function h:etag( $id, $strong ) {
  let $str   := fn:concat( '"', xdmp:md5(fn:string($id)), '"' )
  let $etag := if ($strong) then $str else fn:concat("W/", $str)
  return xdmp:add-response-header('ETag', $etag) } ;

declare function h:negotiateContentType( $accept, 
  $supported-content-types, $default-content-type ) {
  let $ordered-accept-types :=
    for $media-range in fn:tokenize($accept, "\s*,\s*")
         let $l := fn:tokenize($media-range, "\s*;\s*")
         let $type   := $l [1]
         let $params := fn:subsequence($l, 2)
         let $quality := (for $p in $params
                         let $q-or-ext := fn:tokenize($p, "\s*=\s*") 
                         where $q-or-ext [1] = "q"
                         return fn:number($q-or-ext[2]), 1.0) [1]
         order by $quality descending
         return $type
  return (for $sat in $ordered-accept-types
           let $match := (for $sct in $supported-content-types
           where fn:matches($sct, fn:replace($sat, "\*", ".*"))
           return $sct) [1]
           return $match, $default-content-type) [1] } ;

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

declare function h:error ( $exception ) { 
  if ( $exception//*:code = 'XDMP-UNDFUN' )
  then xdmp:redirect-response( '/static/404.xqy' )
  else ( h:error( 500, 'Internal Server Error', $e//error:message/fn:string() ), 
  xdmp:log( $exception ) ) } ;

declare function h:error( $code, $msg, $reason ) {
  h:error( $code, $msg, () ) } ;

declare function h:error( $code, $msg, $reason ) {
  ( xdmp:set-response-code( $code, $msg )
  , xdmp:add-response-header( "Date", fn:string(fn:current-dateTime() ) )
  , if ( $reason ) 
    then xdmp:add-response-header( "X-errorReason", $reason )
    else () ) } ;