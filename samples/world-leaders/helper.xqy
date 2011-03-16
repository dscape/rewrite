module namespace h = "helper.xqy"
  ;

declare namespace wc = "http://marklogic.com/mlu/world-leaders" 
  ;

declare function h:total-leaders() {
  xdmp:estimate( /wc:leader ) } ;

declare function h:greybar() {
  h:greybar( () ) };

declare function h:greybar( $form ) { 
  <div id="graybar"> { $form } </div>
};

declare function h:table () {
  h:table( /wc:leader ) } ;

declare function h:table( $leaders ) {
  <table cellspacing="0">
    <tr>
      <th>F Name</th>
      <th>L Name</th>
      <th>Country</th>
      <th>Title</th>
    <th>H of State</th>
      <th><p>H of Govt</p></th>
      <th>Start Date</th>
      <th>End Date</th>
      <th>Age</th>
      <th>Gender</th>
    </tr>
    <tr>
      <td colspan="10"><hr/></td>
    </tr>
    { for $leader in $leaders
      let $firstName       := $leader //wc:firstname /fn:string()
      let $lastName        := fn:string( $leader //wc:lastname ) 
      let $country         := $leader //wc:country /fn:string()
      let $currentPosition := $leader //wc:position [1] 
      let $title           := $currentPosition /wc:title /fn:string()
      let $startDate       := $currentPosition /wc:startdate /fn:string()
      let $endDate         := $currentPosition /wc:enddate /fn:string()
      let $hos             := $currentPosition /@hos /fn:string()
      let $hog             := $currentPosition /@hog /fn:string()
      let $gender          := $leader //wc:gender /fn:string()
      let $age             := $leader //wc:dob /fn:string()
      let $description    := $leader //wc:summary /fn:string()
      let $hos-color      := if ($hos) then "#689747" else "#C40E1C"
      let $hog-color      := if ($hog) then "#689747" else "#C40E1C"
      return (
        <tr>
        <td><b>{$firstName}</b></td>
        <td><b>{$lastName}</b></td>
        <td>{$country}</td>
        <td>{$title}</td>
        <td style="background:{$hos-color}; color:{$hos-color}">{$hos}</td>
        <td style="background:{$hog-color}; color:{$hog-color}">{$hog}</td>
        <td>{$startDate}</td>
        <td>{$endDate}</td>
        <td>{$age}</td> 
        <td>{$gender}</td>
        </tr> ,
        <tr>
        <td colspan="10" class="summary">{$description}</td> 
        </tr> ) }
  </table>
} ;

declare function h:tabs( $page ) {
  let $iSel := if ( $page = 'index' ) then "_selected" else ()
  let $cSel := if ( $page = 'country' ) then "_selected" else ()
  let $dSel := if ( $page = 'date' ) then "_selected" else ()
  let $sSel := if ( $page = 'search' ) then "_selected" else ()
  return <div id="tabs">
    <a href="/"><img src="/images/byname{$iSel}.gif" width="121" height="30"/></a>
    <a href="/country"><img src="/images/bycountry{$cSel}.gif" width="121" height="30" /></a>
    <a href="/search"><img src="/images/search{$sSel}.gif" width="121" height="30" /></a>
  </div>
};