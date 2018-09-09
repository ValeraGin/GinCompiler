unit SystemUnit;

{$reference 'System.dll'}

uses System;

// обьявление типов
type
  int64 = System.Int64;
  uint64 = System.UInt64;
  integer = System.Int32;
  longint = System.Int32;
  longword = System.UInt32;
  cardinal = System.UInt32;
  smallint = System.Int16; 
  word = System.UInt16; 
  shortint = System.SByte; 
  byte = System.Byte; 
  boolean = System.Boolean; 
  real = System.Double; 
  double = System.Double; 
  char = System.Char; 
  string = System.String; 
  object = System.Object;

// Вызов функции из обычной библиотеки, а не .net
function MessageBox(h: integer; m: string; c: string; t: integer): integer; 
  external 'User32.dll' name 'MessageBox'; 

function GetResourceStream(ResourceFileName: string): System.IO.Stream;
begin
  result := System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream(ResourceFileName);
end;

function readln: string;
begin
  Result := Console.ReadLine;
end;

function StrToInt(s: string): integer;
begin
  Result := Convert.ToInt32(s); 
end;

function IntToStr(i: integer): string;
begin
  Result := i.ToString; 
end;

procedure write(obj: object);
begin
  if obj<>nil then System.Console.Write(obj);
end;

procedure writeln(obj: object);
begin
  if obj<>nil then System.Console.WriteLine(obj);
end;


function GetEXEFileName: string;
begin
  Result := System.Reflection.Assembly.GetEntryAssembly().ManifestModule.FullyQualifiedName;
end;

procedure Sleep(ms: integer);
begin
  System.Threading.Thread.Sleep(ms);
end;

function Length(a: &Array): integer;
begin
  if a = nil then
    Result := 0
  else Result := a.Length;
end;


procedure Halt(exitCode: integer);
begin
  System.Environment.&Exit(exitCode);
end;

procedure Halt;  // overload обьявлять не надо
begin
  System.Environment.&Exit(0);
end;

begin
end.