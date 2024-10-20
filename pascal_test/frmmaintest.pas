unit frmMainTest;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

type
  TForm1 = class(TForm)
    btnGraphemeOriginal: TButton;
    btnCodePoints: TButton;
    btnLowerCase: TButton;
    btnTitleCase: TButton;
    btnUpperCase: TButton;
    Button1: TButton;
    Edit1: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    MemoPascal: TMemo;
    MemoC: TMemo;
    procedure btnGraphemeOriginalClick(Sender: TObject);
    procedure btnCodePointsClick(Sender: TObject);
    procedure btnLowerCaseClick(Sender: TObject);
    procedure btnTitleCaseClick(Sender: TObject);
    procedure btnUpperCaseClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure MemoPascalChange(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

implementation

uses
  grapheme_dynamic,grapheme_utf8,grapheme_character,grapheme_case;

{$R *.lfm}

{ TForm1 }

procedure TForm1.MemoPascalChange(Sender: TObject);
begin

end;

function ToHex(Astr:string):string;
var
  i:integer;
begin
  result:='';
  i:=1;
  while i<= length(Astr) do
  begin
    Result:=Result+HexStr(Ord(Astr[i]),2);
    if i<length(Astr) then
      Result:=Result+',';
    Inc(i);
  end;

end;

procedure TForm1.btnCodePointsClick(Sender: TObject);
var
  ret, off, count:size_t;
  cp:UInt32;
  wStr:AnsiString;
  wR:string;
  len:UInt32;
begin
  MemoC.Lines.Clear;
  MemoPascal.Lines.Clear;
  wStr:=Edit1.Text;
  len:=length(wStr);
  MemoC.Lines.Add(Format('(Length: %d ) %s',[len,ToHex(wStr)]));
  MemoPascal.Lines.Add(Format('(Length: %d)  %s',[len,ToHex(wStr)]));

  wR:='';
  count:=0;
  off:=1;
  while off<=Uint32(length(wStr)) do
  begin
    ret:= grapheme_decode_utf8(@wStr[off], len - off + 1, @cp);
      if ret > (len - off + 1) then
      begin
        {*
         * string ended unexpectedly in the middle of a
         * multibyte sequence and we have the choice
         * here to possibly expand str by ret - len + off
         * bytes to get a full sequence, but we just
         * bail out in this case.
         *}
        break;
      end;
      wR:=wR+ HexStr(cp,4)+ ',';
      MemoPascal.Lines.Add(Format('bytes: %d, codepoint: %s',[ret,HexStr(cp,4)]));
    off:=off + ret;
    Inc(count);
  end;
  MemoPascal.Lines.Add(wR);
  MemoPascal.Lines.Add(Format('Count: %d',[count]));

  wR:='';
  count:=0;
  off:=1;
  while off<=Uint32(length(wStr)) do
  begin
    ret:= grapheme_dynamic.grapheme_decode_utf8(@wStr[off], len - off + 1, @cp);
      if ret > (len - off + 1) then
      begin
        {*
         * string ended unexpectedly in the middle of a
         * multibyte sequence and we have the choice
         * here to possibly expand str by ret - len + off
         * bytes to get a full sequence, but we just
         * bail out in this case.
         *}
        break;
      end;
      wR:=wR+ HexStr(cp,4)+ ',';
      MemoC.Lines.Add(Format('bytes: %d, codepoint: %s',[ret,HexStr(cp,4)]));
    off:=off + ret;
    Inc(Count);
  end;
  MemoC.Lines.Add(wR);
  MemoC.Lines.Add(Format('Count: %d',[count]));
end;



procedure TForm1.btnLowerCaseClick(Sender: TObject);
var
  s,s2:string;
  len,len2:integer;
begin
  s:=Edit1.Text;
  len:=length(s);
  if len<=0 then
    exit;

  //calc len
  len2:=grapheme_dynamic.grapheme_to_lowercase_utf8(@s[1],len,nil,0);
  SetLength(s2,len2);
  grapheme_dynamic.grapheme_to_lowercase_utf8(@s[1],len,@s2[1],len2+1);
  MemoC.Lines.Add(s2);

  len2:=grapheme_to_lowercase_utf8(@s[1],len,nil,0);
  SetLength(s2,len2);
  grapheme_to_lowercase_utf8(@s[1],len,@s2[1],len2+1);
  MemoPascal.Lines.Add(s2);
end;

procedure TForm1.btnTitleCaseClick(Sender: TObject);
var
  s,s2:string;
  len,len2:integer;
begin
  s:=Edit1.Text;
  len:=length(s);
  if len<=0 then
    exit;

  //calc len
  len2:=grapheme_dynamic.grapheme_to_titlecase_utf8(@s[1],len,nil,0);
  SetLength(s2,len2);
  grapheme_dynamic.grapheme_to_titlecase_utf8(@s[1],len,@s2[1],len2+1);
  MemoC.Lines.Add(s2);

  len2:=grapheme_to_titlecase_utf8(@s[1],len,nil,0);
  SetLength(s2,len2);
  grapheme_to_titlecase_utf8(@s[1],len,@s2[1],len2+1);
  MemoPascal.Lines.Add(s2);
end;

procedure TForm1.btnUpperCaseClick(Sender: TObject);
var
  s,s2:string;
  len,len2:integer;
begin
  s:=Edit1.Text;
  len:=length(s);
  if len<=0 then
    exit;

  //calc len
  len2:=grapheme_dynamic.grapheme_to_uppercase_utf8(@s[1],len,nil,0);
  SetLength(s2,len2);
  grapheme_dynamic.grapheme_to_uppercase_utf8(@s[1],len,@s2[1],len2+1);
  MemoC.Lines.Add(s2);

  len2:=grapheme_to_uppercase_utf8(@s[1],len,nil,0);
  SetLength(s2,len2);
  grapheme_to_uppercase_utf8(@s[1],len,@s2[1],len2+1);
  MemoPascal.Lines.Add(s2);
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  st:string;
  l:integer;
begin
  st:=Edit1.text;
  MemoPascal.Lines.Add('--------------');
  MemoPascal.Lines.Add(graphemeLowerCase(st));
  MemoPascal.Lines.Add(graphemeUpperCase(st));
  MemoPascal.Lines.Add(graphemeTitleCase(st));
  MemoPascal.Lines.Add('--------------');
  l:=graphemeCountGraphemes(st,1);
  MemoPascal.Lines.Add('Graphemes: '+IntToStr(l));
  l:=graphemeCountGraphemes(@st[1],length(st));
  MemoPascal.Lines.Add('Graphemes: '+IntToStr(l));
  l:=graphemeCountCodePoints(st,1);
  MemoPascal.Lines.Add('CodePoints: '+IntToStr(l));
  l:=graphemeCountCodePoints(@st[1],length(st));
  MemoPascal.Lines.Add('CodePoints: '+IntToStr(l));

  l:=graphemeGraphemeToChars(st,3);
  MemoPascal.Lines.Add('grapheme to chars 3: '+IntToStr(l));

  l:=graphemePosGraphemes('(',st);
  MemoPascal.Lines.Add('grapheme Pos ( grapheme: '+IntToStr(l));

  MemoPascal.Lines.Add('Copy 2 2:'+graphemeCopyGraphemes(st,2,2));


  l:=graphemeCodePointToChars(st,3);
  MemoPascal.Lines.Add('codepoints to chars 3: '+IntToStr(l));

  l:=graphemePosCodePoints('(',st);
  MemoPascal.Lines.Add('codepoints Pos ( codepoint: '+IntToStr(l));

  MemoPascal.Lines.Add('Copy 2 2:'+graphemeCopyCodePoints(st,2,2));

end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  LibGraphemeLoad('');
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  LibGraphemeUnload();
end;


//https://onlinetools.com/unicode/extract-unicode-graphemes
// some samples.
//https://github.com/cometkim/unicode-segmenter/blob/657e31a7cdbaf64769528596d11e6df03e9ee1e7/test/grapheme.js#L103

procedure TForm1.btnGraphemeOriginalClick(Sender: TObject);
var
  len, off, Count: integer;
  ret: size_t;
  s: ansistring;
begin
  s := Edit1.Text;
  len := length(s);

  off := 0;
  Count := 0;
  MemoPascal.Lines.Clear;
  MemoPascal.Lines.Add(s);
  MemoPascal.Lines.Add(Format('grapheme clusters in input delimited to %d bytes:', [len]));
  while off < len do
  begin
    ret := grapheme_next_character_break_utf8(@s[1 + off], len - off);
    MemoPascal.Lines.Add(Format('%d bytes: %s', [ret, Copy(s, 1 + off, ret)]));
    off := off + ret;
    Inc(Count);
  end;
  MemoPascal.Lines.Add(Format('grapheme count: %d', [Count]));


  off := 0;
  Count := 0;
  MemoC.Lines.Clear;
  MemoC.Lines.Add(s);
  MemoC.Lines.Add(Format('grapheme clusters in input delimited to %d bytes:', [len]));
  while off < len do
  begin
    ret := grapheme_dynamic.grapheme_next_character_break_utf8(@s[1 + off], len - off);
    MemoC.Lines.Add(Format('%d bytes: %s', [ret, Copy(s, 1 + off, ret)]));
    off := off + ret;
    Inc(Count);
  end;
  MemoC.Lines.Add(Format('grapheme count: %d', [Count]));


end;
end.

