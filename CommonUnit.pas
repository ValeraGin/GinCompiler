/// Общий для всех модулей модуль
unit CommonUnit;

uses
  System, 
  System.IO, 
  System.Collections,
  System.Collections.Generic;

const
  Version = '0.6';

type
  TextPos = class
  public 
    FileName: string;
    Line: integer;
    Column: integer;
    constructor Create(Line, Column: integer);
    begin
      self.Line := Line;
      self.Column := Column;
    end;
  end;
  
  Location = class
  public 
    FileName: string;
    BeginLine: integer;
    BeginColumn: integer;
    EndLine: integer;
    EndColumn: integer;
    
    procedure DefineBeginPos(BeginLine, BeginColumn: integer);
    begin
      self.BeginLine := BeginLine;
      self.BeginColumn := BeginColumn;
    end;
    
    procedure DefineBeginPos(BeginPos: TextPos);
    begin
      DefineBeginPos(BeginPos.Line, BeginPos.Column);
    end;
    
    procedure DefineEndPos(EndLine, EndColumn: integer);
    begin
      self.EndLine := EndLine;
      self.EndColumn := EndColumn;
    end;
    
    procedure DefineEndPos(EndPos: TextPos);
    begin
      DefineEndPos(EndPos.Line, EndPos.Column);
    end;
    
    procedure LocCopyFrom(LocObj: Location);
    begin
      FileName := LocObj.FileName;
      BeginLine := LocObj.BeginLine;
      BeginColumn := LocObj.BeginColumn;
      EndLine := LocObj.EndLine;
      EndColumn := LocObj.EndColumn;
    end;
    
    procedure LocCopyFrom(TxtObj: TextPos);
    begin
      FileName := TxtObj.FileName;
      BeginLine := TxtObj.Line;
      BeginColumn := TxtObj.Column;
      EndLine := TxtObj.Line;
      EndColumn := TxtObj.Column;
    end;
  end;
  
  ExceptionWithLocation = class(Exception)
    Loc: Location;
    constructor Create(message: string; Loc: Location);
    begin
      inherited Create(string.Format('[{0},{1}] {2}', Loc.BeginLine, Loc.BeginColumn, Message));
      self.Loc := Loc;
    end;
  end;
  
  
  CompilerDirective = class(Location)
  public 
    Name: string;
    Value: string;
    constructor Create(Name, Value: string; Loc: Location);
    begin
      self.Name := Name;
      self.Value := Value;
      self.LocCopyFrom(Loc);
    end;
  end;
  
  TokenKind = 
  (NO_TOKEN,
  
  KW_LIBRARY, KW_PROGRAM, KW_UNIT,
  
  EOF,
  
  STRING_IDENT,
  
  INTEGER_KIND, FLOAT_KIND, STRING_KIND, CHAR_KIND,
  
  SEMI{;}, ASSIGN{:=}, COLON{:}, DOT{.}, COMMA{,},// SHARP,
  
  PAREN_OPEN{(}, PAREN_CLOSE{)},
  
  SQUARE_BRACKET_OPEN, SQUARE_BRACKET_CLOSE,
  
  KW_VAR,
  
  KW_IF, KW_THEN, KW_ELSE,
  
  KW_FOR, KW_TO, KW_DOWNTO, KW_DO,
  
  KW_WHILE,
  
  KW_REPEAT, KW_UNTIL,
  
  KW_GOTO,
  
  KW_USES,
  
  KW_TYPE,
  
  KW_CONST,
  
  KW_PROCEDURE, KW_FUNCTION, 
  
  CONST_NIL,
  CONST_TRUE,
  CONST_FALSE,
  
  KW_TRY, KW_EXCEPT, KW_FINALLY,
  
  KW_BEGIN, KW_END,   
  
  TK_LOGIC_AND,
  TK_LOGIC_OR,
  TK_LOGIC_NOT,
  TK_LOGIC_XOR,
  
  INT_DIV_OP,
  INT_MOD_OP,
  
  ADD_OP,
  SUB_OP,
  DIV_OP,
  MUL_OP,
  
  ADD_ASSIGN_OP,
  SUB_ASSIGN_OP,
  DIV_ASSIGN_OP,
  MUL_ASSIGN_OP,
  
  TK_EQUAL,
  TK_NO_EQUAL,
  TK_GREATER_THAN,
  TK_GREATER_THAN_OR_EQUAL,
  TK_LESS_THAN, 
  TK_LESS_THAN_OR_EQUAL,
  
  ARRAY_IDENT,
  
  KW_RAISE,
  
  KW_PRINT,
  
  KW_RETURN,
  KW_EXIT,
  
  KW_BREAK,
  KW_CONTINUE
  
  );
  
  CompilerOptions = class
  public 
    Optimize := false;
    Codepage :=  Text.Encoding.GetEncoding(1251);
    CompilerDirectives := new List<CompilerDirective>;
    OutFile: string;
    SourceFile: string;
    Debug := true;
    DefineList := new List<string>;
  end;
  
  MessageType = (Info, Warning, Error);
  MessageInfo = class
  public 
    MType: MessageType;
    Text: string;
    Loc: Location;
    
    constructor Create(Text: string);
    begin
      self.MType := MessageType.Info;
      self.Text := Text;
    end;
    
    constructor Create(Text: string; MType: MessageType);
    begin
      self.Text := Text;
      self.MType := MType;
    end;
    
    constructor Create(Text: string; MType: MessageType; Loc: Location);
    begin
      self.Text := Text;
      self.MType := MType;
      self.Loc := Loc;
    end;
    
    constructor Create(Text: string; MType: MessageType; TxtPos: TextPos);
    begin
      self.Text := Text;
      self.MType := MType;
      self.Loc := new Location();
      self.Loc.FileName := TxtPos.FileName;
      self.Loc.BeginLine := TxtPos.Line;
      self.Loc.BeginColumn := TxtPos.Column;
      self.Loc.EndLine := TxtPos.Line +1; 
      self.Loc.EndColumn := TxtPos.Column +1;
    end;
  end;
  
  MessageProc = procedure(Message: MessageInfo);


var
  OutputProc: MessageProc;
  Options := new CompilerOptions;
  keyword_dict: Dictionary<string, object>;
  token_dict: Dictionary<string, object>;
  TypeSizes: Dictionary<&Type, integer>;


function TokenKind2Str(TK: TokenKind): string;
begin
  foreach pair: KeyValuePair<string, object> in keyword_dict do
  begin
    if pair.Value.Equals(TK) then
    begin
      result := pair.Key;
      exit;
    end;
  end;
  foreach pair: KeyValuePair<string, object> in token_dict do
  begin
    if pair.Value.Equals(TK) then
    begin
      result := pair.Key;
      exit;
    end;
  end;
  result := TK.ToString;
end;

begin
  TypeSizes := new Dictionary<&Type, integer>;
  TypeSizes.Add(typeof(System.Boolean), 1);
  TypeSizes.Add(typeof(System.Byte), 1);
  TypeSizes.Add(typeof(System.SByte), 1);
  TypeSizes.Add(typeof(System.Int16), 2);
  TypeSizes.Add(typeof(System.Int32), 4);
  TypeSizes.Add(typeof(System.Int64), 8);
  TypeSizes.Add(typeof(System.UInt16), 2);
  TypeSizes.Add(typeof(System.UInt32), 4);
  TypeSizes.Add(typeof(System.UInt64), 8);
  TypeSizes.Add(typeof(System.Single), 4);
  TypeSizes.Add(typeof(System.Double), 8);
  TypeSizes.Add(typeof(System.Decimal), 16);
  
  token_dict := new Dictionary<string, object>;
  token_dict.Add('пусто', NO_TOKEN);
  token_dict.Add('конец файла', EOF);
  token_dict.Add('идентификатор', STRING_IDENT);
  token_dict.Add('число', INTEGER_KIND);
  token_dict.Add('число с плавающей точкой', FLOAT_KIND);
  token_dict.Add('строка', STRING_KIND);
  token_dict.Add('символ', CHAR_KIND);
  
  token_dict.Add(';', SEMI);
  token_dict.Add(':=', ASSIGN);
  token_dict.Add(':', COLON);
  token_dict.Add('.', DOT);
  token_dict.Add(',', COMMA);
  
  token_dict.Add('(', PAREN_OPEN);
  token_dict.Add(')', PAREN_CLOSE);
  token_dict.Add('[', SQUARE_BRACKET_OPEN);
  token_dict.Add(']', SQUARE_BRACKET_CLOSE);
  
  token_dict.Add('+', ADD_OP);
  token_dict.Add('-', SUB_OP);
  token_dict.Add('/', DIV_OP);
  token_dict.Add('*', MUL_OP);
  
  token_dict.Add('+=', ADD_ASSIGN_OP);
  token_dict.Add('-=', SUB_ASSIGN_OP);
  token_dict.Add('/=', DIV_ASSIGN_OP);
  token_dict.Add('*=', MUL_ASSIGN_OP);
  
  token_dict.Add('=', TK_EQUAL);
  token_dict.Add('<>', TK_NO_EQUAL);
  token_dict.Add('>', TK_GREATER_THAN);
  token_dict.Add('>=', TK_GREATER_THAN_OR_EQUAL);
  token_dict.Add('<', TK_LESS_THAN);
  token_dict.Add('<=', TK_LESS_THAN_OR_EQUAL);
  
  
  // Создания словаря зарезирвированных слов
  keyword_dict := new Dictionary<string, object>;
  
  keyword_dict.Add('program', KW_PROGRAM);
  keyword_dict.Add('library', KW_LIBRARY);
  keyword_dict.Add('unit', KW_UNIT);
  
  keyword_dict.Add('var', KW_VAR);
  keyword_dict.Add('if', KW_IF);
  keyword_dict.Add('then', KW_THEN);
  keyword_dict.Add('else', KW_ELSE);
  
  keyword_dict.Add('for', KW_FOR);
  keyword_dict.Add('to', KW_TO);
  keyword_dict.Add('downto', KW_DOWNTO);
  keyword_dict.Add('do', KW_DO);
  
  keyword_dict.Add('while', KW_WHILE);
  
  keyword_dict.Add('repeat', KW_REPEAT);
  keyword_dict.Add('until', KW_UNTIL);
  
  keyword_dict.Add('goto', KW_GOTO);
  
  keyword_dict.Add('type', KW_TYPE);
  
  keyword_dict.Add('const', KW_CONST);
  
  keyword_dict.Add('uses', KW_USES);
  
  keyword_dict.Add('print', KW_PRINT);
  keyword_dict.Add('return', KW_RETURN);
  keyword_dict.Add('exit', KW_EXIT);
  keyword_dict.Add('break', KW_BREAK);
  keyword_dict.Add('continue', KW_CONTINUE);
  
  keyword_dict.Add('raise', KW_RAISE);
  
  
  keyword_dict.Add('procedure', KW_PROCEDURE);
  keyword_dict.Add('function', KW_FUNCTION); 
  
  keyword_dict.Add('begin', KW_BEGIN);
  keyword_dict.Add('end', KW_END);   
  
  keyword_dict.Add('try', KW_TRY);
  keyword_dict.Add('except', KW_EXCEPT); 
  keyword_dict.Add('finally', KW_FINALLY); 
  
  keyword_dict.Add('and', TK_LOGIC_AND);
  keyword_dict.Add('or', TK_LOGIC_OR);     
  keyword_dict.Add('not', TK_LOGIC_NOT);
  keyword_dict.Add('xor', TK_LOGIC_XOR);  
  
  keyword_dict.Add('div', INT_DIV_OP);
  keyword_dict.Add('mod', INT_MOD_OP); 
  
  
  // true и false идут как есть
  keyword_dict.Add('true', CONST_TRUE);
  keyword_dict.Add('false', CONST_FALSE); 
  
  keyword_dict.Add('nil', CONST_NIL); 
  
  keyword_dict.Add('array', ARRAY_IDENT); 
end.