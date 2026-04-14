/*
 * B2: read JSONL; count lines; rolling hash over characters (diagnostic).
 * Run: ./b2 bench/work/data.jsonl
 */
REQUEST HB_GT_STD_DEFAULT

PROCEDURE Main( ... )
   LOCAL a := hb_AParams()
   LOCAL path, c, lines, i, n, h := 0, t0, t1, line, j, ch

   path := IIF( Len( a ) > 0, a[1], "bench/work/data.jsonl" )
   IF !hb_FileExists( path )
      ConOut( '{"error":"missing file","path":"' + path + '"}' + hb_eol() )
      Quit( 1 )
      RETURN
   ENDIF

   c := hb_MemoRead( path )
   c := StrTran( c, Chr(13), "" )
   lines := hb_ATokens( c, Chr(10) )
   n := Len( lines )

   t0 := hb_MilliSeconds()
   FOR i := 1 TO n
      line := lines[i]
      IF !Empty( line )
         FOR j := 1 TO Len( line )
            ch := Asc( SubStr( line, j, 1 ) )
            h := h * 1315423911 + ch
            h := h - Int( h / 4294967296 ) * 4294967296
         NEXT
      ENDIF
   NEXT
   t1 := hb_MilliSeconds()

   ConOut( '{"phase":"B2_xhb","rows":' + hb_ntos( n ) + ',"millis":' + hb_ntos( t1 - t0 ) + ;
      ',"line_char_hash32":' + hb_ntos( h ) + '}' + hb_eol() )
RETURN
