unit ASemanticTree;

interface

uses
  System, 
  System.IO, 
  System.Collections,
  System.Collections.Generic,
  System.Reflection, 
  System.Reflection.Emit,
  ASyntaxTree,
  CommonUnit;

type
  SNode = class(Location)
  public 
  end;
  
  SFunctionNode = class; // forward
  
  STypeNode = class(SNode) 
  public
  end; 
  
  STypeExpr = &Type;
  
  SStmtNode = class(SNode)
  public 
  end;
  
  SExprNode = class(SStmtNode)
  public 
    _Type: STypeExpr;
    IsDotExpr := False;
  end;
  
  // Semantic Type Node


  // Semantic Expression Node
 
  SDotNode = class(SExprNode)
  private 
    _FirstStmt: SExprNode;
    function GetFirstStmt: SExprNode;
    begin
      result := _FirstStmt;
    end;
    procedure SetFirstStmt(value: SExprNode);
    begin
      value.IsDotExpr := True;
      _FirstStmt := value;
    end;
  public 
    SecondStmt: SStmtNode;
    property FirstStmt:SExprNode read GetFirstStmt write SetFirstStmt;
  end; 
  
  SVariableNode = class(SExprNode)
  public 
    Name: string;
  end; 

  SActionNode = class(SExprNode)
  public 
    Operands: List<SExprNode>;
  end; 
  
  //SBinaryOperations = (Addition, Subtraction, Multiplication, Division);
  
  
  SBinaryOperation = class(SActionNode)
  public 
  end; 
  
  SAddBinaryOperation = class(SBinaryOperation)
  public 
    Action: AddBinaryOperations;
  end; 
  
  SMulBinaryOperation = class(SBinaryOperation)
  public 
    Action: MulBinaryOperations;
  end; 
  
  
  //SIntegerOperations = (DivisionInteger, ModInteger); 
  SIntegerOperation = class(SActionNode)
  public 
    Action: IntegerOperations;
  end; 
  
  //SCompareOperations = (Equal, NoEqual, GreaterThan, GreaterThanOrEqual, LessThan, LessThanOrEqual);
  SCompareOperation = class(SActionNode)
  public
    Action: CompareOperations;
  end;
  
 // SLogicalOperations = (logic_and, logic_or, logic_xor, logic_not);
  SLogicalOperation = class(SActionNode)
  public 
    Action: LogicalOperations;
  end; 
  
  // Константные выражения
  SCostantNode = class(SExprNode)
  public 
  end;  
  
  SCostantNullNode = class(SExprNode)
  public 
  end; 

  SStringLiteral = class(SCostantNode)
  public 
    Value: string;
  end; 
  
  SIntegerLiteral = class(SCostantNode)
  public 
    Value: integer;
  end; 
  
  SRealLiteral = class(SCostantNode)
  public 
    Value: real;
  end; 
  
  SBooleanLiteral = class(SCostantNode)
  public 
    Value: boolean;
  end; 
  
  SCharLiteral = class(SCostantNode)
  public 
    Value: integer;
  end; 

  // Semantic Statements Node and Semantic Type Node
  
  SVarListNode = class(SStmtNode)
  public 
    VarList: List<SVariableNode>;
  end;
  
  SGlobalVarNode = class(SVariableNode)
  public
  end; 
  
  SGlobalDeclareNode = class(SGlobalVarNode)
  public
  end; 
  
  SGlobalDeclareAndAssignNode = class(SGlobalVarNode)
  public
    Expr: SExprNode;
  end; 
  
  SDeclareNode = class(SVariableNode)
  public
  end; 
  
  SDeclareAndAssignNode = class(SVariableNode)
  public 
    Expr: SExprNode;
  end;
  
  SParameterNode = class(SDeclareNode)
  public
  end; 
  
  SPropertyNode = class(SExprNode)
  public 
    Prop: PropertyInfo;
    PassedParameters: List<SExprNode>;
    NeedRead: boolean;
  end;
  
  SNewArrayNode = class(SExprNode)
  public 
    OfType: STypeExpr;
    Length: SExprNode;
  end;
  
  SArrayElemNode = class(SExprNode)
  public 
    Arr: SExprNode;
    Index: List<SExprNode>;
  end;
  
  SNewObjNode = class(SExprNode)
  public 
    ConstInfo: ConstructorInfo;
    PassedParameters: List<SExprNode>;
  end;
  
  STypeOfNode = class(SExprNode)
  public 
    TypeExpr: STypeExpr;
  end;
  
  SSizeOfNode = class(SExprNode)
  public 
    TypeExpr: STypeExpr;
  end;
  
  
  SCallFunctionNode = class(SExprNode);
  
  SCallOtherFunctionNode = class(SCallFunctionNode)
  public 
    MthdInfo: MethodInfo;
    PassedParameters: List<SExprNode>;
  end;
  
  SCallOwnFunctionNode = class(SCallFunctionNode)
  public 
    _Function: SFunctionNode;
    PassedParameters: List<SExprNode>;
  end;
  
  
    // Semantic Statements Node
  
  SStmtListNode = class(SStmtNode)
  public 
    StmtList: List<SStmtNode>;
  end;
  
  SArrayAssignNode = class(SStmtNode)
  public 
    Arr: SArrayElemNode;
    Expr: SExprNode;
  end; 
  
  SVarAssignNode = class(SStmtNode)
  public 
    Variable: SVariableNode;
    Expr: SExprNode;
  end; 
  
  SDotAssignNode = class(SStmtNode)
  public 
    DotNode: SDotNode;
    Expr: SExprNode;
  end; 
  
  SPropertyAssignNode = class(SStmtNode)
  public 
    Prop: SPropertyNode;
    Expr: SExprNode;
  end; 
  
  SExitNode = class(SStmtNode)
  public 
  end; 
  
  SBreakNode = class(SStmtNode)
  public 
  end; 
  
  SContinueNode = class(SStmtNode)
  public 
  end; 
  
  SReturnNode = class(SStmtNode)
  public 
    Expr: SExprNode;
  end; 
  
  SPrintNode = class(SStmtNode)
  public 
    Expr: SExprNode;
  end; 
  
  SRaiseNode = class(SStmtNode)
  public 
    Expr: SExprNode;
  end; 

  SIfNode = class(SStmtNode)
  public 
    Condition: SExprNode;
    ThenBody: SStmtNode;
    ElseBody: SStmtNode
  end; 
  
  SLabelNode = class(SNode)
  public 
    Name: string;
    HasGotoNode, HasLabelDefNode: boolean;
  end;   

  SLabelDefNode = class(SStmtNode)
  public 
    LabelNode: SLabelNode;
    Body: SStmtNode;
  end;   
  
  SGotoNode = class(SStmtNode)
  public 
    LabelNode: SLabelNode;
  end; 
  
  SForNode = class(SStmtNode)
  public 
    Body: SStmtNode;
    WhileExpr: SExprNode;
    IncStmt: SStmtNode;
    InitStmt: SStmtNode;
  end;   
  
  SRepeatNode = class(SStmtNode)
  public 
    Condition: SExprNode;
    Body: SStmtNode;
  end; 
  
  SWhileNode = class(SStmtNode) 
  public 
    Condition: SExprNode;
    Body: SStmtNode;
  end; 
  
  SExceptionFilterNode = class(StatementNode) 
  public 
    Body: SStmtNode;
    ExceptionVar: SVariableNode;
    ExceptionType: STypeExpr;
  end; 
  
  STryNode = class(SStmtNode) 
  public 
    TryStatements: SStmtNode;
    ExceptionFilters: List<SExceptionFilterNode>;
    FinallyStatements: SStmtNode;
  end; 


  
  // Other
  
  SFunctionNode = class(SNode)
  public 
    Name: string;
    ReturnType: STypeExpr;
    ParametersType: List<SParameterNode>;
    TypBuilder: TypeBuilder;
    MthdBuilder: MethodBuilder;
    ModulBuilder: ModuleBuilder;
  end;
  
  SNetFunctionNode = class(SFunctionNode)
  public 
    Body: SStmtNode;
  end;
  
  SNativeFunctionNode = class(SFunctionNode)
  public 
    DllName: string;
    DllNameMethod: string;
    CharSet: System.Runtime.InteropServices.CharSet;
  end;
  
  
  SProgramNode = class(SNode)
  public 
    UsedUnits: List<SProgramNode>;
    GlobalVarList: List<SGlobalVarNode>;
    // 0 элемент это EntryPoint для программы
    SGeneric_Functions: List<SFunctionNode>;
  end;
  
  SProgramTree = class(SProgramNode)
  public 
    ProgramName: string;
  end;

  SUnitTree = class(SProgramNode)
  public 
    UnitName: string;
  end;
  
  SLibraryTree = class(SProgramNode)
  public 
    LibraryName: string;
  end;

implementation


end.
