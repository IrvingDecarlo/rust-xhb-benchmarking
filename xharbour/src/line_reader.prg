/*
 * Buffered line reader for JSONL-sized files.
 *
 * Usage:
 *   LOCAL lr := LineReaderOpen( "path" )
 *   DO WHILE LineReaderNext( @lr )
 *      ? lr["line"]
 *   ENDDO
 *   LineReaderClose( @lr )
 */
REQUEST HB_GT_STD_DEFAULT

FUNCTION LineReaderOpen( cPath, nBufSize )
   LOCAL h := {=>}
   LOCAL fh := FOpen( cPath )

   IF nBufSize == NIL .OR. nBufSize <= 0
      nBufSize := 65536
   ENDIF

   h["path"] := cPath
   h["fh"] := fh
   h["bufsize"] := nBufSize
   h["buf"] := Space( nBufSize )
   h["carry"] := ""
   h["nread"] := 0
   h["pos"] := 1
   h["line"] := ""
   h["eof"] := .f.
RETURN h

FUNCTION LineReaderClose( h )
   IF ValType( h ) == "H" .AND. h:hasKey( "fh" ) .AND. h["fh"] >= 0
      FClose( h["fh"] )
   ENDIF
RETURN NIL

STATIC FUNCTION _FillBuffer( h )
   LOCAL n
   IF h["eof"]
      RETURN 0
   ENDIF
   n := FRead( h["fh"], @h["buf"], h["bufsize"] )
   IF n <= 0
      h["eof"] := .t.
      h["nread"] := 0
      h["pos"] := 1
      RETURN 0
   ENDIF
   h["nread"] := n
   h["pos"] := 1
RETURN n

FUNCTION LineReaderNext( h )
   LOCAL i, ch, nlen, cLine

   h["line"] := ""
   cLine := h["carry"]
   h["carry"] := ""

   DO WHILE .t.
      IF h["pos"] > h["nread"]
         IF _FillBuffer( h ) <= 0
            IF !Empty( cLine )
               h["line"] := cLine
               RETURN .t.
            ENDIF
            RETURN .f.
         ENDIF
      ENDIF

      nlen := h["nread"]
      FOR i := h["pos"] TO nlen
         ch := SubStr( h["buf"], i, 1 )
         IF ch == Chr(10)
            h["pos"] := i + 1
            IF Right( cLine, 1 ) == Chr(13)
               cLine := Left( cLine, Len( cLine ) - 1 )
            ENDIF
            h["line"] := cLine
            RETURN .t.
         ENDIF
         cLine += ch
      NEXT
      h["pos"] := nlen + 1
   ENDDO
RETURN .f.

