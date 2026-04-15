/*
 * B4: DBF → array-of-hashes (materialize all rows in memory).
 *
 * CLI:
 *   b4 <dbf_base> <cache_path>
 *
 * Defaults:
 *   dbf_base: bench/work/xhb_bench
 *   cache_path: bench/work/xhb_cache.jsonl
 *
 * Output: one-line JSON with rows, millis, rolling hash, cache path.
 *
 * Cache format: JSONL canonical lines (amount, code, flag, id) so B5/B6 can
 * reload without re-reading DBF while keeping a deterministic representation.
 */
REQUEST HB_GT_STD_DEFAULT
REQUEST HB_RDDCDX

EXTERNAL JsonEncode

PROCEDURE Main( ... )
   LOCAL a := hb_AParams()
   LOCAL cDbBase := IIF( Len( a ) > 0, a[1], "bench/work/xhb_bench" )
   LOCAL cCache := IIF( Len( a ) > 1, a[2], "bench/work/xhb_cache.jsonl" )
   LOCAL cDbf := cDbBase + ".dbf"
   LOCAL rows := {}, h := 0
   LOCAL t0, t1
   LOCAL fh
   LOCAL id, code, amount, flag
   LOCAL i, hRow, line

   hb_DirCreate( hb_FNamePath( cCache ) )

   IF !hb_FileExists( cDbf )
      ConOut( '{"error":"missing dbf","path":"' + cDbf + '"}' + hb_eol() )
      Quit( 1 )
      RETURN
   ENDIF

   rddSetDefault( "DBFCDX" )
   USE ( cDbf ) SHARED NEW

   t0 := hb_MilliSeconds()
   GO TOP
   DO WHILE !Eof()
      id := ID
      code := CODE
      amount := AMOUNT
      flag := FLAG
      hRow := {=>}
      hRow["id"] := id
      hRow["code"] := code
      hRow["amount"] := amount
      hRow["flag"] := flag
      AAdd( rows, hRow )
      SKIP
   ENDDO
   t1 := hb_MilliSeconds()

   CLOSE

   /* Persist cache as canonical JSONL (also produces deterministic hash) */
   fh := FCreate( cCache )
   IF fh < 0
      ConOut( '{"error":"cannot create cache","path":"' + cCache + '"}' + hb_eol() )
      Quit( 1 )
      RETURN
   ENDIF

   FOR i := 1 TO Len( rows )
      line := CanonicalLine( rows[i] )
      /* rolling 32-bit-ish hash (same as b2.prg char hash style) */
      h := HashLine32( h, line )
      FWrite( fh, line + hb_eol() )
   NEXT
   FClose( fh )

   ConOut( '{\"phase\":\"B4_xhb\",\"rows\":' + hb_ntos( Len( rows ) ) + ;
      ',\"millis\":' + hb_ntos( t1 - t0 ) + ;
      ',\"hash32\":' + hb_ntos( h ) + ;
      ',\"cache\":\"' + cCache + '\"}' + hb_eol() )
RETURN

STATIC FUNCTION CanonicalLine( hRow )
   LOCAL id := hRow["id"]
   LOCAL code := hRow["code"]
   LOCAL amount := hRow["amount"]
   LOCAL flag := hRow["flag"]
RETURN '{\"amount\":' + AllTrim( Str( amount ) ) + ;
   ',\"code\":\"' + code + '\",\"flag\":' + IIF( flag, "true", "false" ) + ;
   ',\"id\":' + AllTrim( Str( id ) ) + '}'

STATIC FUNCTION HashLine32( acc, cLine )
   LOCAL j, ch
   FOR j := 1 TO Len( cLine )
      ch := Asc( SubStr( cLine, j, 1 ) )
      acc := acc * 1315423911 + ch
      acc := acc - Int( acc / 4294967296 ) * 4294967296
   NEXT
RETURN acc

