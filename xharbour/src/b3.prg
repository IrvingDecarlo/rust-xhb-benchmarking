/*
 * B3: JSONL → DBF (timed persistence only; CDX index built after timing).
 *
 * CLI:
 *   b3 <rows> <input_jsonl> <dbf_base>
 *
 * Defaults:
 *   rows: 1000000
 *   input_jsonl: bench/work/data.jsonl
 *   dbf_base: bench/work/xhb_bench
 *
 * Output: one-line JSON to stdout.
 */
REQUEST HB_GT_STD_DEFAULT
REQUEST HB_RDDCDX

/* external helpers (compiled together) */
EXTERNAL JsonParse
EXTERNAL JsonEncode
EXTERNAL LineReaderOpen
EXTERNAL LineReaderNext
EXTERNAL LineReaderClose

PROCEDURE Main( ... )
   LOCAL a := hb_AParams()
   LOCAL nRows := IIF( Len( a ) > 0, Val( a[1] ), 1000000 )
   LOCAL cInput := IIF( Len( a ) > 1, a[2], "bench/work/data.jsonl" )
   LOCAL cDbBase := IIF( Len( a ) > 2, a[3], "bench/work/xhb_bench" )

   LOCAL cDbf := cDbBase + ".dbf"
   LOCAL cCdx := cDbBase + ".cdx"
   LOCAL cTags := cDbBase + ".cdx"
   LOCAL lr, h, i
   LOCAL aId := {}, aCode := {}, aAmount := {}, aFlag := {}
   LOCAL t0, t1

   hb_DirCreate( hb_FNamePath( cDbf ) )

   IF !hb_FileExists( cInput )
      ConOut( '{"error":"missing input","path":"' + cInput + '"}' + hb_eol() )
      Quit( 1 )
      RETURN
   ENDIF

   /* Untimed: parse JSONL into compact arrays */
   lr := LineReaderOpen( cInput, 65536 )
   IF lr["fh"] < 0
      ConOut( '{"error":"cannot open input","path":"' + cInput + '"}' + hb_eol() )
      Quit( 1 )
      RETURN
   ENDIF

   i := 0
   DO WHILE i < nRows .AND. LineReaderNext( @lr )
      IF Empty( lr["line"] )
         LOOP
      ENDIF
      h := JsonParse( lr["line"] )
      AAdd( aId, Val( IIF( "id" $ h, h["id"], 0 ) ) )
      AAdd( aCode, IIF( "code" $ h, h["code"], "" ) )
      AAdd( aAmount, Val( IIF( "amount" $ h, h["amount"], 0 ) ) )
      AAdd( aFlag, IIF( "flag" $ h, h["flag"], .f. ) )
      i++
   ENDDO
   LineReaderClose( @lr )

   /* Prepare DBF (delete existing) */
   IF hb_FileExists( cDbf )
      FErase( cDbf )
   ENDIF
   IF hb_FileExists( cCdx )
      FErase( cCdx )
   ENDIF

   rddSetDefault( "DBFCDX" )
   dbCreate( cDbf, { ;
      { "ID", "N", 10, 0 }, ;
      { "CODE", "C", 8, 0 }, ;
      { "AMOUNT", "N", 18, 6 }, ;
      { "FLAG", "L", 1, 0 } ;
   } )

   USE ( cDbf ) EXCLUSIVE NEW

   /* Timed: persistence only */
   t0 := hb_MilliSeconds()
   FOR i := 1 TO Len( aId )
      APPEND BLANK
      REPLACE ID WITH aId[i]
      REPLACE CODE WITH aCode[i]
      REPLACE AMOUNT WITH aAmount[i]
      REPLACE FLAG WITH aFlag[i]
   NEXT
   t1 := hb_MilliSeconds()

   /* Untimed: optional index build (excluded from B3 timing by decision) */
   /* Keep it simple: create a tag on CODE if desired */
   INDEX ON CODE TAG code TO ( cTags )

   CLOSE

   ConOut( '{\"phase\":\"B3_xhb\",\"rows\":' + hb_ntos( Len( aId ) ) + ;
      ',\"millis\":' + hb_ntos( t1 - t0 ) + ;
      ',\"dbf\":\"' + cDbf + '\",\"cdx\":\"' + cCdx + '\"}' + hb_eol() )
RETURN

