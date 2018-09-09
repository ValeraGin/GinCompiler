program GinCompiler; 

{$apptype windows}
{$mainresource Resources\IconRes.res}

//TODO: Сделать нормально try..except, try..finally
//TODO: Сделать знак + для char и string
//TODO: Реализовать перечислимый тип 
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
  ColorWriteln('Использование:', ConsoleColor.White);
  writelnFormat('{0} <параметры_компилятора> [диск:][путь]имя_файла', Reflection.Assembly.GetEntryAssembly.ManifestModule.Name);
  writeln;
  ColorWriteln('                          ПАРАМЕТРЫ КОМПИЛЯТОРА', ConsoleColor.White);
  writeln('/help или /?                : Выводит данную помощь и завершает программу');
  writeln;
  writeln('/nologo                     : Запрещает вывод сообщения о программе');
  writeln;
  writeln('/codepage:<кодовая_страница>: Указывает, какую кодовую страницу следует.');
  writeln('                              использовать при открытии исходных файлов.');
  writeln('                              <кодовая_страница> = utf8|unicode');
  writeln('                                                        |ansi|<номер_кодировки>');
  writeln;
  writeln('/apptype:<windows|console>  : Указывает формат выходного файла');
  writeln;
  writeln('/out:<выходной_файл>        : Определяет имя выходного файла.');
  writeln;
  writeln('/define:<список_имен>       : Определяет символ(имя) условной компиляции.');
  writeln('                              Оказывает такое же влияние, что и использование');
  writeln('                              директивы препроцессора {define <имя>}, за'); 
  writeln('                              исключением того, что параметр компилятора');
  writeln('                              влияет на все файлы проекта.');
  writeln('                              Перечисление через ","');
  writeln;
  writeln('/reference:<список_сборок>  : Ссылается на метаданные из указанных ');
  writeln('                              файлов сборки. Перечисление через ","');
  writeln('                              Аналог директивы компилятора $reference');
  writeln;
  writeln('/win32res:<win32_ресурсы>   : Указывает ресурсы Win32(.res), которые следует');
  writeln('                              вставить в выходной файл. Перечисление через ","');
  writeln('                              Нужен к примеру если программе нужна иконка');  
  writeln('                              Аналог директивы компилятора $win32res');
  writeln;
  writeln('/res:<список_файлов>        : Включает эти файлы, как ресурсы .NET Framework в');
  writeln('                              выходной файл. Перечисление через ",".');
  writeln('                              Аналог директивы компилятора $res');
  writeln;
  writeln('Gardens Point LEX/optimize                   : Включает оптимизацию кода.');
  writeln('/debug                      : Компилятор будет генерировать .pdb файлы');
  
  writeln;
  ColorWriteln('Примеры:', ConsoleColor.White);
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
  
  // Лёгкий парсинг командной строки
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
    if Options.Codepage = nil then raise new Exception(String.Format('кодировка, связанная с идентификатором "{0}" не существует', CodepageStr));
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
      // Включаем тему WinXP
    System.Windows.Forms.Application.EnableVisualStyles;
    
    // Запускаем приложение
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