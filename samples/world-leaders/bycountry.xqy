xquery version "1.0-ml";

declare namespace wc = "http://marklogic.com/mlu/world-leaders" ;

import module namespace h = "helper.xqy" at "helper.xqy" ;

declare variable $country :=
  xdmp:get-request-field( 'country', 'all')
  ;

xdmp:set-response-content-type("text/html; charset=utf-8"),
'<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>World Leaders</title>
<link href="/css/world-leaders.css" rel="stylesheet" type="text/css" />
</head>

<body>
<div id="wrapper">
  <a href="/"><img src="/images/logo.gif" width="427" height="76" /></a><br />
  <span class="currently">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  Currently in database: { h:total-leaders() }</span><br />
  <br />
  <br />
  <br />
  { h:tabs( "country" ) }
  { h:greybar( 
    <form name="formcountry" method="get" action="/country" id="formcountry">
    <p>Choose a country: </p>
    <select name="country" id="country">
    <option value="all">all</option>
    { 
      for $opt in fn:distinct-values( //wc:country )
      order by $opt
      return <option value="{$opt}">
        { if($country=$opt)
          then attribute selected { "selected" }
          else (), 
        $opt}</option> 
    }
    </select>
    <input type="submit" value="go"/>
    </form> ) }
  <div id="content">
   { 
     let $leaders :=
       for $leader in /wc:leader 
       where $country = 'all' or $leader//wc:country = $country
       order by $leader//wc:firstname 
       return $leader
     return h:table( $leaders ) }
 </div>
</div>
</body>
</html>
