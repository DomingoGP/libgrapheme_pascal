unit grapheme_dynamic;

{$ifdef FPC}{$mode delphi}{$endif}

interface

uses
  Classes, SysUtils;

{.$define LOAD_DYNAMICALLY}

// if load_dynamically use () to call functions or procedures without parameters
// wS:=Version();  //ok  wS:=Version;  //error.

{$IFDEF LOAD_DYNAMICALLY}
  {$DEFINE LD}
{$ENDIF}


const
  GRAPHEME_INVALID_CODEPOINT{: uint32} = $FFFD;

  {$IF Defined(MSWINDOWS)}
  LibGraphemeFileName = 'libgrapheme.dll'; { Setup as you need }
  {$ELSEIF Defined(DARWIN)}
    LibGraphemeFileName = 'libgrapheme.dylib';
  {$ELSEIF Defined(UNIX)}
    LibGraphemeFileName = 'libgrapheme.so';
  {$IFEND}

type
  Pgrapheme_bidirectional_direction = ^grapheme_bidirectional_direction;
  grapheme_bidirectional_direction = (
    GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL,
    GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR,
    GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL
    );

  Psize_t = ^size_t;
  Puint_least32_t = PUInt32;
  uint_least32_t = UInt32;
  Pint_least32_t = PInt32;
  int_least32_t = Int32;
  Puint_least16_t = PUInt16;
  uint_least16_t = UInt16;
  Pint_least16_t = PInt16;
  int_least16_t = Int16;
  uint_least8_t = UInt8;
  Pint_least8_t = PInt8;
  int_least8_t = Int8;


{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_bidirectional_get_line_embedding_levels{$IFDEF LD}: function{$ENDIF}(const p1: PUint_least32_t; p2: size_t;
p3: PInt_least8_t; p4: size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}

{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_bidirectional_preprocess_paragraph{$IFDEF LD}: function{$ENDIF}(const p1: PUint_least32_t; p2: size_t;
p3: grapheme_bidirectional_direction;
p4: PUint_least32_t; p5: size_t;
p6: Pgrapheme_bidirectional_direction): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}

{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_bidirectional_reorder_line{$IFDEF LD}: function{$ENDIF}(const p1: PUint_least32_t; const p2: PUint_least32_t;
p3: size_t; p4: PUint_least32_t; p5: size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}

{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_decode_utf8{$IFDEF LD}: function{$ENDIF}(const AStr: pansichar; ALen: size_t; ACp: PUint_least32_t): size_t; cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_encode_utf8{$IFDEF LD}: function{$ENDIF}(ACp: Uint_least32_t; AStr: pansichar; ALen: size_t): size_t; cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}

{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_is_character_break{$IFDEF LD}: function{$ENDIF}(cp0: uint_least32_t; cp1: uint_least32_t; s: Puint_least16_t): boolean;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}


{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_is_uppercase{$IFDEF LD}: function{$ENDIF}(const src: Puint_least32_t; srclen: size_t; caselen: Psize_t): boolean;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_is_lowercase{$IFDEF LD}: function{$ENDIF}(const src: Puint_least32_t; srclen: size_t; caselen: Psize_t): boolean;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_is_titlecase{$IFDEF LD}: function{$ENDIF}(const src: Puint_least32_t; srclen: size_t; caselen: Psize_t): boolean;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}

{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_is_uppercase_utf8{$IFDEF LD}: function{$ENDIF}(const src: pansichar; srclen: size_t; caselen: Psize_t): boolean;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_is_lowercase_utf8{$IFDEF LD}: function{$ENDIF}(const src: pansichar; srclen: size_t; caselen: Psize_t): boolean;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_is_titlecase_utf8{$IFDEF LD}: function{$ENDIF}(const src: pansichar; srclen: size_t; caselen: Psize_t): boolean;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}

{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_next_character_break{$IFDEF LD}: function{$ENDIF}(const Astr: Puint_least32_t; len: size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_next_line_break{$IFDEF LD}: function{$ENDIF}(const str: Puint_least32_t; len: size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_next_sentence_break{$IFDEF LD}: function{$ENDIF}(const str:Puint_least32_t;len:size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_next_word_break{$IFDEF LD}: function{$ENDIF}(const p1: PUint_least32_t; p2: size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}

{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_next_character_break_utf8{$IFDEF LD}: function{$ENDIF}(const Astr: pansichar; len: size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_next_line_break_utf8{$IFDEF LD}: function{$ENDIF}(const str: pansichar; len: size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_next_sentence_break_utf8{$IFDEF LD}: function{$ENDIF}(const str:PAnsiChar;len:size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_next_word_break_utf8{$IFDEF LD}: function{$ENDIF}(const p1: pansichar; p2: size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}

{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_to_uppercase{$IFDEF LD}: function{$ENDIF}(const src: Puint_least32_t; srclen: size_t; dest: Puint_least32_t; destlen: size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_to_lowercase{$IFDEF LD}: function{$ENDIF}(const src: Puint_least32_t; srclen: size_t; dest: Puint_least32_t; destlen: size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_to_titlecase{$IFDEF LD}: function{$ENDIF}(const src: Puint_least32_t; srclen: size_t; dest: Puint_least32_t; destlen: size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}

{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_to_uppercase_utf8{$IFDEF LD}: function{$ENDIF}(const src: pansichar; srclen: size_t; dest: pansichar; destlen: size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_to_lowercase_utf8{$IFDEF LD}: function{$ENDIF}(const src: pansichar; srclen: size_t; dest: pansichar; destlen: size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}
{$IFDEF LD}var{$ELSE}function{$ENDIF} grapheme_to_titlecase_utf8{$IFDEF LD}: function{$ENDIF}(const src: pansichar; srclen: size_t; dest: pansichar; destlen: size_t): size_t;cdecl; {$IFNDEF LD}external LibGraphemeFileName;{$ENDIF}

function LibGraphemeLoaded: boolean;
function LibGraphemeLoad(const libfilename: string): boolean;
procedure LibGraphemeUnload;

implementation


{$IFDEF LOAD_DYNAMICALLY}
uses
  DynLibs
//  linuxlib and darwinlib are part of BGRABitmap package.
//  I don't want this dependence at the moment.
//  {$ifdef linux}, linuxlib{$endif}
//  {$ifdef darwin}, darwinlib{$endif}
  ;

var
  LibHandle: TLibHandle = dynlibs.NilHandle;
  // this will hold our handle for the lib; it functions nicely as a mutli-lib prevention unit as well...
  LibGraphemeRefCount: longword = 0;  // Reference counter

function LibGraphemeLoaded: boolean;
begin
  Result := (LibHandle <> dynlibs.NilHandle);
end;

function LibGraphemeLoad(const libfilename: string): boolean;
var
  thelib: string;
begin
  Result := False;
  if LibHandle <> 0 then
  begin
    Inc(LibGraphemeRefCount);
    Result := True; {is it already there ?}
  end
  else
  begin {go & load the library}
    if libfilename <> '' then
    begin
      thelib := libfilename;
      if Pos(DirectorySeparator, thelib) = 0 then
        thelib := ExtractFilePath(ParamStr(0)) + DirectorySeparator + thelib;
      LibHandle := DynLibs.SafeLoadLibrary(libfilename); // obtain the handle we want
    end
    else
    begin
      {$ifdef linux}
      //TODO: Implement FindLinuxLibrary
      //thelib := FindLinuxLibrary(LibGraphemeFileName);
      thelib := LibGraphemeFileName;
      {$else}
      {$ifdef darwin}
      //TODO: Implement FindDarwinLibrary
      //thelib := FindDarwinLibrary(LibGraphemeFileName);
      thelib := LibGraphemeFileName;
      {$else}
      thelib := ExtractFilePath(ParamStr(0)) + DirectorySeparator + LibGraphemeFileName;
      {$endif}
      {$endif}
      if thelib <> '' then
        LibHandle := DynLibs.SafeLoadLibrary(thelib); // obtain the handle we want
    end;
    if LibHandle <> DynLibs.NilHandle then
    begin {now we tie the functions to the VARs from above}
      grapheme_bidirectional_get_line_embedding_levels :=
        DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_bidirectional_get_line_embedding_levels'));
      grapheme_bidirectional_preprocess_paragraph := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_bidirectional_preprocess_paragraph'));
      grapheme_bidirectional_reorder_line := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_bidirectional_reorder_line'));
      grapheme_decode_utf8 := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_decode_utf8'));
      grapheme_encode_utf8 := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_encode_utf8'));
      grapheme_is_character_break := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_is_character_break'));
      grapheme_is_uppercase := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_is_uppercase'));
      grapheme_is_lowercase := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_is_lowercase'));
      grapheme_is_titlecase := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_is_titlecase'));
      grapheme_is_uppercase_utf8 := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_is_uppercase_utf8'));
      grapheme_is_lowercase_utf8 := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_is_lowercase_utf8'));
      grapheme_is_titlecase_utf8 := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_is_titlecase_utf8'));
      grapheme_next_character_break := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_next_character_break'));
      grapheme_next_line_break := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_next_line_break'));
      grapheme_next_sentence_break := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_next_sentence_break'));
      grapheme_next_word_break := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_next_word_break'));
      grapheme_next_character_break_utf8 := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_next_character_break_utf8'));
      grapheme_next_line_break_utf8 := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_next_line_break_utf8'));
      grapheme_next_sentence_break_utf8 := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_next_sentence_break_utf8'));
      grapheme_next_word_break_utf8 := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_next_word_break_utf8'));
      grapheme_to_uppercase := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_to_uppercase'));
      grapheme_to_lowercase := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_to_lowercase'));
      grapheme_to_titlecase := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_to_titlecase'));
      grapheme_to_uppercase_utf8 := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_to_uppercase_utf8'));
      grapheme_to_lowercase_utf8 := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_to_lowercase_utf8'));
      grapheme_to_titlecase_utf8 := DynLibs.GetProcedureAddress(LibHandle, pansichar('grapheme_to_titlecase_utf8'));
    end;
    Result := LibGraphemeLoaded;
    LibGraphemeRefCount := 1;
  end;
end;

procedure LibGraphemeUnload;
begin
  // < Reference counting
  if LibGraphemeRefCount > 0 then
    Dec(LibGraphemeRefCount);
  if LibGraphemeRefCount > 0 then
    exit;
  // >
  if LibGraphemeLoaded then
  begin
    DynLibs.UnloadLibrary(LibHandle);
    LibHandle := DynLibs.NilHandle;
  end;
end;

{$ELSE}

function LibGraphemeLoaded: boolean;
begin
  Result := True;
end;

function LibGraphemeLoad(const libfilename: string): boolean;
begin
  Result := True;
  //do nothing
end;

procedure LibGraphemeUnload;
begin
  //do nothing
end;
{$ENDIF}


end.
