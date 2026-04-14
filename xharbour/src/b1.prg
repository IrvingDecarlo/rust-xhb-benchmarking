/*
 * B1: write JSONL (canonical row shape; same semantics as Rust).
 * Run: ./b1 1000000 bench/work/data.jsonl
 */
REQUEST HB_GT_STD_DEFAULT

PROCEDURE Main( ... )
   LOCAL a := hb_AParams()
   LOCAL nRows, outPath, i, fh, t0, t1

   nRows := IIF( Len( a ) > 0, Val( a[1] ), 1000000 )
   outPath := IIF( Len( a ) > 1, a[2], "bench/work/data.jsonl" )

   hb_DirCreate( hb_FNamePath( outPath ) )

   fh := FCreate( outPath )
   IF fh < 0
      ConOut( '{"error":"FCreate failed","path":"' + outPath + '"}' + hb_eol() )
      Quit( 1 )
      RETURN
   ENDIF

   t0 := hb_MilliSeconds()
   FOR i := 0 TO nRows - 1
      FWrite( fh, JsonLineFromId( i ) + hb_eol() )
   NEXT
   t1 := hb_MilliSeconds()
   FClose( fh )

   ConOut( '{"phase":"B1_xhb","rows":' + hb_ntos( nRows ) + ',"millis":' + hb_ntos( t1 - t0 ) + ;
      ',"path":"' + outPath + '"}' + hb_eol() )
RETURN

STATIC FUNCTION JsonLineFromId( k )
   LOCAL amount, code, sFlag, id, m, r100
   id := k
   m := k - Int( k / 10000000 ) * 10000000
   code := "C" + PadL( hb_ntos( m ), 7, "0" )
   r100 := k - Int( k / 100 ) * 100
   amount := k * 0.01 + r100 * 0.001
   sFlag := IIF( k - Int( k / 2 ) * 2 == 0, "true", "false" )
RETURN '{"amount":' + hb_ntos( amount ) + ',"code":"' + code + '","flag":' + sFlag + ',"id":' + hb_ntos( id ) + '}'
