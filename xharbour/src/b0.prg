/*
 * B0: 32-bit wrapping checksum (matches Rust b0_checksum_u32 for n <= 2^32-1).
 * Build: hbmk2 b0.prg -o../bin/b0
 * Run:   ./b0 1000000
 */
REQUEST HB_GT_STD_DEFAULT

PROCEDURE Main( ... )
   LOCAL a := hb_AParams()
   LOCAL nRows, i, acc := 0, t0, t1, mul := 1315423911
   LOCAL modu := 4294967296, x

   nRows := IIF( Len( a ) > 0, Val( a[1] ), 1000000 )

   t0 := hb_MilliSeconds()
   FOR i := 1 TO nRows
      x := acc * mul + i
      acc := x - Int( x / modu ) * modu
   NEXT
   t1 := hb_MilliSeconds()

   ConOut( '{"phase":"B0_xhb","rows":' + hb_ntos( nRows ) + ',"millis":' + hb_ntos( t1 - t0 ) + ;
      ',"checksum_u32":' + hb_ntos( acc ) + '}' + hb_eol() )
RETURN

