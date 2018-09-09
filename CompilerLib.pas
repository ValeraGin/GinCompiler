library CompilerLib;

{$mainresource Resources\IconRes.res}

//TODO: Сделать нормально try..except, try..finally
//TODO: Сделать знаки + для char и string
//TODO: Реализовать перечислимый тип 
// type Months = (January,February,March,April,May,June,July,August,September,October,November,December);

uses
  PABCSystem,
  
  System, 
  System.IO, 
  System.Collections,
  System.Collections.Generic,
  
  ASemanticTree,
  ASyntaxTree,
  
  ScannerUnit,
  SyntaxAnalyze,
  TreeConverter,
  CodeGen,
  
  CommonUnit;

const
  LibSource = 'LibSource';

var
  Scanner: GScanner;
  Parser: GParser;
  Converter: GConverter;
  CodeGenerator: GCodeGenerator;

type
  MessageType = (Info, Warning, Error);
  MessageInfo = class
    MType: MessageType;
    Text: string;
    Loc: Location;
  public
    constructor Create(Text: string);
    constructor Create(Text: string; MType: MessageType);
    constructor Create(Text: string; MType: MessageType; Loc: Location);
  end;
  
  MessageProc = procedure(Message: MessageInfo);

  Compiler = class
  private 
    OutputProc : MessageProc;
    function GetSyntaxTree(UnitName: string; Dir: string): UnitTree;
  public 
    procedure CompilerMessage(msg: string);
    procedure Compile(Options: CompilerOptions; OutputProc: MessageProc);
  end;

  var Options : CompilerOptions;
  
 
constructor MessageInfo.Create(Text: string);
begin
  self.Text := Text;
  self.MType := MessageType.Info;
end;

constructor MessageInfo.Create(Text: string; MType: MessageType);
begin
  self.Text := Text;
  self.MType := MType;
end;

constructor MessageInfo.Create(Text: string; MType: MessageType; Loc: Location);
begin
  self.Text := Text;
  self.MType := MType;
  self.Loc := Loc;
end;
 
procedure Compiler.CompilerMessage(msg: string);
begin
  OutputProc(new MessageInfo(msg));
end;

/// функция которую вызывает семантический анализатор для загрузки в него синтаксического дерево нужного модуля
function Compiler.GetSyntaxTree(UnitName: string; Dir: string): UnitTree;
begin
  // Где будем искать Unit 
  var UnitSearchPaths := new List<string>;
  UnitSearchPaths.Add(Dir); // Папка где лежит файл в котором включен данный Unit
  UnitSearchPaths.Add(Path.Combine(Path.GetDirectoryName(GetEXEFilename), LibSource));
  UnitSearchPaths.Add(Environment.CurrentDirectory); // текущая папка
  UnitSearchPaths.Add(Path.GetDirectoryName(GetEXEFilename)); // где находится сам компилятор
  
  foreach s: string in UnitSearchPaths do
  begin
    var fname := Path.Combine(s, UnitName + '.pas');
    if &File.Exists(fname) then
    begin
      var scan := new GScanner(fname, Options.DefineList);
      var pars := new GParser(scan.Tokens, fname);
      Result := (pars.SyntaxTree as UnitTree);
    end;
  end;
  
  if not (Result is UnitTree) then Result := nil;
end;



procedure Compiler.Compile(Options: CompilerOptions; OutputProc: MessageProc);
begin
  CommonUnit.Options := Options;
  self.OutputProc := OutputProc;

  CompilerMessage(Format('Старт компиляции "{0}"...', Path.GetFileName(Options.SourceFile)));
  // Компилятор работает в 4 прохода:
  
  // Лексический анализ. На этом этапе последовательность символов исходного файла преобразуется в последовательность лексем.
  // Выполняет ещё функции препроцессора
  var startCompileTime := Milliseconds;
  
  Scanner := new GScanner(Options.SourceFile, Options.DefineList);
  
  var ScanTime := Milliseconds - startCompileTime;
  
  // Синтаксический (грамматический) анализ. Последовательность лексем преобразуется в дерево разбора.
  Parser := new GParser(Scanner.Tokens, Options.SourceFile);
  
  var ParsTime := Milliseconds - (ScanTime + startCompileTime);
  
  // Семантический анализ. Дерево разбора обрабатывается с целью установления его семантики (смысла)
  Converter := new GConverter(Parser.SyntaxTree, GetSyntaxTree);
  
  var TreeConvertTime := Milliseconds - (ScanTime + startCompileTime + ParsTime);
  
  // Генерация кода. Из семантического дерева порождается MSIL код.
  if (Converter.SemanticTree is SUnitTree) then raise new Exception('ожидалась программа или библиотека, а не модуль.');
  
  
  CodeGenerator := new GCodeGenerator(Options.OutFile, Converter.SemanticTree);  
  
  var CodeGenTime := Milliseconds - (ScanTime + startCompileTime + ParsTime + TreeConvertTime);
  
  // ===========================================================================
  
  CompilerMessage(Format('Компиляция "{0}" завершена успешно.', Path.GetFileName(Options.SourceFile)));
  
  CompilerMessage('                     ВРЕМЯ РАБОТЫ ');
  CompilerMessage(Format('1.Сканирование и препроцессор          :{0} мс ({1:f2}%)',  ScanTime, (ScanTime / Milliseconds) * 100));
  CompilerMessage(Format('2.Парсинг                              :{0} мс ({1:f2}%)',  ParsTime, (ParsTime / Milliseconds) * 100));
  CompilerMessage(Format('3.Конвертирование дерева и оптимизация :{0} мс ({1:f2}%)',  TreeConvertTime, (TreeConvertTime / Milliseconds) * 100));
  CompilerMessage(Format('4.Кодогенерация                        :{0} мс ({1:f2}%)',  CodeGenTime, (CodeGenTime / Milliseconds) * 100));
  CompilerMessage(Format('  Общее время работы программы         :{0} мс',  Milliseconds)); 
end;

begin
  
end. 