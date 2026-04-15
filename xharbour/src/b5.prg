/*
 * B5: cache (canonical JSONL) → reserialize/hash.
 *
 * CLI:
 *   b5 <cache_path>
 *
 * Defaults:
 *   cache_path: bench/work/xhb_cache.jsonl
 *
 * Output: one-line JSON with rows, millis, hash32.
 */
REQUEST HB_GT_STD_DEFAULT

EXTERNAL LineReaderOpen
EXTERNAL LineReaderNext
EXTERNAL LineReaderClose

PROCEDURE Main( ... )
   LOCAL a := hb_AParams()
   LOCAL cCache := IIF( Len( a ) > 0, a[1], "bench/work/xhb_cache.jsonl" )
   LOCAL lr, n := 0, h := 0
   LOCAL t0, t1, line

   IF !hb_FileExists( cCache )
      ConOut( '{"error":"missing cache","path":"' + cCache + '"}' + hb_eol() )
      Quit( 1 )
      RETURN
   ENDIF

   lr := LineReaderOpen( cCache, 65536 )
   IF lr["fh"] < 0
      ConOut( '{"error":"cannot open cache","path":"' + cCache + '"}' + hb_eol() )
      Quit( 1 )
      RETURN
   ENDIF

   t0 := hb_MilliSeconds()
   DO WHILE LineReaderNext( @lr )
      line := lr["line"]
      IF Empty( line )
         LOOP
      ENDIF
      h := HashLine32( h, line )
      n++
   ENDDO
   t1 := hb_MilliSeconds()
   LineReaderClose( @lr )

   ConOut( '{\"phase\":\"B5_xhb\",\"rows\":' + hb_ntos( n ) + ;
      ',\"millis\":' + hb_ntos( t1 - t0 ) + ;
      ',\"hash32\":' + hb_ntos( h ) + '}' + hb_eol() )
RETURN

STATIC FUNCTION HashLine32( acc, cLine )
   LOCAL j, ch
   FOR j := 1 TO Len( cLine )
      ch := Asc( SubStr( cLine, j, 1 ) )
      acc := acc * 1315423911 + ch
      acc := acc - Int( acc / 4294967296 ) * 4294967296
   NEXT
RETURN acc

