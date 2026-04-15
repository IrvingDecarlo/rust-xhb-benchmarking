/*
 * B6: cache (canonical JSONL) → file write.
 *
 * CLI:
 *   b6 <cache_path> <output_path>
 *
 * Defaults:
 *   cache_path: bench/work/xhb_cache.jsonl
 *   output_path: bench/work/out-xhb.jsonl
 *
 * Output: one-line JSON with rows, millis, path.
 */
REQUEST HB_GT_STD_DEFAULT

EXTERNAL LineReaderOpen
EXTERNAL LineReaderNext
EXTERNAL LineReaderClose

PROCEDURE Main( ... )
   LOCAL a := hb_AParams()
   LOCAL cCache := IIF( Len( a ) > 0, a[1], "bench/work/xhb_cache.jsonl" )
   LOCAL cOut := IIF( Len( a ) > 1, a[2], "bench/work/out-xhb.jsonl" )
   LOCAL lr, fh, n := 0
   LOCAL t0, t1, line

   hb_DirCreate( hb_FNamePath( cOut ) )

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

   fh := FCreate( cOut )
   IF fh < 0
      ConOut( '{"error":"cannot create output","path":"' + cOut + '"}' + hb_eol() )
      Quit( 1 )
      RETURN
   ENDIF

   t0 := hb_MilliSeconds()
   DO WHILE LineReaderNext( @lr )
      line := lr["line"]
      IF Empty( line )
         LOOP
      ENDIF
      FWrite( fh, line + hb_eol() )
      n++
   ENDDO
   t1 := hb_MilliSeconds()

   FClose( fh )
   LineReaderClose( @lr )

   ConOut( '{\"phase\":\"B6_xhb\",\"rows\":' + hb_ntos( n ) + ;
      ',\"millis\":' + hb_ntos( t1 - t0 ) + ;
      ',\"path\":\"' + cOut + '\"}' + hb_eol() )
RETURN

