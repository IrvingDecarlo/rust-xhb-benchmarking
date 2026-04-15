*****************************************************************
* JsonParse(cjson)
*
* Funcao para desserializar uma string json
*
* @param cjson : string json
*
* @return Hash + array da string desserializada
*****************************************************************
function JsonParse ( cJson )
local nPos := 1
return JsonValue( cJson, @nPos )

function JsonSkip( cJson, nPos )
do while nPos <= Len(cJson) .and. ;
         SubStr(cJson,nPos,1) $ " " + Chr(9) + Chr(10) + Chr(13)
   nPos++
enddo
return nPos

function JsonValue( cJson, nPos )
local c
nPos := JsonSkip( cJson, nPos )
c := SubStr( cJson, nPos, 1 )
do case
   case c == "{"
      return JsonObject( cJson, @nPos )
   case c == "["
      return JsonArray( cJson, @nPos )
   case c == '"'
      return JsonString( cJson, @nPos )
   case c $ "-0123456789"
      return JsonNumber( cJson, @nPos )
   case SubStr(cJson,nPos,4) == "true"
      nPos += 4
      return .t.
   case SubStr(cJson,nPos,5) == "false"
      nPos += 5
      return .f.
   case SubStr(cJson,nPos,4) == "null"
      nPos += 4
      return nil
endcase
return nil

function JsonObject( cJson, nPos )
local h := {=>}
local k,v
nPos++
do while nPos <= Len(cJson)
   nPos := JsonSkip(cJson,nPos)
   if SubStr(cJson,nPos,1) == "}"
      nPos++
      exit
   endif
   k := JsonString( cJson, @nPos )
   nPos := JsonSkip(cJson,nPos)
   nPos++
   v := JsonValue( cJson, @nPos )
   h[k] := v
   nPos := JsonSkip(cJson,nPos)
   if SubStr(cJson,nPos,1) == "}"
      nPos++
      exit
   endif
   if SubStr(cJson,nPos,1) == ","
      nPos++
   endif
enddo
return h

function JsonArray( cJson, nPos )
local a := {}
local v
nPos++
do while nPos <= Len(cJson)
   nPos := JsonSkip(cJson,nPos)
   if SubStr(cJson,nPos,1) == "]"
      nPos++
      exit
   endif
   v := JsonValue( cJson, @nPos )
   AAdd( a, v )
   nPos := JsonSkip(cJson,nPos)
   if SubStr(cJson,nPos,1) == "]"
      nPos++
      exit
   endif
   if SubStr(cJson,nPos,1) == ","
      nPos++
   endif
enddo
return a

function JsonString( cJson, nPos )
local c := ""
local ch
nPos++
do while nPos <= Len(cJson)
   ch := SubStr(cJson,nPos,1)
   if ch == '"'
      nPos++
      exit
   endif
   if ch == "\"
      nPos++
      ch := SubStr(cJson,nPos,1)
      do case
         case ch == '"'
            c += '"'
         case ch == "\"
            c += "\"
         case ch == "/"
            c += "/"
         case ch == "n"
            c += Chr(10)
         case ch == "r"
            c += Chr(13)
         case ch == "t"
            c += Chr(9)
         case ch == "u"
            c += Chr( Val( "0x" + SubStr(cJson,nPos+1,4) ) )
            nPos += 4
         other
            c += ch
      endcase
   else
      c += ch
   endif
   nPos++
enddo
return c

function JsonNumber( cJson, nPos )
local c := ""
local ch
do while nPos <= Len(cJson)
   ch := SubStr(cJson,nPos,1)
   if !( ch $ "-0123456789.eE" )
      exit
   endif
   c += ch
   nPos++
enddo
return Val(c)

*****************************************************************
* JsonEncode(x)
*
* Serializa um objeto JSON para uma string.
*
* @param x Objeto JSON
*
* @return O objeto JSON convertido a uma string JSON, ou:
* "null" se o objeto for nil.
*****************************************************************
function JsonEncode( x )
local cT := ValType(x)
do case
   case cT == "U"
      return "null"
   case cT == "L"
      return iif( x, "true", "false" )
   case cT == "N"
      return JsonEncodeNumber( x )
   case cT == "C"
      return '"' + JsonEncodeString( x ) + '"'
   case cT == "H"
      return JsonEncodeObject( x )
   case cT == "A"
      return JsonEncodeArray( x )
endcase
return "null"

function JsonEncodeNumber( n )
return AllTrim(Str(n))

function JsonKeyToJsonString( k )
local t := ValType(k)
if t == "C"
   return k
endif
if t == "N"
   return AllTrim(Str(k))
endif
if t == "D"
   return DtoS(k)
endif
return ""

function JsonHex4( n )
local s := ""
local d := "0123456789ABCDEF"
local i, q
for i := 1 to 4
   q := n % 16
   s := SubStr( d, q+1, 1 ) + s
   n := Int( n / 16 )
next
return s

function JsonEncodeString( cStr )
local c := ""
local i, n, ch, na
n := Len(cStr)
for i := 1 to n
   ch := SubStr(cStr,i,1)
   na := Asc(ch)
   do case
      case ch == '"'
         c += '\"'
      case ch == '\'
         c += '\\'
      case ch == Chr(8)
         c += '\b'
      case ch == Chr(9)
         c += '\t'
      case ch == Chr(10)
         c += '\n'
      case ch == Chr(12)
         c += '\f'
      case ch == Chr(13)
         c += '\r'
      case na < 32
         c += '\u' + JsonHex4( na )
      otherwise
         c += ch
   endcase
next
return c

function JsonEncodeObject( h )
local i,c,kvp
c := "{"
i=1
for each kvp in h
   if i > 1
      c += ","
   endif
   c += '"' + JsonEncodeString( JsonKeyToJsonString( kvp:key() ) ) + '":'
   c += JsonEncode( kvp:value() )
   i=i+1
next
c += "}"
return c

function JsonEncodeArray( a )
local i, n, c
n := Len(a)
if n == 0
   return "[]"
endif
c := "["
for i := 1 to n
   if i > 1
      c += ","
   endif
   c += JsonEncode( a[i] )
next
c += "]"
return c
