/// Создает синтаксическое дерево
unit SyntaxAnalyze;

interface

uses
  System, 
  System.IO, 
  System.Collections,
  System.Collections.Generic, 
  ScannerUnit,
  ASyntaxTree,
  CommonUnit;

type
  ParserException = class(Exception)
    Loc: Location;
    
    function GetTKInfo(tk: Token): string;
    begin
      Result := tk.Kind.ToString;
      Result := Result + ' - "'  + TokenKind2Str(tk.Kind);
      if tk.Data <> nil then Result := Result + ' - "' + tk.Data.ToString + '"';
    end;
    
    constructor Create(message: string; tk: Token);
    begin
      inherited Create(string.Format('{0} [элемент разбора: "{1}"]', Message, GetTKInfo(tk)));
      self.Loc := new Location;
      self.Loc.LocCopyFrom(tk);
    end;
    
    constructor Create(message: string; Loc: Location);
    begin
      inherited Create(message);
      self.Loc := Loc;
    end;
  end;
  
  GParser = class
  private 
    fname: string;
    isUnit := False;
    index: integer := 0;
    tokens: List<Token>;
    
    procedure ParseProgram;
    function ParseStatement(MustFound: boolean): StatementNode;
    function ParseExpression: ExpressionNode;
    function ParseParameterType: FunctionParameter;
    function ParseTypeExpression: TypeExpression;
    function ParseIdent: IdentNode;
    
    
    function ExceptKW(KW: TokenKind): boolean;
    function ExceptKW(TK: Token; KW: TokenKind): boolean;
    
    procedure StructureExpressionNode(var ExprNode: ExpressionsNode);
  public 
    SyntaxTree: ProgramNode;
    property filename: string read fname;
    constructor Create(tokens: List<Token>; filename: string);
  end;

implementation

constructor GParser.Create(tokens: List<Token>; filename: string);
begin
  if tokens.Count = 0 then 
    exit;
  self.fname := filename;
  self.tokens := tokens;
  self.ParseProgram;

end;

procedure GParser.ParseProgram;
begin
  index := index;
  if (tokens[index].Kind = KW_PROGRAM) then
  begin
    index += 1;
    if (tokens[index].Kind = KW_PROGRAM) then 
      (SyntaxTree as ProgramTree).ProgramName := ParseIdent.ToString;
    ExceptKW(SEMI); 
  end
  else if (tokens[index].Kind = KW_UNIT) then 
  begin
    index += 1;
    SyntaxTree := new UnitTree;
    (SyntaxTree as UnitTree).UnitName := ParseIdent.ToString;
    ExceptKW(SEMI);
  end
  else if (tokens[index].Kind = KW_LIBRARY) then 
  begin
    index += 1;
    SyntaxTree := new LibraryTree;
    (SyntaxTree as LibraryTree).LibraryName := ParseIdent.ToString;
    ExceptKW(SEMI); 
  end
  else
    SyntaxTree := new ProgramTree;
 SyntaxTree.FileName :=  fname; 
    
  
  SyntaxTree.SourceFilename := fname;
  SyntaxTree.Generic_Functions := new List<FunctionNode>;
  SyntaxTree.Generic_UsesAliases := new Dictionary<IdentNode, IdentNode>;
  SyntaxTree.Generic_Uses := new List<IdentNode>;
  
  // Добавление юнита по умолчанию
  var a := new IdentNode;
  a.IdentList := new List<string>; 
  a.IdentList.Add('SystemUnit'); 
  SyntaxTree.Generic_Uses.Add(a);
  
  
  SyntaxTree.Generic_Types := new List<TypeNode>;
  SyntaxTree.Generic_Const := new List<ConstNode>;
  SyntaxTree.Generic_Vars := new List<TypeVarNode>;
  
  SyntaxTree.MainFunction := new StatementsNode;
  SyntaxTree.MainFunction.Statements := new List<StatementNode>;
  
  while (index < tokens.Count) do
  begin
    if (tokens[index].Kind = KW_USES) then
    begin
      index += 1;
      while (index < tokens.Count) do
      begin
        var firstIdent := ParseIdent;
        
        if (tokens[index].Kind = TokenKind.TK_EQUAL) and (firstIdent.IdentList.Count = 1) then 
        begin
          index += 1;
          SyntaxTree.Generic_UsesAliases.Add(firstIdent, ParseIdent);
        end
        else SyntaxTree.Generic_Uses.Add(firstIdent);
        
        if (tokens[index].Kind = COMMA) then
          index += 1
        else
          break;
      end;
      ExceptKW(SEMI);   
    end
    
    else if (tokens[index].Kind = KW_VAR) and (tokens[index + 1].kind = STRING_IDENT) and (tokens[index + 2].kind = COLON) then
    begin
      index += 1;
      while (index < tokens.Count) and (tokens[index].kind = STRING_IDENT) and (tokens[index + 1].kind = COLON) do
      begin
        
        { var VarList := new List<string>;
         while (index < tokens.Count) do
         begin
           if (index < tokens.Count) and (tokens[index].kind = STRING_IDENT) then
             VarList.Add(string(tokens[index].Data))
           else raise new ParserException('ожидалcя идентификатор', tokens[index]);
           index += 1;
           if (tokens[index].Kind = COMMA) then
             index += 1
           else
             break;
         end;}
        
        
        
        var VarN := new TypeVarNode;
        VarN.Name := string(tokens[index].Data);
        index += 2;
        VarN.Expr := ParseTypeExpression;
        
        SyntaxTree.Generic_Vars.Add(VarN);
        
        ExceptKW(SEMI); 
      end;
    end
    
    else if tokens[index].kind = KW_TYPE then
    begin
      index += 1;
      while (index < tokens.Count) and  (tokens[index].kind = STRING_IDENT) and (tokens[index + 1].Kind = TokenKind.TK_EQUAL) do
      begin
        var TypeN := new TypeNode;
        TypeN.Name := string(tokens[index].Data);
        index += 2;
        TypeN.Expr := ParseTypeExpression;
        SyntaxTree.Generic_Types.Add(TypeN);
        
        ExceptKW(SEMI); 
        
      end;
    end
    
    else if tokens[index].kind = KW_CONST then
    begin
      index += 1;
      while (index < tokens.Count) and  (tokens[index].kind = STRING_IDENT) and (tokens[index + 1].Kind = TokenKind.TK_EQUAL) do
      begin
        var ConstN := new ConstNode;
        ConstN.Name := string(tokens[index].Data);
        index += 2;
        ConstN.Expr := ParseExpression;
        SyntaxTree.Generic_Const.Add(ConstN);
        ExceptKW(SEMI); 
      end;
    end
    
    else if (tokens[index].Kind = KW_PROCEDURE) or (tokens[index].Kind = KW_FUNCTION) then
    begin
      
      // var FuncNode := new FunctionNode;
      var IsFunction := (tokens[index].Kind = KW_FUNCTION);
      
      index += 1;
      var ParametersType := new List<FunctionParameter>;
      
      var Name: string;
      if (index < tokens.Count) and (tokens[index].kind = STRING_IDENT) then
      begin
        Name := string(tokens[index].Data)
      end
      else raise new ParserException('ожидалось название процедуры', tokens[index]);
      index += 1;
      
      if (tokens[index].Kind = PAREN_OPEN) then
      begin
        index += 1;
        if not (tokens[index].Kind = PAREN_CLOSE) then 
          while (index < tokens.Count) do
          begin
            ParametersType.Add(ParseParameterType);
            if (index < tokens.Count) and (tokens[index].Kind = SEMI) then 
              index += 1
              else
            if (index < tokens.Count) and (tokens[index].Kind = PAREN_CLOSE) then 
            begin
              index += 1;
              break;
            end 
            else
              raise new ParserException('Ожидалось ";" или ")"', tokens[index])
          end
        else index += 1; 
      end;
      
      var ReturnType: TypeExpression;
      if IsFunction then
      begin
        ExceptKW(COLON); 
        ReturnType := ParseTypeExpression;
      end;
      
      ExceptKW(SEMI); 
      
      
      var FuncNode: FunctionNode;
      
      if (tokens[index].kind = STRING_IDENT) and (string(tokens[index].Data).ToLower = 'external') then
      begin
        index += 1; 
        
        FuncNode := new NativeFunctionNode;
        FuncNode.Name := Name;
        FuncNode.ParametersType := ParametersType;
        FuncNode.ReturnType := ReturnType;
        FuncNode.IsFunction := IsFunction;
        
        
        if not (tokens[index].kind = STRING_KIND) then 
          raise new ParserException('ожидалось имя dll', tokens[index]);
        (FuncNode as NativeFunctionNode).DllName := string(tokens[index].Data);
        index += 1; 
        
        
        if not (tokens[index].kind = STRING_IDENT) and (string(tokens[index].Data).ToLower = 'name') then 
          raise new ParserException('ожидалось "name"', tokens[index]);
        index += 1; 
        
        if not (tokens[index].kind = STRING_KIND) then 
          raise new ParserException('ожидалось имя функции из native dll', tokens[index]);
        (FuncNode as NativeFunctionNode).DllNameMethod := string(tokens[index].Data);
        index += 1; 
        
        if (tokens[index].kind = STRING_IDENT) and (string(tokens[index].Data).ToLower = 'charset') then
        begin
          index += 1; 
          
          if not (tokens[index].kind = STRING_IDENT) then 
            raise new ParserException('ожидалось имя charset', tokens[index]);
          (FuncNode as NativeFunctionNode).CharSet := string(tokens[index].Data);
          index += 1; 
        end else (FuncNode as NativeFunctionNode).CharSet := nil;
        
      end
      else
      begin
        FuncNode := new NetFunctionNode;
        FuncNode.Name := Name;
        FuncNode.ParametersType := ParametersType;
        FuncNode.ReturnType := ReturnType;
        FuncNode.IsFunction := IsFunction;
        (FuncNode as NetFunctionNode).Body := ParseStatement(true);
      end;
      
      ExceptKW(SEMI); 
      
      SyntaxTree.Generic_Functions.Add(FuncNode);
    end
    
    else if (tokens[index].Kind = KW_BEGIN) then
    begin
      index += 1;
      while (index < tokens.Count) and not (tokens[index].Kind = KW_END) do
      begin
        
        SyntaxTree.MainFunction.Statements.Add(ParseStatement(true));
        
        ExceptKW(SEMI); 
        
      end;
      index += 1;
      
      ExceptKW(DOT);
      
      break;
    end
    
    
    // обработка для программы
    else if not isUnit then 
    begin
      while (index < tokens.Count) do
      begin
        
        SyntaxTree.MainFunction.Statements.Add(ParseStatement(true));
        
        ExceptKW(SEMI); 
        
      end;
      break;
    end;
    
    //raise new ParserException('неожидаемый элемент: ' + string(tokens[index].Data));
  end;
  
end;




function GParser.ParseParameterType: FunctionParameter;
begin
  var ParList := new List<string>;
  
  while (index < tokens.Count) do
  begin
    if (index < tokens.Count) and (tokens[index].kind = STRING_IDENT) then
      ParList.Add(string(tokens[index].Data))
    else raise new ParserException('ожидалcя идентификатор', tokens[index]);
    index += 1;
    if (tokens[index].Kind = COMMA) then
      index += 1
    else
      break;
  end;
  
  
  ExceptKW(COLON); 
  var _type := ParseTypeExpression;
  
  
  
  if ParList.Count = 1 then
  begin
    var ParType := new FunctionParameterVar;
    ParType.TypeExpr := _type;
    ParType.Name := ParList[0];
    Result :=  ParType;  
  end
  else
  begin
    var ParTypeList := new FunctionParameterList;
    ParTypeList.TypeExpr := _type;
    ParTypeList.ParList := ParList;
    Result :=  ParTypeList;   
  end;
  
end;



function GParser.ParseIdent: IdentNode;
begin
  var BeginPos := new TextPos(tokens[index].BeginLine, tokens[index].BeginColumn);
  
  Result := new IdentNode;
  Result.IdentList := new List<string>;
  
  while (index < tokens.Count) and (tokens[index].kind = STRING_IDENT) and (tokens[index + 1].Kind = Dot) do
  begin
    Result.IdentList.Add(string(tokens[index].Data));
    index += 2; // прыжок через имя и точку
  end;
  
  
  ExceptKW(STRING_IDENT); index -= 1;
  Result.IdentList.Add(string(tokens[index].Data));
  index += 1;
  
  
  Result.BracketList := new List<ExpressionNode>;
  if (tokens[index].Kind = PAREN_OPEN) then
  begin
    index += 1;
    if not (tokens[index].Kind = PAREN_CLOSE) then 
      while (index < tokens.Count) do
      begin
        Result.BracketList.Add(ParseExpression);
        if (index < tokens.Count) and (tokens[index].Kind = COMMA) then 
          index += 1
        else 
        begin
          ExceptKW(PAREN_CLOSE);
          break;
        end;
      end
    else index += 1; 
  end;
  
  Result.SquareBracketList := new List<ExpressionNode>;
  if (tokens[index].Kind = SQUARE_BRACKET_OPEN) then
  begin
    index += 1;
    if not (tokens[index].Kind = SQUARE_BRACKET_CLOSE) then 
      while (index < tokens.Count) do
      begin
        Result.SquareBracketList.Add(ParseExpression);
        if (index < tokens.Count) and (tokens[index].Kind = COMMA) then 
          index += 1
        else 
        begin
          ExceptKW(SQUARE_BRACKET_CLOSE);
          break;
        end;
      end
    else index += 1; 
  end;
  
  
  
  if (tokens[index].Kind = DOT) then 
  begin
    index += 1; 
    result.SubIdentNode := ParseIdent;
  end;
  
  result.DefineBeginPos(BeginPos);
  result.DefineEndPos(tokens[index - 1].EndLine, tokens[index - 1].EndColumn);
end;

function GParser.ParseStatement(MustFound: boolean): StatementNode;
begin
  if not (index < tokens.Count) then 
    raise new ParserException('Неожиданный конец файла', tokens[index]);
  
  
  var BeginPos := new TextPos(tokens[index].BeginLine, tokens[index].BeginColumn);
  
  case tokens[index].Kind of 
    
    // begin statement* end
    KW_BEGIN: 
      begin
        index += 1;
        
        var StatementsStatement := new StatementsNode;
        StatementsStatement.Statements := new List<StatementNode>;
        
        while (index < tokens.Count) and not (tokens[index].Kind = KW_END) do
        begin
          StatementsStatement.Statements.Add(ParseStatement(true));
          
          ExceptKW(SEMI); 
          
        end;
        
        ExceptKW(KW_END);
        
        result := StatementsStatement;        
      end;
    
    // var ident (:type|:=expression) 
    KW_VAR:
      begin
        index += 1;
        
        var VarList := new List<string>;
        
        while (index < tokens.Count) do
        begin
          ExceptKW(STRING_IDENT); index -= 1;
          VarList.Add(string(tokens[index].Data));
          index += 1;
          if (tokens[index].Kind = COMMA) then
            index += 1
          else
            break;
        end;
        
        if (index < tokens.Count) then
          if (tokens[index].Kind = ASSIGN) then
          begin
            index += 1;
            var ExprDeclareStatement := new ExprDeclareNode;
            ExprDeclareStatement.VarList := VarList;
            ExprDeclareStatement.Expr := ParseExpression;
            Result := ExprDeclareStatement;
          end
          else 
          if (tokens[index].Kind = COLON) then
          begin
            index += 1;
            var TypeDeclareStatement := new TypeDeclareNode;
            TypeDeclareStatement.VarList := VarList;
            TypeDeclareStatement.Expr := ParseTypeExpression;
            Result := TypeDeclareStatement;
          end
          else 
            raise new ParserException('ожидалось ":" или ":="', tokens[index]);
      end;
    
    // if BooleanExpession then statement [else statement]
    KW_IF:
      begin
        index += 1;
        var IfStatement := new IfNode;
        
        IfStatement.Condition := ParseExpression;
        
        ExceptKW(KW_THEN);
        
        IfStatement.ThenBody := ParseStatement(false);
        
        if (index < tokens.Count) and (tokens[index].Kind = KW_ELSE) then
        begin
          index += 1;
          IfStatement.ElseBody := ParseStatement(false);
        end;
        
        result := IfStatement;
      end;
    
    // goto ident
    KW_GOTO:
      begin
        index += 1;
        var GotoStatement := new GotoNode;
        ExceptKW(STRING_IDENT); index -= 1;
        GotoStatement.Name := string(tokens[index].Data);
        index += 1;  
        
        Result := GotoStatement;
      end;
    
    
    // for [var] ident = IntExpr (to|downto) IntExpr do statement
    KW_FOR: 
      begin
        index += 1;
        var ForStatement := new ForNode;
        
        if (index < tokens.Count) and (tokens[index].Kind = KW_VAR)  then
        begin
          index += 1;
          ForStatement.DeclareCounter := true;
        end else ForStatement.DeclareCounter := false; 
        
        ExceptKW(STRING_IDENT); index -= 1;
        ForStatement.CounterName := string(tokens[index].Data);
        index += 1;  
        
        
        ExceptKW(ASSIGN);
        
        
        ForStatement.FromExpression := ParseExpression;
        
        
        if (index < tokens.Count) and (not (tokens[index].Kind = KW_TO)) or (tokens[index].Kind = KW_DOWNTO) then
          raise new ParserException('ожидалось "to" или "downto" ', tokens[index]);
        
        ForStatement.&DownTo := (tokens[index].Kind = KW_DOWNTO); 
        
        index += 1;  
        
        ForStatement.ToExpression := ParseExpression;
        
        ExceptKW(KW_DO);
        
        
        ForStatement.Body := ParseStatement(false);
        
        Result := ForStatement;
      end;
    
    // repeat statement* until BooleanExpression
    KW_REPEAT:
      begin
        index += 1;
        var RepeatStatement := new RepeatNode;
        
        var Statements := new StatementsNode;
        Statements.Statements := new List<StatementNode>;
        
        while (index < tokens.Count) and not (tokens[index].Kind = KW_UNTIL) do
        begin
          Statements.Statements.Add(ParseStatement(true));
          
          ExceptKW(SEMI);
          
        end;
        
        RepeatStatement.Body := Statements;
        
        ExceptKW(KW_UNTIL);
        
        RepeatStatement.Condition := ParseExpression;
        
        Result := RepeatStatement;
      end;
    
    // while BooleanExpression do statement
    KW_WHILE:
      begin
        index += 1;
        var WhileStatement := new WhileNode;
        
        WhileStatement.Condition := ParseExpression;
        
        ExceptKW(KW_DO);
        
        WhileStatement.Body := ParseStatement(false);
        
        Result := WhileStatement;
      end;
    
    // try statement (except (on ident: ExceptionType do statement)* | finally statement) end
    KW_TRY:
      begin
        index += 1;
        var TryStatement := new TryNode;
        
        var TryStatements := new StatementsNode;
        TryStatements.Statements := new List<StatementNode>;
        while (index < tokens.Count) and not ((tokens[index].Kind = KW_EXCEPT) 
           or (tokens[index].Kind = KW_FINALLY) or (tokens[index].Kind = KW_END)) do
        begin
          TryStatements.Statements.Add(ParseStatement(true));
          ExceptKW(SEMI);
        end;
        TryStatement.TryStatements :=  TryStatements;
        
        
        
        if (index < tokens.Count) and (tokens[index].Kind = KW_EXCEPT) then
        begin
          index += 1;
          
          TryStatement.ExceptionFilters := new List<ExceptionFilterNode>;
          
          while (index < tokens.Count) and (tokens[index].Kind = STRING_IDENT) 
            and (string(tokens[index].Data).ToLower = 'on') do
          begin
            index += 1;
            var ExceptionFilter := new ExceptionFilterNode;
            if (index + 1 < tokens.Count) and (tokens[index + 1].kind = COLON) then
            begin
              ExceptKW(STRING_IDENT); index -= 1;
              ExceptionFilter.ExceptionVarName := string(tokens[index].Data);
              index += 2; // пропускаем ещё и двоеточие
              ExceptionFilter.ExceptionType := ParseTypeExpression;
              
              ExceptKW(KW_DO);
              
              var Statements := new StatementsNode;
              Statements.Statements := new List<StatementNode>;
              while (index < tokens.Count) and not ((tokens[index].Kind = KW_EXCEPT) 
                 or (tokens[index].Kind = KW_FINALLY) or (tokens[index].Kind = KW_END)) do
              begin
                Statements.Statements.Add(ParseStatement(true));
                ExceptKW(SEMI);
              end;
              ExceptionFilter.Body :=  Statements;
            end else raise new ParserException('', tokens[index]);
            TryStatement.ExceptionFilters.Add(ExceptionFilter);
          end;
          
        end;
        
        if (index < tokens.Count) and (tokens[index].Kind = KW_FINALLY) then
        begin
          index += 1;
          var FinallyStatements := new StatementsNode;
          FinallyStatements.Statements := new List<StatementNode>;
          while (index < tokens.Count) and not (tokens[index].Kind = KW_END) do
          begin
            FinallyStatements.Statements.Add(ParseStatement(true));
            ExceptKW(SEMI);
          end;
          TryStatement.FinallyStatements := FinallyStatements;
        end;
        
        ExceptKW(KW_END);
        
        
        Result := TryStatement;
      end;
    
    // print expression
    KW_PRINT:
      begin
        index += 1;
        var PrintStatement := new PrintNode;
        PrintStatement.Expr := ParseExpression;
        Result := PrintStatement;
      end;
    
    // raise expression
    KW_RAISE:
      begin
        index += 1;
        var RaiseStatement := new RaiseNode;
        RaiseStatement.Expr := ParseExpression;
        Result := RaiseStatement;
      end;
    
    // return expression
    KW_RETURN:
      begin
        index += 1;
        var ReturnStatement := new ReturnNode;
        ReturnStatement.Expr := ParseExpression;
        Result := ReturnStatement;
      end;
    
    // exit
    KW_EXIT:
      begin
        index += 1;
        Result := new ExitNode;
      end;
    
    // break
    KW_BREAK:
      begin
        index += 1;
        Result := new BreakNode;
      end;
    
    // continu
    KW_CONTINUE:
      begin
        index += 1;
        Result := new ContinueNode;
      end;
    
    
    
    STRING_IDENT:
      begin
        if (index + 1 < tokens.Count) then
        begin
          
          // ident : statement; 
          if (tokens[index + 1].Kind = COLON) then
          begin
            var LabelStatement := new LabelNode;
            
            LabelStatement.Name := string(tokens[index].Data);
            index += 2; // переход на statement
            
            LabelStatement.Body := ParseStatement(false);   
            
            Result := LabelStatement;
          end
          
          else
          begin
            var SaveIndex := index;
            var Ident := ParseIdent;
            // ident := <expression>
            if (tokens[index].Kind = ASSIGN) then
            begin
              var AssignStatement := new AssignNode;
              AssignStatement.Ident := Ident;
              index += 1; // переход на expression
              AssignStatement.Expr := ParseExpression;
              Result := AssignStatement;
            end
            
            else if
            ((tokens[index].Kind = ADD_ASSIGN_OP) or
             (tokens[index].Kind = SUB_ASSIGN_OP) or
             (tokens[index].Kind = MUL_ASSIGN_OP) or
             (tokens[index].Kind = DIV_ASSIGN_OP)) then
            begin
              
              // Да, да я ленивый 
              // Поэтому выражение типа a+=8 превращается в a:=a+8;
              // Минусы: новый a содержит локацию от первого a
              
              var Kind: TokenKind;
              case tokens[index].Kind of
                ADD_ASSIGN_OP: Kind := ADD_OP;
                SUB_ASSIGN_OP: Kind := SUB_OP;
                MUL_ASSIGN_OP: Kind := MUL_OP;
                DIV_ASSIGN_OP: Kind := DIV_OP;
              end;
              
              tokens[index].Kind := ASSIGN;
              
              var tk := Token(tokens[index].MemberwiseClone);
              tk.Kind := Kind;
              
              tokens.Insert(index + 1, tk); 
              
              for var i := SaveIndex to index - 1 do 
                tokens.Insert(index + 1, tokens[i]);  // Вставили "a"
              
              index := SaveIndex;
              Result := ParseStatement(true); // Заново парсим то что мы сделали
              
              {var AssignOp := new AssignOpNode;
              AssignOp.Ident := Ident;
              case tokens[index].Kind of
              ADD_ASSIGN_OP:AssignOp.Operation := ASSIGN_ADD;
              SUB_ASSIGN_OP:AssignOp.Operation := ASSIGN_SUB;
              MUL_ASSIGN_OP:AssignOp.Operation := ASSIGN_MUL;
              DIV_ASSIGN_OP:AssignOp.Operation := ASSIGN_DIV;
              end;
              index += 1;
              AssignOp.Expr := ParseExpression;
              Result := AssignOp;}
            end
            else
            begin
              var IdentStmt := new IdentNodeStmt;
              IdentStmt.Ident := Ident;
              Result := IdentStmt;
            end; 
          end
          
        end else raise new ParserException('Неизвестное имя "' + tokens[index].Kind.ToString + '"', tokens[index]);
      end
  
  
  else if MustFound then raise new ParserException('Неизвестный элемент в разборе [' + index.ToString + '] "' + tokens[index].Kind.ToString + '"', tokens[index]);
  end;
  
  if Result <> nil then
  begin
    result.DefineBeginPos(BeginPos);
    result.DefineEndPos(tokens[index - 1].EndLine, tokens[index - 1].EndColumn);
  end;
end;

function GParser.ParseTypeExpression: TypeExpression;
begin
  var BeginPos := new TextPos(tokens[index].BeginLine, tokens[index].BeginColumn);
  if (index < tokens.Count) then
  begin
    if (tokens[index].Kind = ARRAY_IDENT) then
    begin
      index += 1; 
      if tokens[index].Kind = SQUARE_BRACKET_OPEN then
      begin
        var TypeArrayWithIndex := new TypeExprArrayWithIndex;
        
        index += 1;
        if not (tokens[index].Kind = SQUARE_BRACKET_CLOSE) then
        begin
          TypeArrayWithIndex.IndexExpr := ParseExpression;
          ExceptKW(SQUARE_BRACKET_CLOSE);
        end
        else index += 1; 
        
        if (tokens[index].kind = STRING_IDENT) and (string(tokens[index].Data).ToLower = 'of') then
        begin
          index += 1; 
          TypeArrayWithIndex.OfType := ParseTypeExpression;
          Result :=  TypeArrayWithIndex;
        end
        else raise new ParserException('ожидалось "of"', tokens[index]);
        
      end
      else 
      begin
        
        if (tokens[index].kind = STRING_IDENT) and (string(tokens[index].Data).ToLower = 'of') then
        begin
          index += 1; 
          var TypeArray := new TypeExprArray;
          TypeArray.OfType := ParseTypeExpression;
          Result :=  TypeArray;
        end
        else raise new ParserException('ожидалось "of"', tokens[index]);
      end;
    end
    else
    if (tokens[index].kind = STRING_IDENT) then
    begin
      var TypeExprRef := new TypeExpressionRef;
      var names: string;
      while (index < tokens.Count) and (tokens[index].kind = STRING_IDENT) and (tokens[index + 1].Kind = Dot) do
      begin
        names := names + string(tokens[index].Data) + '.';
        index += 2; // прыжок через имя и точку
      end;
      
      TypeExprRef.TypeName := names; 
      
      ExceptKW(STRING_IDENT); index -= 1;
      TypeExprRef.TypeName := TypeExprRef.TypeName +  string(tokens[index].Data);
      index += 1; 
      
      Result := TypeExprRef;
    end
    else raise new ParserException('Неизвестный элемент в разборе [' + index.ToString + ']', tokens[index]);
  end;
  
  if Result <> nil then
  begin
    result.DefineBeginPos(BeginPos);
    result.DefineEndPos(tokens[index - 1].EndLine, tokens[index - 1].EndColumn);
  end;
  
end;

function GParser.ParseExpression: ExpressionNode;
begin
  if not (index < tokens.Count) then 
    raise new ParserException('Парсинг выражения. Неожиданный конец файла', tokens[tokens.Count-1]);
  
  var Exprs := new ExpressionsNode;
  Exprs.Nodes := new List<ExpressionNode>;
  
  repeat
    var BeginPos := new TextPos(tokens[index].BeginLine, tokens[index].BeginColumn);
    
    case tokens[index].Kind of 
      
      PAREN_OPEN:
        begin
          index += 1;
          var BracketExpr := new BracketNode;
          BracketExpr.Nodes := new List<ExpressionNode>;
          while not (tokens[index].Kind = PAREN_CLOSE) do
            BracketExpr.Nodes.Add(ParseExpression);
          Exprs.Nodes.Add(BracketExpr);
        end;
      
      CONST_NIL:
        begin
          Exprs.Nodes.Add(new ConstantNullNodeExpr);
        end;
      
      STRING_KIND:
        begin
          var StringCnst := new StringLiteral;
          StringCnst.Value := string(tokens[index].Data); 
          Exprs.Nodes.Add(StringCnst);
        end;
      
      INTEGER_KIND:
        begin
          var IntegerCnst := new IntegerLiteral;
          IntegerCnst.Value := integer(tokens[index].Data); 
          Exprs.Nodes.Add(IntegerCnst);
        end;
      
      FLOAT_KIND:
        begin
          var RealCnst := new RealLiteral;
          RealCnst.Value := real(tokens[index].Data); 
          Exprs.Nodes.Add(RealCnst);
        end;
      
      CHAR_KIND:
        begin
          var CharCnst := new CharLiteral;
          CharCnst.Value := integer(tokens[index].Data); 
          Exprs.Nodes.Add(CharCnst);
        end;
      
      CONST_TRUE:
        begin
          var BooleanCnst := new BooleanLiteral;
          BooleanCnst.Value := true; 
          Exprs.Nodes.Add(BooleanCnst);      
        end;
      
      CONST_FALSE:
        begin
          var BooleanCnst := new BooleanLiteral;
          BooleanCnst.Value := true; 
          Exprs.Nodes.Add(BooleanCnst);      
        end;
      
      ADD_OP:
        begin
          var AddBinaryOp := new AddBinaryOperation;
          AddBinaryOp.Action := AddBinaryOperations.Addition; 
          Exprs.Nodes.Add(AddBinaryOp); 
        end;
      
      SUB_OP:
        begin
          var AddBinaryOp := new AddBinaryOperation;
          AddBinaryOp.Action := AddBinaryOperations.Subtraction; 
          Exprs.Nodes.Add(AddBinaryOp); 
        end;  
      
      MUL_OP:
        begin
          var MulBinaryOp := new MulBinaryOperation;
          MulBinaryOp.Action := MulBinaryOperations.Multiplication; 
          Exprs.Nodes.Add(MulBinaryOp); 
        end;
      
      DIV_OP:
        begin
          var MulBinaryOp := new MulBinaryOperation;
          MulBinaryOp.Action := MulBinaryOperations.Division; 
          Exprs.Nodes.Add(MulBinaryOp); 
        end;
      
      INT_DIV_OP:
        begin
          var IntegerOp := new IntegerOperation;
          IntegerOp.Action := IntegerOperations.DivisionInteger; 
          Exprs.Nodes.Add(IntegerOp); 
        end;
      
      INT_MOD_OP:
        begin
          var IntegerOp := new IntegerOperation;
          IntegerOp.Action := IntegerOperations.ModInteger; 
          Exprs.Nodes.Add(IntegerOp); 
        end;
      
      TokenKind.TK_LOGIC_AND:
        begin
          var LogicalOp := new LogicalOperation;
          LogicalOp.Action := LogicalOperations.logic_and; 
          Exprs.Nodes.Add(LogicalOp);       
        end;
      
      TokenKind.TK_LOGIC_OR:
        begin
          var LogicalOp := new LogicalOperation;
          LogicalOp.Action := LogicalOperations.logic_or; 
          Exprs.Nodes.Add(LogicalOp);       
        end;
      
      TokenKind.TK_LOGIC_XOR:
        begin
          var LogicalOp := new LogicalOperation;
          LogicalOp.Action := LogicalOperations.logic_xor; 
          Exprs.Nodes.Add(LogicalOp);       
        end;
      
      TokenKind.TK_LOGIC_NOT:
        begin
          var LogicalOp := new LogicalOperation;
          LogicalOp.Action := LogicalOperations.logic_not; 
          Exprs.Nodes.Add(LogicalOp);       
        end;
      
      TokenKind.TK_EQUAL:
        begin
          var CompareOp := new CompareOperation;
          CompareOp.Action := CompareOperations.Equal; 
          Exprs.Nodes.Add(CompareOp);       
        end;
      
      TokenKind.TK_NO_EQUAL:
        begin
          var CompareOp := new CompareOperation;
          CompareOp.Action := CompareOperations.NoEqual; 
          Exprs.Nodes.Add(CompareOp);       
        end;
      
      TokenKind.TK_GREATER_THAN:
        begin
          var CompareOp := new CompareOperation;
          CompareOp.Action := CompareOperations.GreaterThan; 
          Exprs.Nodes.Add(CompareOp);       
        end;
      
      TokenKind.TK_GREATER_THAN_OR_EQUAL:
        begin
          var CompareOp := new CompareOperation;
          CompareOp.Action := CompareOperations.GreaterThanOrEqual; 
          Exprs.Nodes.Add(CompareOp);       
        end;
      
      TokenKind.TK_LESS_THAN:
        begin
          var CompareOp := new CompareOperation;
          CompareOp.Action := CompareOperations.LessThan; 
          Exprs.Nodes.Add(CompareOp);       
        end;
      
      TokenKind.TK_LESS_THAN_OR_EQUAL:
        begin
          var CompareOp := new CompareOperation;
          CompareOp.Action := CompareOperations.LessThanOrEqual; 
          Exprs.Nodes.Add(CompareOp);       
        end;    
      
      TokenKind.DOT:
        begin
          index += 1;
          var EDot := new ExprDot;
          EDot.Expr := Exprs.Nodes[Exprs.Nodes.Count-1];
          Exprs.Nodes.RemoveAt(Exprs.Nodes.Count-1);
          EDot.SubIdent := ParseIdent;
          Exprs.Nodes.Add(EDot); 
          index -= 1;
        end; 
      
      STRING_IDENT:
        begin
          if string(tokens[index].Data).ToLower = 'new' then 
          begin
            index += 1;
            var NewN := new NewNode;
            NewN.TypeExpr := ParseTypeExpression; 
            NewN.Parameters := new List<ExpressionNode>;
            
            if tokens[index].Kind = PAREN_OPEN then
            begin
              index += 1;
              if not (tokens[index].Kind = PAREN_CLOSE) then 
                while (index < tokens.Count) do
                begin
                  NewN.Parameters.Add(ParseExpression);
                  if (index < tokens.Count) and (tokens[index].Kind = COMMA) then 
                    index += 1
                  else
                  if (index < tokens.Count) and (tokens[index].Kind = PAREN_CLOSE) then 
                  begin
                    index += 1;
                    break;
                  end 
                  else
                    raise new ParserException('Ожидалось "," или ")"', tokens[index])
                end
              else index += 1; 
            end;
            
            {if tokens[index].Kind = SQUARE_BRACKET_OPEN then
            begin
              index += 1;
              if not (tokens[index].Kind = SQUARE_BRACKET_CLOSE) then
              begin
                NewN.ArrayLength := ParseExpression;
                if not (tokens[index].Kind = SQUARE_BRACKET_CLOSE) then
                  raise new ParserException('Ожидалось "]"' )
                else index += 1; 
              end
              else index += 1; 
            end;}
            
            Exprs.Nodes.Add(NewN);
            index -= 1;
          end
          else if string(tokens[index].Data).ToLower = 'typeof' then 
          begin
            index += 1;
            var TypeOfExpr := new TypeOfNode;
            ExceptKW(PAREN_OPEN);
            TypeOfExpr.TypeExpr := ParseTypeExpression;
            ExceptKW(PAREN_CLOSE);
            Exprs.Nodes.Add(TypeOfExpr);
            index -= 1;
          end
          else if string(tokens[index].Data).ToLower = 'sizeof' then 
          begin
            index += 1;
            var SizeOfExpr := new SizeOfNode;
            ExceptKW(PAREN_OPEN);
            SizeOfExpr.TypeExpr := ParseTypeExpression;
            ExceptKW(PAREN_CLOSE);
            Exprs.Nodes.Add(SizeOfExpr);
            index -= 1;
          end
          else
          begin
            var IdentExpr := new IdentNodeExpr;
            IdentExpr.Ident := ParseIdent;
            Exprs.Nodes.Add(IdentExpr);
            index -= 1;
          end;
        end;
        
        
        
    else break;                   
    end;
    
    Exprs.DefineBeginPos(BeginPos);
    Exprs.DefineEndPos(tokens[index].EndLine, tokens[index - 1].EndColumn);
    
    index += 1;
    
  until index >= tokens.Count - 1;
  
  StructureExpressionNode(Exprs);
  
  if Exprs.Nodes.Count = 0 then
    raise new ParserException('ожидалось выражение (' + tokens[index].Kind.ToString + ')', tokens[index]);
  
  Result := Exprs;
  
  if (index < tokens.Count) and (tokens[index].Kind = DOT) then
  begin
    var EDot := new ExprDot;
    EDot.Expr := result;
    index += 1;
    EDot.SubIdent := ParseIdent;
    Result := EDot; 
  end;
  
end;

procedure GParser.StructureExpressionNode(var ExprNode: ExpressionsNode);
  
  procedure ProcessExpressionNode(var ExprNode: ExpressionsNode; i: integer; Unar: boolean);
  begin
    (ExprNode.Nodes[i] as ExpressionsNode).Nodes := new List<ExpressionNode>;
    
    if ((ExprNode.Nodes[i] is LogicalOperation) and ((exprNode.Nodes[i] as LogicalOperation).Action = logic_not)) or
    
    ((ExprNode.Nodes[i] is AddBinaryOperation) and ((ExprNode.Nodes[i] as AddBinaryOperation).Action = Subtraction) and  not (i - 1 >= 0)) or Unar then
    begin
      // Если not или - (унарные операторы)
      var TempNode := ExprNode.Nodes[i + 1];
      
      if ((ExprNode.Nodes[i + 1] is LogicalOperation) and ((exprNode.Nodes[i + 1] as LogicalOperation).Action = logic_not)) or
        ((ExprNode.Nodes[i + 1] is AddBinaryOperation) and ((ExprNode.Nodes[i + 1] as AddBinaryOperation).Action = Subtraction))
        then 
        ProcessExpressionNode(ExprNode, i + 1, true);
      
      (ExprNode.Nodes[i] as ExpressionsNode).Nodes.Add(TempNode);
      ExprNode.Nodes.Remove(TempNode);
    end
    else if (i + 1 < ExprNode.Nodes.Count) and (i - 1 >= 0) then
    begin
      var TempNode1 := ExprNode.Nodes[i - 1];
      
      if ((ExprNode.Nodes[i + 1] is LogicalOperation) and ((ExprNode.Nodes[i + 1] as LogicalOperation).Action = logic_not)) or
      ((ExprNode.Nodes[i + 1] is AddBinaryOperation) and ((ExprNode.Nodes[i + 1] as AddBinaryOperation).Action = Subtraction)) then
        ProcessExpressionNode(ExprNode, i + 1, true);
      
      var TempNode2 := ExprNode.Nodes[i + 1];
      
      (ExprNode.Nodes[i] as ExpressionsNode).Nodes.Add(TempNode1);
      (ExprNode.Nodes[i] as ExpressionsNode).Nodes.Add(TempNode2);
      
      ExprNode.Nodes.Remove(TempNode1);
      ExprNode.Nodes.Remove(TempNode2);
      
      i -= 1;
    end 
    else raise new ParserException('Для операции требуется 2 операнда', ExprNode.Nodes[i]); 
  end;

begin
  for var a := 0 to 3 do
  begin
    var i := 0; 
    while i < exprNode.Nodes.Count do
    begin
      if (ExprNode.Nodes[i] is BracketNode) then
      begin
        var p := (ExprNode.Nodes[i] as ExpressionsNode);
        StructureExpressionNode(p);
      end
      else
      begin
        var b := false;
        
        case a of
          0: b := (ExprNode.Nodes[i] is IntegerOperation) or (ExprNode.Nodes[i] is MulBinaryOperation);
          1: b := (ExprNode.Nodes[i] is AddBinaryOperation);
          2: b := (ExprNode.Nodes[i] is CompareOperation);
          3: b := (ExprNode.Nodes[i] is LogicalOperation); 
        end;
        
        if b then
        begin
          if ExprNode.Nodes[i] is ExpressionsNode then
          begin
            if (ExprNode.Nodes[i] as ExpressionsNode).Nodes = nil then
            begin
              ProcessExpressionNode(ExprNode, i, false);
            end else raise new ParserException('Пытаемся вложить в не пустое дерево элементы  (' + ExprNode.Nodes[i].ToString + ')', tokens[index]);
          end else raise new ParserException('Пытаемся вложить в узел, который не предназначен для хранения узлов', tokens[index]);
        end;
      end;
      i += 1;
    end;
  end;
  ExprNode.Nodes.TrimExcess;
end;

function GParser.ExceptKW(TK: Token; KW: TokenKind): boolean;
begin
  if not (TK.Kind = KW) then 
    raise new ParserException('ожидалось "' + TokenKind2Str(KW) + '"', TK);
  index += 1;    
end;

function GParser.ExceptKW(KW: TokenKind): boolean;
begin
  if (index < tokens.Count) then Result := ExceptKW(tokens[index], KW) else raise new Exception('неожиданный конец, ожидалось "' + TokenKind2Str(KW) + '"');
end;

end.