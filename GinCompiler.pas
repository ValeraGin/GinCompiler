program GinCompiler; 

{$apptype windows}
{$mainresource Resources\IconRes.res}

//TODO: ������� ��������� try..except, try..finally
//TODO: ������� ���� + ��� char � string
//TODO: ����������� ������������ ��� 
// type Months = (January,February,March,April,May,June,July,August,September,October,November,December);

uses
  PABCSystem,
  
  System, 
  System.IO, 
  System.Collections,
  System.Collections.Generic,
  
  CompilerIDE,
  
  CompilerUnit,
  
  CommonUnit;

const
  LibSource = 'LibSource';
  
  // %ERRORLEVEL%
  ERROR_SUCCESS = 0;
  ERROR_BAD_PARAMETERS = 2;
  ERROR_OTHER = 4;


function WINAPI_AllocConsole: longword; external 'kernel32.dll' name 'AllocConsole';



procedure ColorWriteln(s: string; cl: ConsoleColor);
begin
 // if COLOR_CMD then 
 // begin
    var clRestore := Console.ForegroundColor;
    Console.ForegroundColor := cl;
    writeln(s);
    Console.ForegroundColor := clRestore;
 // end 
 // else writeln(s);
end;

procedure PrintBanner;
begin
  ColorWriteln(Format('GinCompiler {0} (compiled with PABC.NET)', Version), ConsoleColor.Green);
end;

procedure PrintHelp;
begin
  PrintBanner;
  writeln;
  ColorWriteln('�������������:', ConsoleColor.White);
  writelnFormat('{0} <���������_�����������> [����:][����]���_�����', Reflection.Assembly.GetEntryAssembly.ManifestModule.Name);
  writeln;
  ColorWriteln('                          ��������� �����������', ConsoleColor.White);
  writeln('/help ��� /?                : ������� ������ ������ � ��������� ���������');
  writeln;
  writeln('/nologo                     : ��������� ����� ��������� � ���������');
  writeln;
  writeln('/codepage:<�������_��������>: ���������, ����� ������� �������� �������.');
  writeln('                              ������������ ��� �������� �������� ������.');
  writeln('                              <�������_��������> = utf8|unicode');
  writeln('                                                        |ansi|<�����_���������>');
  writeln;
  writeln('/apptype:<windows|console>  : ��������� ������ ��������� �����');
  writeln;
  writeln('/out:<��������_����>        : ���������� ��� ��������� �����.');
  writeln;
  writeln('/define:<������_����>       : ���������� ������(���) �������� ����������.');
  writeln('                              ��������� ����� �� �������, ��� � �������������');
  writeln('                              ��������� ������������� {define <���>}, ��'); 
  writeln('                              ����������� ����, ��� �������� �����������');
  writeln('                              ������ �� ��� ����� �������.');
  writeln('                              ������������ ����� ","');
  writeln;
  writeln('/reference:<������_������>  : ��������� �� ���������� �� ��������� ');
  writeln('                              ������ ������. ������������ ����� ","');
  writeln('                              ������ ��������� ����������� $reference');
  writeln;
  writeln('/win32res:<win32_�������>   : ��������� ������� Win32(.res), ������� �������');
  writeln('                              �������� � �������� ����. ������������ ����� ","');
  writeln('                              ����� � ������� ���� ��������� ����� ������');  
  writeln('                              ������ ��������� ����������� $win32res');
  writeln;
  writeln('/res:<������_������>        : �������� ��� �����, ��� ������� .NET Framework �');
  writeln('                              �������� ����. ������������ ����� ",".');
  writeln('                              ������ ��������� ����������� $res');
  writeln;
  writeln('Gardens Point LEX/optimize                   : �������� ����������� ����.');
  writeln('/debug                      : ���������� ����� ������������ .pdb �����');
  
  writeln;
  ColorWriteln('�������:', ConsoleColor.White);
  writelnFormat('{0} /nologo /codepage:ansi /define:"debug,win32" "C:\d i r\file.pas"', Path.GetFileNameWithoutExtension(Reflection.Assembly.GetEntryAssembly.ManifestModule.Name));
  writelnFormat('{0} /apptype:windows /reference:"System.Windows.Forms.dll" file.pas', Reflection.Assembly.GetEntryAssembly.ManifestModule.Name);  
  readln;
end;

var
  CmdLineDict: Dictionary<string, string>;



procedure WriteCompilerMessage(Message: MessageInfo);
begin
  writeln(Message.Text);
end;

begin
  System.Environment.ExitCode := ERROR_OTHER;
  
  // ˸���� ������� ��������� ������
  CmdLineDict := new Dictionary<string, string>;
  foreach s: string in CommandLineArgs do 
  begin
    var arr := s.Split(':');
    if arr.Length = 1 then 
      CmdLineDict.Add(arr[0].ToLower, '')
    else if arr.Length = 2 then
      CmdLineDict.Add(arr[0].ToLower, arr[1]);
  end;
  
  if (CommandLineArgs.Length = 0) or (CmdLineDict.Count > CommandLineArgs.Length)
  or CmdLineDict.ContainsKey('/?') or CmdLineDict.ContainsKey('/help')
  or CmdLineDict.ContainsKey('help')  then
  begin
    PrintHelp;
    Environment.&Exit(ERROR_BAD_PARAMETERS);
  end;
  
  if IO.&File.Exists(CommandLineArgs[CommandLineArgs.Length - 1]) then Options.SourceFile := Path.GetFullPath(CommandLineArgs[CommandLineArgs.Length - 1]);
  Options.Optimize := CmdLineDict.ContainsKey('/optimize');
  Options.Debug := CmdLineDict.ContainsKey('/debug');
  
  if CmdLineDict.ContainsKey('/codepage') then
  begin
    var CodepageStr := CmdLineDict['/codepage'].ToLower;
    if CodepageStr = 'utf8' then
      Options.Codepage := Text.Encoding.UTF8
    else if CodepageStr = 'ansi' then
      Options.Codepage := Text.Encoding.GetEncoding(1251)
    else if CodepageStr = 'unicode' then
      Options.Codepage := Text.Encoding.Unicode
      else
    begin
      var CodepageID: integer;
      if TryStrToInt(CodepageStr, CodepageID) then
      begin
        Options.Codepage := Text.Encoding.GetEncoding(CodepageID);
      end
    end;
    if Options.Codepage = nil then raise new Exception(String.Format('���������, ��������� � ��������������� "{0}" �� ����������', CodepageStr));
  end;
  
  if CmdLineDict.ContainsKey('/out') then
    Options.OutFile := Path.GetFullPath(CmdLineDict['/out'])
  else
    Options.OutFile := Path.ChangeExtension(Options.SourceFile, '.exe');
  
  
  if CmdLineDict.ContainsKey('/apptype') then
  begin
    Options.CompilerDirectives.Add(new CompilerDirective('apptype', CmdLineDict['/apptype'].ToLower, new Location));
  end;
  
  if CmdLineDict.ContainsKey('/define') then
  begin
    var arr := CmdLineDict['/define'].Split(',');
    foreach s: string in arr do
      Options.DefineList.Add(s.ToLower);
  end;
  
  if CmdLineDict.ContainsKey('/reference') then
  begin
    var arr := CmdLineDict['/reference'].Split(',');
    foreach s: string in arr do
      Options.CompilerDirectives.Add(new CompilerDirective('reference', s.ToLower, new Location));
  end;
  
  if CmdLineDict.ContainsKey('/win32res') then
  begin
    var arr := CmdLineDict['/win32res'].Split(',');
    foreach s: string in arr do
      Options.CompilerDirectives.Add(new CompilerDirective('win32res', s.ToLower, new Location));
  end;
  
  if CmdLineDict.ContainsKey('/res') then
  begin
    var arr := CmdLineDict['/res'].Split(',');
    foreach s: string in arr do
      Options.CompilerDirectives.Add(new CompilerDirective('res', s.ToLower, new Location));
  end;
  
  if CmdLineDict.ContainsKey('/gui') then
  begin
      // �������� ���� WinXP
    System.Windows.Forms.Application.EnableVisualStyles;
    
    // ��������� ����������
    System.Windows.Forms.Application.Run(new EditorForm);
    
  end else
  begin
    if not CmdLineDict.ContainsKey('/nologo') then PrintBanner;
    
   var Cmp := new Compiler;
   Cmp.Compile(WriteCompilerMessage);
    
    WINAPI_AllocConsole;
  end;
  
   Environment.&Exit(ERROR_SUCCESS);
end.