/// Юнит сканнера и препроцессора, всё происходит за один проход
unit ScannerUnit;

interface

uses
  System, 
  System.Text, 
  System.IO, 
  System.Collections,
  System.Collections.Generic,
  CommonUnit;

type
  
  ScanReader = class
  public 
    FileName: string;
    Reader: TextReader;
    Line: integer;
    Column: integer;
    codepage: Encoding;
    
    constructor Create(fname: string; codepage: Text.Encoding);
    begin
      FileName := Path.GetFullPath(fname);
      self.codepage := codepage;
      try
        self.Reader := new StreamReader(fname, codepage ) as TextReader;
      except
        on FileNotFoundException do raise new Exception('Не найден файл ' + fname);
      end;
      self.line := 1;
      self.column := 0;
    end;
    
    function Read: integer;
    begin
      var c := reader.Read;
      column += 1;
      if c = 13 then 
      begin
        line += 1;
        column := 0;
      end;
      Result := c;
    end;
    
    function Peek: integer;
    begin
      Result := reader.Peek;
    end;
  end;
  
  Token = class(Location)
  public 
    Kind: TokenKind;
    Data: object;
    
    constructor Create(sr: ScanReader);
    begin
      FileName := sr.FileName;
      DefineBeginPos(sr.line, sr.column)
    end;
    
    procedure EndCreate(sr: ScanReader);
    begin
      DefineEndPos(sr.line, sr.column)
    end;
  end;
  
  GScanner = class
  private 
    SaveToPos: TextPos;
    
    // препроцессор
    IfStack: Stack<boolean>;
    AllowAddToken := True;
    DefineList: List<string>; 
    
    _tokens: List<Token>;
    function TryExecScanDirective(Name, Value: string; Pos: TextPos; fname: string): boolean;
    procedure Scan(fname: string);
  public 
    property Tokens: List<Token> read _tokens;
    constructor Create(fname: string; DefineList: List<string>);
  end;
  
  ScannerException = class(Exception)
    Loc: Location;
    constructor Create(message: string; TxtPos: TextPos);
    begin
      inherited Create(message);
      self.Loc := new Location;
      self.Loc.LocCopyFrom(TxtPos);
    end;
  end;

implementation

constructor GScanner.Create(fname: string; DefineList: List<string>);
begin
  
  self.DefineList := new List<string>;
  foreach s: string in DefineList do self.DefineList.Add(s);
  _tokens := new List<Token>;
  
  IfStack := new Stack<boolean>;
  IfStack.Push(true);
  
  Scan(fname);
end;

function GScanner.TryExecScanDirective(Name, Value: string; Pos: TextPos; fname: string): boolean;
begin
  Result := False;
  if Name.ToLower = 'include' then
  begin
    SaveToPos := Pos;
    Scan(Value);
    SaveToPos := nil;
    Result := True;
  end
  else if Name.ToLower = 'define' then
  begin
    Value := Value.ToLower;
    if AllowAddToken then 
    begin
      if not DefineList.Contains(Value) then
        DefineList.Add(Value)
      else raise new ScannerException('имя ' + Value + ' уже было определено', Pos);
    end;
    Result := True;
  end
  else if Name.ToLower = 'undef' then
  begin
    Value := Value.ToLower;
    if AllowAddToken then 
    begin
      if DefineList.Contains(Value) then
        DefineList.Remove(Value) 
      else raise new ScannerException('стирание не существоющего имени ' + Value, Pos);
    end;
    Result := True;
  end
  else if Name.ToLower = 'ifdef' then
  begin
    Value := Value.ToLower;
    if AllowAddToken then 
    begin
      if DefineList.Contains(Value) then
        AllowAddToken := True
      else AllowAddToken := False;
    end;
    IfStack.Push(AllowAddToken);
    Result := True;
  end  
  else if Name.ToLower = 'ifndef' then
  begin
    Value := Value.ToLower;
    if AllowAddToken then
    begin
      if not DefineList.Contains(Value) then
        AllowAddToken := True
      else AllowAddToken := False;
    end;
    IfStack.Push(AllowAddToken);
    Result := True;
  end
  else if Name.ToLower = 'else' then
  begin
    AllowAddToken := not IfStack.Peek;
    Result := True;
  end
  else if Name.ToLower = 'endif' then
  begin
    IfStack.Pop;
    AllowAddToken := IfStack.Peek;
    Result := True;
  end
  else if Name.ToLower = 'warning' then
  begin
    if AllowAddToken then 
    begin
      OutputProc( new MessageInfo( string.Format('{2}<{0},{1}> warning: {3}', Pos.Line, Pos.Column, fname, Value), Warning, Pos));
    end;
    Result := True;
  end
  else if Name.ToLower = 'error' then
  begin
    if AllowAddToken then 
    begin
      raise new ScannerException( string.Format('{2}<{0},{1}> error: {3}', Pos.Line, Pos.Column, fname, Value), pos );
    end;
    Result := True;
  end;
end;

procedure GScanner.Scan(fname: string);
begin
  var sr := new ScanReader(fname, Options.Codepage);
  while sr.Peek <> -1 do
  begin
    
    var tk := new Token(sr); // Создается Token и записывается в нём текущий столбик и линия 
    tk.Kind := NO_TOKEN; // Если далее тип не изменится, добавлять созданный токен не будем
    
    var ch := char(sr.Peek);
    
    // пустота
    if char.IsWhiteSpace(ch) then
      sr.Read
    
    // {{БУКВА}+[_]}{{БУКВА}+[_]+{ЦИФРА}}*
    else if char.IsLetter(ch) or (ch = '_') then  
    begin
      var sb := new StringBuilder;
      
      while char.IsLetter(ch) or (ch = '_') or ((sb.Length > 0) and char.IsDigit(ch)) do
      begin
        sb.Append(ch);
        sr.Read;
        ch := char(sr.Peek);
      end;
      
      if keyword_dict.ContainsKey(sb.ToString.ToLower) then
      begin
        tk.Kind := TokenKind(keyword_dict[sb.ToString.ToLower]);
      end
      else
      begin
        tk.Kind := TokenKind.STRING_IDENT;
        tk.Data := sb.ToString;
      end;
    end
    
    // {ЦИФРА}*|{ЦИФРА}*.{ЦИФРА}+
    else if char.IsDigit(ch) then
    begin
      var sb := new StringBuilder;
      var DotFound := False;
      while char.IsDigit(ch) or ((sb.Length > 0) and (ch = '.') and not DotFound) do
      begin
        if ch = '.' then DotFound := True;
        sb.Append(ch);
        sr.Read;
        ch := char(sr.Peek);
      end;
      if DotFound then 
      begin
        tk.Kind := TokenKind.FLOAT_KIND;
        tk.Data := StrToFloat(sb.ToString);
      end
      else
      begin
        tk.Kind := TokenKind.INTEGER_KIND;
        tk.Data := Convert.ToInt32(sb.ToString);
      end;
    end
    
    // 
    else if ch = #39 then
    begin
      sr.Read; 
      var sb := new StringBuilder;
      ch := char(sr.Peek);
      repeat 
        if sr.Peek = -1 then
          raise new ScannerException('Обнаружена незаканчивающаяся строка!', new TextPos(sr.Line, sr.Column));
        sb.Append(ch);
        sr.Read;
        ch :=  char(sr.Peek);
      until ch = #39; 
      
      sr.Read; 
      
      tk.Kind := TokenKind.STRING_KIND;
      tk.Data := sb.ToString;
    end
    
    // 
    else if ch = '{' then
    begin
      sr.Read; 
      if char(sr.Read) = '$' then
      begin
        var sb := new StringBuilder;
        
        ch :=  char(sr.Peek); 
        while char.IsLetter(ch) or (ch = '_') or (ch = '.') or ((sb.Length > 0) and char.IsDigit(ch)) do
        begin
          sb.Append(ch);
          sr.Read;
          ch :=  char(sr.Peek); 
        end;
        var CompilerDirectiveName := sb.ToString;
        
        var CompilerDirectiveValue := '';
        
        if char(sr.Peek) <> '}' then 
        begin
          if char(sr.Read) <> ' ' then 
            raise new ScannerException('Ожидался пробел', new TextPos(sr.Line, sr.Column));
          
          sb := new StringBuilder;
          
          ch :=  char(sr.Peek);
          if ch = #39 then 
          begin
            sr.Read;
            ch := char(sr.Peek);
            repeat 
              if sr.Peek = -1 then
                raise new ScannerException('Обнаружена незаканчивающаяся строка!', new TextPos(sr.Line, sr.Column));
              sb.Append(ch);
              sr.Read;
              ch :=  char(sr.Peek);
            until ch = #39; 
            sr.Read;
          end
          else
            while char.IsLetter(ch) do
            begin
              sb.Append(ch);
              sr.Read;
              ch :=  char(sr.Peek); 
            end;
          
          if char(sr.Read) <> '}' then 
            raise new ScannerException('Ожидалось "}"', new TextPos(sr.Line, sr.Column));  
          
          CompilerDirectiveValue := sb.ToString;
        end
        else sr.Read();
        
        if (CompilerDirectiveName <> '') then
          if not TryExecScanDirective(CompilerDirectiveName, CompilerDirectiveValue, new TextPos(tk.BeginLine, tk.BeginColumn), fname) then
          begin
            tk.EndCreate(sr);
            Options.CompilerDirectives.Add(new CompilerDirective(CompilerDirectiveName, CompilerDirectiveValue, tk))
          end;
        
      end
      else
      begin
        while char(sr.Peek) <> '}' do
        begin
          // на случай когда в в скобках {} другой комментарий //
          if char(sr.Read) = '/' then 
            if  char(sr.Read) = '/' then
              while (sr.Peek <> -1) and (sr.Read <> 13) do 
                if sr.Peek = -1 then
                  raise new ScannerException('Обнаружен незаканчивающийся комментарий типа фигурные скобки', new TextPos(sr.Line, sr.Column));
        end;
        sr.Read;
      end;
      
    end
    
    else 
      case ch of
        '+': 
          begin
            sr.Read;
            if char(sr.Peek) = '=' then
            begin
              sr.Read;
              tk.Kind := ADD_ASSIGN_OP;
            end
            else
              tk.Kind := ADD_OP;
          end;
        
        '-': 
          begin
            sr.Read;
            if char(sr.Peek) = '=' then
            begin
              sr.Read;
              tk.Kind := SUB_ASSIGN_OP;
            end
            else
              tk.Kind := SUB_OP;
          end;
        
        '*': 
          begin
            sr.Read;
            if char(sr.Peek) = '=' then
            begin
              sr.Read;
              tk.Kind := MUL_ASSIGN_OP;
            end
            else
              tk.Kind := MUL_OP;
          end;    
        
        '/': 
          begin
            sr.Read;
            if char(sr.Peek) = '/' then
              while (sr.Peek <> -1) and (sr.Read <> 13) do 
            else
            if char(sr.Peek) = '=' then
            begin
              sr.Read;
              tk.Kind := DIV_ASSIGN_OP;
            end
            else
              tk.Kind := DIV_OP;
          end; 
        
        ':': 
          begin
            sr.Read;
            if  char(sr.Peek) = '=' then
            begin
              sr.Read;
              tk.Kind := ASSIGN;
            end
            else
              tk.Kind := COLON;
          end;   
        
        '=': 
          begin
            sr.Read;
            tk.Kind := TK_EQUAL;
          end;            
        
        '<': 
          begin
            sr.Read;
            if  char(sr.Peek) = '=' then
            begin
              sr.Read;
              tk.Kind := TK_LESS_THAN_OR_EQUAL;
            end
            else if  char(sr.Peek) = '>' then
            begin
              sr.Read;
              tk.Kind := TK_NO_EQUAL;
            end
            else
              tk.Kind := TK_LESS_THAN;
          end; 
        
        '>': 
          begin
            sr.Read;
            if  char(sr.Peek) = '=' then
            begin
              sr.Read;
              tk.Kind := TK_GREATER_THAN_OR_EQUAL;
            end
            else
              tk.Kind := TK_GREATER_THAN;
          end; 
        
        '(': 
          begin
            sr.Read;
            tk.Kind := PAREN_OPEN;
          end; 
        
        ')': 
          begin
            sr.Read;
            tk.Kind := PAREN_CLOSE;
          end; 
        
        '[': 
          begin
            sr.Read;
            tk.Kind := SQUARE_BRACKET_OPEN;
          end; 
        
        ']': 
          begin
            sr.Read;
            tk.Kind := SQUARE_BRACKET_CLOSE;
          end;           
        
        ';': 
          begin
            sr.Read;
            tk.Kind := SEMI;
          end; 
        
        '.': 
          begin
            sr.Read;
            tk.Kind := DOT;
          end; 
        
        ',': 
          begin
            sr.Read;
            tk.Kind := COMMA;
          end;     
        
        
        '&': 
          begin
            sr.Read;
            
            var sb := new StringBuilder;
            ch := char(sr.Peek);
            while char.IsLetter(ch) or (ch = '_') or ((sb.Length > 0) and char.IsDigit(ch)) do
            begin
              sb.Append(ch);
              sr.Read;
              ch := char(sr.Peek);
            end;
            
            if sb.Length = 0 then
              raise new ScannerException('ожидалось ключевое слово с которого надо снять аттрибут ключевого слова', new TextPos(tk.BeginLine, tk.BeginColumn));
            
            if not keyword_dict.ContainsKey(sb.ToString.ToLower) then
              raise new ScannerException('снимается атрибут ключевого слова с не ключевого слова', new TextPos(tk.BeginLine, tk.BeginColumn));
            
            tk.Kind := TokenKind.STRING_IDENT;
            tk.Data := sb.ToString;
          end;
        
        '#': 
          begin
            sr.Read;
            tk.Kind := CHAR_KIND;
            
            var sb := new StringBuilder;
            ch := char(sr.Peek);
            while char.IsDigit(ch) do
            begin
              sb.Append(ch);
              sr.Read;
              ch := char(sr.Peek);
            end;
            
            var int: integer;
            if not integer.TryParse(sb.ToString, int) then 
              raise new ScannerException('Ожидался байт 0..255', new TextPos(sr.Line, sr.Column));
            tk.Data := int;
            
          end;
      
      
      else raise new ScannerException('Сканнер обнаружил непредвиденный символ "' + ch + '"', new TextPos(sr.Line, sr.Column));
      end;
    
    if tk.Kind <> NO_TOKEN then 
    begin
      tk.EndCreate(sr);
      if AllowAddToken then 
        if SaveToPos = nil then 
          _tokens.Add(tk)
        else 
        begin
          tk.DefineBeginPos(SaveToPos.Line, SaveToPos.Column);
          tk.DefineEndPos(SaveToPos.Line, SaveToPos.Column);
          _tokens.Add(tk)
        end;
    end;
  end;
end;


end.