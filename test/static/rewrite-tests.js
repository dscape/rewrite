function rewriteUrl( method, uri, xml, extra, paths ) {
  return 'rewrite.xqy?uri=' + escape(uri) + "&routes=" +  escape(xml)
  + '&paths=' + escape(paths) + '&method=' + escape(method) + escape(extra) };