/*
 * Canonical JSON line builder and rolling hash used by xHarbour phases.
 *
 * Canonical key order: amount, code, flag, id
 * Canonical numeric formatting:
 *   - id: integer (no leading spaces)
 *   - amount: fixed 6 decimals (DBF is 18,6)
 */
REQUEST HB_GT_STD_DEFAULT

FUNCTION CanonicalLineFromHash( hRow )
   LOCAL id := hRow["id"]
   LOCAL code := hRow["code"]
   LOCAL amount := hRow["amount"]
   LOCAL flag := hRow["flag"]
RETURN '{\"amount\":' + CanonAmount6( amount ) + ;
   ',\"code\":\"' + code + '\",\"flag\":' + IIF( flag, "true", "false" ) + ;
   ',\"id\":' + CanonInt( id ) + '}'

FUNCTION CanonInt( n )
RETURN AllTrim( Str( Val( n ), 0, 0 ) )

FUNCTION CanonAmount6( n )
   /* Force fixed 6 decimals; Str() may introduce leading spaces, so trim. */
RETURN AllTrim( Str( Val( n ), 0, 6 ) )

FUNCTION HashLine32( acc, cLine )
   LOCAL j, ch
   FOR j := 1 TO Len( cLine )
      ch := Asc( SubStr( cLine, j, 1 ) )
      acc := acc * 1315423911 + ch
      acc := acc - Int( acc / 4294967296 ) * 4294967296
   NEXT
RETURN acc

