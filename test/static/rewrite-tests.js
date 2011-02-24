function rewriteUrl( method, uri, xml, extra ) {
  return 'rewrite.xqy?uri=' + escape( uri ) + "&routes=" + escape( xml ) +
  '&method=' + escape( method ) + extra };