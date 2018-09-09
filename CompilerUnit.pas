unit CompilerUnit;

//TODO: ������� ��������� try..except, try..finally
//TODO: ������� ����� + ��� char � string
//TODO: ����������� ������������ ��� 
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
  
  Compiler = class
  private 
    procedure CompilerMessage(msg: string);
    function GetSyntaxTree(UnitName: string; Dir: string): UnitTree;
  public 
    function Compile(OutputProc: MessageProc): boolean;
  end;



procedure Compiler.CompilerMessage(msg: string);
begin
  OutputProc(new MessageInfo(msg));
end;

/// ������� ������� �������� ������������� ���������� ��� �������� � ���� ��������������� ������ ������� ������
function Compiler.GetSyntaxTree(UnitName: string; Dir: string): UnitTree;
begin
  // ��� ����� ������ Unit 
  var UnitSearchPaths := new List<string>;
  UnitSearchPaths.Add(Dir); // ����� ��� ����� ���� � ������� ������� ������ Unit
  UnitSearchPaths.Add(Path.Combine(Path.GetDirectoryName(GetEXEFilename), LibSource));
  UnitSearchPaths.Add(Environment.CurrentDirectory); // ������� �����
  UnitSearchPaths.Add(Path.GetDirectoryName(GetEXEFilename)); // ��� ��������� ��� ����������
  
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



function Compiler.Compile(OutputProc: MessageProc): boolean;
begin
  {$UNDEF NOTDEBUG}
  {$IFDEF NOTDEBUG}
 // try
  {$ENDIF}
    Result := true;
    CommonUnit.OutputProc := OutputProc;
    
    &File.Delete(Options.OutFile);
    
    CompilerMessage(Format('����� ���������� "{0}"...', Path.GetFileName(Options.SourceFile)));
    // ���������� �������� � 4 �������:
    
    // ����������� ������. �� ���� ����� ������������������ �������� ��������� ����� ������������� � ������������������ ������.
    // ��������� ��� ������� �������������
    var startCompileTime := Milliseconds;
    
    Scanner := new GScanner(Options.SourceFile, Options.DefineList);
    
    var ScanTime := Milliseconds - startCompileTime;
    
    // �������������� (��������������) ������. ������������������ ������ ������������� � ������ �������.
    Parser := new GParser(Scanner.Tokens, Options.SourceFile);
    
    var ParsTime := Milliseconds - (ScanTime + startCompileTime);
    
    // ������������� ������. ������ ������� �������������� � ����� ������������ ��� ��������� (������)
    Converter := new GConverter(Parser.SyntaxTree, GetSyntaxTree);
    
    var TreeConvertTime := Milliseconds - (ScanTime + startCompileTime + ParsTime);
    
    
    // ��������� ����. �� �������������� ������ ����������� MSIL ���.
    if (Converter.SemanticTree is SUnitTree) then raise new Exception('��������� ��������� ��� ����������, � �� ������.');
    
    CodeGenerator := new GCodeGenerator(Options.OutFile, Converter.SemanticTree);  
    
    var CodeGenTime := Milliseconds - (ScanTime + startCompileTime + ParsTime + TreeConvertTime);
    var CompileTime := Milliseconds - startCompileTime;
    
    // ===========================================================================
    
    
    
    CompilerMessage(Format('���������� "{0}" ��������� �������.', Path.GetFileName(Options.SourceFile)));
    
    CompilerMessage('                     ����� ������ ');
    CompilerMessage(Format('1.������������ � ������������          :{0} �� ({1:f2}%)',  ScanTime, (ScanTime / CompileTime) * 100));
    CompilerMessage(Format('2.�������                              :{0} �� ({1:f2}%)',  ParsTime, (ParsTime / CompileTime) * 100));
    CompilerMessage(Format('3.��������������� ������ � ����������� :{0} �� ({1:f2}%)',  TreeConvertTime, (TreeConvertTime / CompileTime) * 100));
    CompilerMessage(Format('4.�������������                        :{0} �� ({1:f2}%)',  CodeGenTime, (CodeGenTime / CompileTime) * 100));
    CompilerMessage(Format('  ����� ����� ������ ���������         :{0} ��',  CompileTime));
   {$IFDEF NOTDEBUG} 
 {* except
    on e: Exception do
    begin
      Result := False;
      if e is ScannerException then 
      begin
        var exp := (e as ScannerException);
        OutputProc(new MessageInfo( string.Format('[{0},{1}] SCANNER_ERROR: {2}: {3}', exp.Loc.BeginLine, exp.Loc.BeginColumn, exp.Loc.FileName, exp.Message), Error, exp.Loc));
      end
       else 
      if e is ParserException then 
      begin
        var exp := (e as ParserException);
        OutputProc( new MessageInfo( string.Format('[{0},{1}] PARSER_ERROR: {2}', exp.Loc.BeginLine, exp.Loc.BeginColumn, exp.Message), Error, exp.Loc));
      end
       else 
      if e is SemanticException then 
      begin
        var exp := (e as SemanticException);
        OutputProc( new MessageInfo( string.Format('[{0},{1}] SEMANTIC_ERROR: {2}', exp.Loc.BeginLine, exp.Loc.BeginColumn, exp.Message), Error, exp.Loc));
      end
       else
      if e is CodeGenException then 
      begin
        var exp := (e as CodeGenException);
        OutputProc( new MessageInfo( string.Format('[{0},{1}] CODEGEN_ERROR: {2}', exp.Loc.BeginLine, exp.Loc.BeginColumn, exp.Message), Error, exp.Loc));
      end
      else OutputProc( new MessageInfo( string.Format('UNKNOWN_ERROR: {0}', e.Message)));
    end;
  end;
  *}
  {$ENDIF}
end;

begin

end. 