/*
 * B5: cache (row hashes as JSONL) → materialize hashes (untimed) → canonical reserialize/hash (timed).
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
EXTERNAL JsonParse
EXTERNAL CanonicalLineFromHash
EXTERNAL HashLine32

PROCEDURE Main( ... )
   LOCAL a := hb_AParams()
   LOCAL cCache := IIF( Len( a ) > 0, a[1], "bench/work/xhb_cache.jsonl" )
   LOCAL lr, n := 0, h := 0
   LOCAL t0, t1, line, aRows := {}, hRow, i

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

   /* Untimed: read cache JSONL and materialize hashes */
   DO WHILE LineReaderNext( @lr )
      line := lr["line"]
      IF Empty( line )
         LOOP
      ENDIF
      hRow := JsonParse( line )
      AAdd( aRows, hRow )
   ENDDO
   LineReaderClose( @lr )

   /* Timed: canonical serialization from hashes + rolling hash */
   t0 := hb_MilliSeconds()
   FOR i := 1 TO Len( aRows )
      line := CanonicalLineFromHash( aRows[i] )
      h := HashLine32( h, line )
   NEXT
   t1 := hb_MilliSeconds()
   n := Len( aRows )

   ConOut( '{\"phase\":\"B5_xhb\",\"rows\":' + hb_ntos( n ) + ;
      ',\"millis\":' + hb_ntos( t1 - t0 ) + ;
      ',\"hash32\":' + hb_ntos( h ) + '}' + hb_eol() )
RETURN
