unit ASyntaxTree;

interface

uses
  System, 
  System.IO, 
  System.Collections,
  System.Collections.Generic,
  CommonUnit;

type
  
  SyntaxNode = class(Location)
  public   
  end;
  
  ExpressionNode = class(SyntaxNode)
  public   
  end;  
  
  TypeExpression = class(SyntaxNode)
  public   
  end; 
  
  TypeNode = class(SyntaxNode)
  public 
    Name: string;
    Expr: TypeExpression;
  end; 
  
  ConstNode = class(SyntaxNode)
  public 
    Name: string;
    Expr: ExpressionNode;
  end; 
  
  StatementNode = class(SyntaxNode)
  public   
  end;
  
  ExprVarNode = class(SyntaxNode)
  public 
    Name: string;
    Expr: ExpressionNode;
  end; 
  
  TypeVarNode = class(SyntaxNode)
  public 
    Name: string;
    Expr: TypeExpression;
  end; 
  
  IdentNode = class(SyntaxNode)
  public 
    IdentList: List<string>;
    BracketList: List<ExpressionNode>;
    SquareBracketList: List<ExpressionNode>;
    SubIdentNode: IdentNode;
    
    function ToString: string; override;
    begin
      for var i := 0 to IdentList.Count - 2 do
        result := result + IdentList[i] + '.';
      result := result + IdentList[IdentList.Count - 1];  
    end;
    
    function ToString(ConvertCount: integer): string;
    begin
      for var i := 0 to ConvertCount - 1 do
        if i = (ConvertCount - 1) then
          result := result + IdentList[IdentList.Count - 1]
        else
          result := result + IdentList[i] + '.';
    end;
  end; 
  
  FunctionParameter = class(SyntaxNode)
  public 
    TypeExpr: TypeExpression;
  end;
  
  FunctionParameterList = class(FunctionParameter)
  public 
    ParList: List<string>;
  end; 
  
  FunctionParameterVar = class(FunctionParameter)
  public 
    Name: string;
  end;
  
  
  FunctionNode = class(SyntaxNode)
  public 
    Name: string;
    ReturnType: TypeExpression;
    ParametersType: List<FunctionParameter>;
    IsFunction: boolean;
  end;
  
  NetFunctionNode = class(FunctionNode)
  public 
    Body: StatementNode;
  end;
  
  NativeFunctionNode = class(FunctionNode)
  public 
    DllName: string;
    DllNameMethod: string;
    CharSet: string;
  end;
  
  // StatementNode
  
  StatementsNode = class(StatementNode)
  public 
    Statements: List<StatementNode>;
  end;
  
  IdentNodeStmt = class(StatementNode)
  public 
    Ident: IdentNode;
  end; 
  
  ExitNode = class(StatementNode)
  public   
  end; 
  
  BreakNode = class(StatementNode)
  public   
  end; 
  
  ContinueNode = class(StatementNode)
  public   
  end; 
  
  ReturnNode = class(StatementNode)
  public 
    Expr: ExpressionNode;
  end; 
  
  PrintNode = class(StatementNode)
  public 
    Expr: ExpressionNode;
  end; 
  
  
  RaiseNode = class(StatementNode)
  public 
    Expr: ExpressionNode;
  end; 
  
  DeclareNode = class(StatementNode)
  public 
    VarList: List<string>;
    Expr: ExpressionNode;
  end; 
  
  ExprDeclareNode = class(DeclareNode)
  public 
    Expr: ExpressionNode;
  end; 
  
  TypeDeclareNode = class(DeclareNode)
  public 
    Expr: TypeExpression;
  end; 
  
  AssignNode = class(StatementNode)
  public 
    Ident: IdentNode;
    Expr: ExpressionNode;
  end; 
  
  
  AssignOperations = (ASSIGN_ADD, ASSIGN_SUB, ASSIGN_MUL, ASSIGN_DIV);
  AssignOpNode = class(StatementNode)
  public 
    Ident: IdentNode;
    Operation: AssignOperations;
    Expr: ExpressionNode;
  end;
  
  IfNode = class(StatementNode)
  public 
    Condition: ExpressionNode;
    ThenBody: StatementNode;
    ElseBody: StatementNode
  end; 
  
  LabelNode = class(StatementNode)
  public 
    Name: string;
    Body: StatementNode;
  end;   
  
  GotoNode = class(StatementNode)
  public 
    Name: string;
  end; 
  
  ForNode = class(StatementNode)
  public 
    Body: StatementNode;
    FromExpression: ExpressionNode;
    ToExpression: ExpressionNode;
    CounterName: string;
    // Обьявление переменной в заголовке ?
    DeclareCounter: boolean;
    &DownTo: boolean;
  end;   
  
  RepeatNode = class(StatementNode)
  public 
    Condition: ExpressionNode;
    Body: StatementsNode;
  end; 
  
  WhileNode = class(StatementNode) 
  public 
    Condition: ExpressionNode;
    Body: StatementNode;
  end; 
  
  ExceptionFilterNode = class(StatementNode) 
  public 
    Body: StatementNode;
    ExceptionVarName: string;
    ExceptionType: TypeExpression;
  end; 
  
  TryNode = class(StatementNode) 
  public 
    TryStatements: StatementNode;
    ExceptionFilters: List<ExceptionFilterNode>;
    FinallyStatements: StatementNode;
  end; 
 
  
  // ExpressionNode
  
  ExprDot = class(ExpressionNode)
  public 
    Expr: ExpressionNode;
    SubIdent: IdentNode;
  end; 
  
  IdentNodeExpr = class(ExpressionNode)
  public 
    Ident: IdentNode;
  end; 
  
  ExpressionsNode = class(ExpressionNode)
  public 
    Nodes: List<ExpressionNode>;
  end;  
  
  ConstantNullNodeExpr = class(ExpressionNode)
  public   
  end; 
  
  StringLiteral = class(ExpressionNode)
  public 
    Value: string;
  end; 
  
  IntegerLiteral = class(ExpressionNode)
  public 
    Value: integer;
  end; 
  
  RealLiteral = class(ExpressionNode)
  public 
    Value: real;
  end; 
  
  BooleanLiteral = class(ExpressionNode)
  public 
    Value: boolean;
  end; 
  
  CharLiteral = class(ExpressionNode)
  public 
    Value: integer;
  end; 
  
  BracketNode = class(ExpressionsNode)
  public  
  end; 
  
  NewNode = class(ExpressionNode)
  public 
    TypeExpr: TypeExpression;
    Parameters: List<ExpressionNode>;
  end; 
  
  TypeOfNode = class(ExpressionNode)
  public 
    TypeExpr: TypeExpression;
  end; 
  
  SizeOfNode = class(ExpressionNode)
  public 
    TypeExpr: TypeExpression;
  end; 
  
  // Type
  TypeExpressionRef = class(TypeExpression)
  public 
    TypeName: string;
  end; 
  
  TypeExprArray = class(TypeExpression)
  public 
    OfType: TypeExpression;
  end; 
  
  TypeExprArrayWithIndex = class(TypeExprArray)
  public 
    IndexExpr: ExpressionNode;
  end; 
  

  
  
  // Operations
  
  
  BinaryOperation = class(ExpressionsNode);
  
  AddBinaryOperations = (Addition, Subtraction);
  AddBinaryOperation = class(BinaryOperation)
  public 
    Action: AddBinaryOperations;
  end; 
  
  MulBinaryOperations = (Multiplication, Division);
  MulBinaryOperation = class(BinaryOperation)
  public 
    Action: MulBinaryOperations;
  end; 
  
  IntegerOperations = (DivisionInteger, ModInteger);
  IntegerOperation = class(ExpressionsNode)
  public 
    Action: IntegerOperations;
  end; 
  
  CompareOperations = (Equal, NoEqual, GreaterThan, GreaterThanOrEqual, LessThan, LessThanOrEqual);
  
  CompareOperation = class(ExpressionsNode)
  public 
    Action: CompareOperations;
  end;
  
  LogicalOperations = (logic_and, logic_or, logic_xor, logic_not);  // not - унарная операция, остальные нет
  LogicalOperation = class(ExpressionsNode)
  public 
    Action: LogicalOperations;
  end; 
  
  
  
  ProgramNode = class(SyntaxNode)
  public 
    SourceFilename: string;
    Generic_Functions: List<FunctionNode>;
    Generic_Uses: List<IdentNode>;
    Generic_UsesAliases: Dictionary<IdentNode, IdentNode>;
    Generic_Types: List<TypeNode>;
    Generic_Const: List<ConstNode>;
    Generic_Vars: List<TypeVarNode>;
    MainFunction: StatementsNode;
  end;
  
  ProgramTree = class(ProgramNode)
  public 
    ProgramName: string;
  end;
  
  UnitTree = class(ProgramNode)
  public 
    UnitName: string;
    //EntryPointFunction: StatementsNode;
  end;
  
  LibraryTree = class(ProgramNode)
  public 
    LibraryName: string;
    //EntryPointFunction: StatementsNode;
  end;


function ArrayToStr<T>(a: array of T; delimiter: string): string;

implementation

function ArrayToStr<T>(a: array of T; delimiter: string): string;
begin
  result := '[';
  for var i := 0 to a.Length - 2 do
    result := result + object(a[i]).ToString + delimiter;
  result := result + object(a[a.Length - 1]).ToString + ']';  
end;


end.