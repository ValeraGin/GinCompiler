/// Юнит кодогенератора
unit CodeGen;

interface

uses
  System,
  System.Diagnostics,
  System.Diagnostics.SymbolStore,
  System.Collections,
  System.Collections.Generic,
  System.Reflection.Emit,
  System.Runtime.InteropServices,
  System.IO,
  System.Reflection,
  ASyntaxTree, 
  ASemanticTree,
  CommonUnit;

type
  GCodeGenerator = class
  private 
    il: Emit.ILGenerator := nil;
    
    docs: Dictionary<string, ISymbolDocumentWriter>;
    
    ModuleName: string;
    
    AsmbName: AssemblyName;
    Asmb: Emit.AssemblyBuilder;
    Modb: Emit.ModuleBuilder;
    TypeBuilder: Emit.TypeBuilder;
    
    typeBuilders := new List<Emit.TypeBuilder>;
    
    Module: SProgramNode;
    
    ContinueLabels: Stack<&Label>;
    BreakLabels: Stack<&Label>;
    
    methodBuilder: Emit.MethodBuilder;
    
    PEFileKind := PEFileKinds.ConsoleApplication;
    
    GlobalSymbolTable: Dictionary<string, Emit.FieldBuilder>;
    SymbolTable: Dictionary<string, Emit.LocalBuilder>;
    
    ArgsSymbolTable: Dictionary<string, integer>;
    ArgsTypes: Dictionary<integer, &Type>;
    
    LabelSymbolTable: Dictionary<string, Emit.Label>;
    
    ResultVar: Emit.LocalBuilder;
    GenResult := False;
    
    GenExitMark := false;
    ExitLabel: &Label;
    
    procedure GenModule;
    
    
    procedure GenUnit(UnitTree: SUnitTree);
    
    procedure GenMethod(Mthd: SFunctionNode; EntryPoint: boolean);
    procedure GenMethod(Mthd: SNetFunctionNode; EntryPoint: boolean);
    procedure GenMethod(Mthd: SNativeFunctionNode; EntryPoint: boolean);
    
    procedure GenStmt(Stmt: SStmtNode; AsExpr: boolean);
    procedure GenFunction(CFunctionNode: SCallFunctionNode);
    
    procedure GenExpr(Expr: SExprNode; params ExpectedTypes: array of &Type);
    procedure GenActionExprNode(Expr: SActionNode; params ExpectedTypes: array of &Type);
    
    procedure MarkSequencePoint(il: Emit.ILGenerator; fname: string; BeginLine, BeginColumn, EndLine, EndColumn: integer);
    
    procedure Store(Name: string; _type: &Type);
  
  public 
    constructor Create(ModuleName: string; Module: SProgramNode);
  end;
  
  CodeGenException = class(Exception)
    Loc: Location;
    constructor Create(message: string; Loc: Location);
    begin
      inherited Create(message);
      self.Loc := Loc;
    end;
  end;

const
  RT_CURSOR = 1;
  RT_BITMAP = 2;
  RT_ICON = 3;
  RT_RCDATA = 10;
  RT_HTML = 23;
  RT_MANIFEST = 24;

implementation


function ArrayToStr<T>(a: array of T; delimiter: string): string;
begin
  result := '[';
  for var i := 0 to a.Length - 2 do
    result := result + object(a[i]).ToString + delimiter;
  result := result + object(a[a.Length - 1]).ToString + ']';  
end;

constructor GCodeGenerator.Create(ModuleName: string; Module: SProgramNode);
begin

  var oldCurDir := Environment.CurrentDirectory;
  Environment.CurrentDirectory := IO.Path.GetDirectoryName(moduleName);
  
  Self.ModuleName := ModuleName;
  Self.Module := Module;
  
  var ext := '.exe';
  if (Module is SLibraryTree) then ext := '.dll';
  
  DeleteFile(IO.Path.ChangeExtension(moduleName, ext));
  
  AsmbName := new AssemblyName(IO.Path.GetFileNameWithoutExtension(moduleName));
  Asmb := System.AppDomain.CurrentDomain.DefineDynamicAssembly(AsmbName, Emit.AssemblyBuilderAccess.Save);
  
  var needDefineVersion := False;
  var ResDefine := False;
  var product, productVersion, company, copyright, trademark: string;
  // Обработка директив
  foreach d: CompilerDirective in Options.CompilerDirectives do
  begin
    if d.Name.ToLower = 'apptype' then
    begin
      if (d.Value.ToLower = 'windows') or (d.Value.ToLower = 'window') then 
        PEFileKind := PEFileKinds.WindowApplication
      else if d.Value.ToLower = 'console' then 
        PEFileKind := PEFileKinds.ConsoleApplication
      else raise new CodeGenException('ожидалось значение "windows" или "console" для директивы "apptype".', d); 
    end
    
    else if d.Name.ToLower = 'product' then
    begin
      needDefineVersion := True;
      product := d.Value;
    end
    
    else if d.Name.ToLower = 'productversion' then
    begin
      needDefineVersion := True;
      productVersion := d.Value;
    end
    
    else if d.Name.ToLower = 'company' then
    begin
      needDefineVersion := True;
      company := d.Value;
    end      
    
    else if d.Name.ToLower = 'copyright' then
    begin
      needDefineVersion := True;
      copyright := d.Value;
    end
    
    else if d.Name.ToLower = 'trademark' then
    begin
      needDefineVersion := True;
      trademark := d.Value;
    end
    
    else if d.Name.ToLower = 'win32res' then 
    begin
      asmb.DefineUnmanagedResource(d.Value)
    end
    
    else if (d.Name.ToLower = 'res') or (d.Name.ToLower = 'resource') then 
    begin
      try
        asmb.AddResourceFile(Path.GetFileName(d.Value), d.Value, ResourceAttributes.Public);
        ResDefine := True;
      except
      end;
      //var rw := asmb.DefineResource('res.resources', 'kz-kz', 'res.resources');
      //rw.AddResource(Path.GetFileName(d.Value), &File.ReadAllBytes (d.Value));
    end;
    
  end;
  
  
  modb := asmb.DefineDynamicModule(AsmbName.Name, 
      AsmbName.Name + ext, Options.Debug);
  
  docs := new Dictionary<string, ISymbolDocumentWriter>;
  
  
  GlobalSymbolTable := new Dictionary<string, FieldBuilder>;
  
  GenModule;
  
  if needDefineVersion and not ResDefine then
    asmb.DefineVersionInfoResource(product, productVersion, company, copyright, trademark);
  
  foreach a: Emit.TypeBuilder in typeBuilders do a.CreateType;
  
  asmb.Save(AsmbName.Name + ext);
  
  modb.CreateGlobalFunctions;
  
  SymbolTable := nil;
  LabelSymbolTable := nil;
  il := nil;
  Environment.CurrentDirectory := oldCurDir;
  
  Options.OutFile := modb.FullyQualifiedName;
end;



procedure GCodeGenerator.GenModule;
begin
  
  for var i := 0 to Module.UsedUnits.Count - 1 do
    self.GenUnit((Module.UsedUnits[i] as SUnitTree)); 
  
  if (Module is SLibraryTree) then
    typeBuilder := modb.DefineType(AsmbName.Name + '.' + AsmbName.Name, TypeAttributes.Public)
  else typeBuilder := modb.DefineType(AsmbName.Name + '.' + 'Program', TypeAttributes.Public);
  
  
  for var i := 0 to Module.GlobalVarList.Count - 1 do
  begin
    if (Module.GlobalVarList[i] is SGlobalDeclareNode) then 
    begin
      var GlobalDeclareNode := SGlobalDeclareNode(Module.GlobalVarList[i]);
      var myFieldBuilder := TypeBuilder.DefineField(GlobalDeclareNode.Name,
         GlobalDeclareNode._Type, FieldAttributes.&Public or FieldAttributes.Static);
      GlobalSymbolTable.Add(GlobalDeclareNode.Name, myFieldBuilder);
    end;
  end;
  
  //DefineMethods(Module.SGeneric_Functions);
  
  foreach a: SFunctionNode in Module.SGeneric_Functions do
    a.ModulBuilder := modb;
  foreach a: SFunctionNode in Module.SGeneric_Functions do
    a.TypBuilder := typeBuilder;  
  
  if (Module is SProgramTree) then GenMethod(Module.SGeneric_Functions[0], True)
  else GenMethod(Module.SGeneric_Functions[0], False);
  
  if not (Module is SProgramTree) then
    for var i := 1 to Module.SGeneric_Functions.Count - 1 do
      GenMethod(Module.SGeneric_Functions[i], False);
  
  typeBuilder.CreateType();
  
end;

procedure GCodeGenerator.GenUnit(UnitTree: SUnitTree);
begin
  for var i := 0 to UnitTree.UsedUnits.Count - 1 do
    self.GenUnit((UnitTree.UsedUnits[i] as SUnitTree));
  
  
  typeBuilder := modb.DefineType(UnitTree.UnitName + '.' + UnitTree.UnitName, TypeAttributes.Public);
  
  for var i := 0 to UnitTree.GlobalVarList.Count - 1 do
  begin
    if (UnitTree.GlobalVarList[i] is SGlobalDeclareNode) then 
    begin
      var GlobalDeclareNode := SGlobalDeclareNode(UnitTree.GlobalVarList[i]);
      var myFieldBuilder := TypeBuilder.DefineField(GlobalDeclareNode.Name,
         GlobalDeclareNode._Type, FieldAttributes.&Public or FieldAttributes.Static);
      GlobalSymbolTable.Add(GlobalDeclareNode.Name, myFieldBuilder);
    end;
  end;
  
  foreach a: SFunctionNode in UnitTree.SGeneric_Functions do
    a.ModulBuilder := modb;
  foreach a: SFunctionNode in UnitTree.SGeneric_Functions do
    a.TypBuilder := typeBuilder;  
  
  typeBuilders.Add(typeBuilder);
  
  
  SymbolTable := nil;
  LabelSymbolTable := nil;
  il := nil;  
end;

procedure GCodeGenerator.GenMethod(Mthd: SFunctionNode; EntryPoint: boolean);
begin
  
  
  if Mthd.MthdBuilder = nil then 
  begin
    var Types := new &Type[Mthd.ParametersType.Count];
    for var b := 0 to Mthd.ParametersType.Count - 1 do
    begin
      Types[b] := Mthd.ParametersType[b]._Type;
    end;
    
    if Mthd is SNetFunctionNode then 
      methodBuilder :=  Mthd.typBuilder.DefineMethod(Mthd.Name, MethodAttributes.Static or MethodAttributes.&Public, Mthd.ReturnType, Types)
    else if (Mthd is SNativeFunctionNode) then
    begin
      
      
      methodBuilder := typeBuilder.DefinePInvokeMethod(
              (Mthd as SNativeFunctionNode).DllNameMethod,
              (Mthd as SNativeFunctionNode).DllName,
              MethodAttributes.Public or MethodAttributes.Static or MethodAttributes.PinvokeImpl or MethodAttributes.HideBySig,
              CallingConventions.Standard,
              Mthd.ReturnType,
              Types,
              CallingConvention.Winapi,
              (Mthd as SNativeFunctionNode).CharSet);
      
      methodBuilder.SetImplementationFlags(MethodImplAttributes($80 or 0));
      
    end      
    else raise new Exception('фигня');
    Mthd.MthdBuilder := methodBuilder;
    
    if Mthd is SNativeFunctionNode then 
      GenMethod((Mthd as SNativeFunctionNode), False)
    else if Mthd is SNetFunctionNode then 
      GenMethod((Mthd as SNetFunctionNode), EntryPoint)
    else raise new Exception('фигня');
  end;
end;

procedure GCodeGenerator.GenMethod(Mthd: SNetFunctionNode; EntryPoint: boolean);
begin
  
  var ArgsTypes2 := ArgsTypes;
  var ArgsSymbolTable2 := ArgsSymbolTable;
  var SymbolTable2 := SymbolTable;
  var LabelSymbolTable2 := LabelSymbolTable;
  var ContinueLabels2 := ContinueLabels;
  var BreakLabels2 := BreakLabels;
  
  var GenExitMark2 := GenExitMark;
  var GenResult2 := GenResult;
  
  var il2 := il;
  
  
  
  ArgsTypes := new Dictionary<integer, &Type>;
  ArgsSymbolTable := new Dictionary<string, integer>;
  SymbolTable := new Dictionary<string, Emit.LocalBuilder>;
  LabelSymbolTable := new Dictionary<string, Emit.Label>;
  ContinueLabels := new Stack<&Label>;
  BreakLabels := new Stack<&Label>;
  
  GenExitMark := false;
  GenResult := false;
  
  
  for var i := 0 to Mthd.ParametersType.Count - 1 do
  begin
    ArgsSymbolTable[Mthd.ParametersType[i].Name] := i;
    ArgsTypes[i] := Mthd.ParametersType[i]._Type;
  end;
  
  methodBuilder := Mthd.MthdBuilder;
  
  if EntryPoint then asmb.SetEntryPoint(methodBuilder, PEFileKind);
  
  
  
  il := methodBuilder.GetILGenerator;
  
  GenStmt(mthd.Body, false);
  
  if (Mthd.ReturnType <> typeof(void)) and GenResult then 
    il.Emit(Emit.OpCodes.Ldloc, ResultVar)
  else
    il.Emit(Emit.OpCodes.Nop);
  
  if GenExitMark then il.MarkLabel(ExitLabel);
  
  il.Emit(Emit.OpCodes.Ret);
  
  ArgsTypes := ArgsTypes2;
  ArgsSymbolTable := ArgsSymbolTable2;
  SymbolTable := SymbolTable2;
  LabelSymbolTable := LabelSymbolTable2;
  ContinueLabels := ContinueLabels2;
  BreakLabels := BreakLabels2;
  GenExitMark := GenExitMark2;
  GenResult := GenResult2;
  
  il := il2;
end;


procedure GCodeGenerator.GenMethod(Mthd: SNativeFunctionNode; EntryPoint: boolean);
begin
  // его генерировать не надо, он уже был обьявлен - этого достаточно
end;


procedure GCodeGenerator.GenFunction(CFunctionNode: SCallFunctionNode);
begin
  if (CFunctionNode is SCallOtherFunctionNode) then
  begin
    var CallFunctionNode := SCallOtherFunctionNode(CFunctionNode);
    for var i := 0 to CallFunctionNode.PassedParameters.Count - 1 do
    begin
      GenExpr(CallFunctionNode.PassedParameters[i], CallFunctionNode.PassedParameters[i]._Type);
      
      { if CallFunctionNode.PassedParameters[i]._Type.IsValueType then 
      il.Emit(Emit.OpCodes.Box, CallFunctionNode.PassedParameters[i]._Type);}
    end;
    
    if not CallFunctionNode.MthdInfo.IsVirtual then
      il.Emit(Emit.OpCodes.Call, CallFunctionNode.MthdInfo)
    else
      il.Emit(Emit.OpCodes.CallVirt, CallFunctionNode.MthdInfo);
  end
  else if (CFunctionNode is SCallOwnFunctionNode) then 
  begin
    var SelfFuncStmt := SCallOwnFunctionNode(CFunctionNode);
    GenMethod(SelfFuncStmt._Function, false);
    
    for var i := 0 to SelfFuncStmt.PassedParameters.Count - 1 do
    begin
      GenExpr(SelfFuncStmt.PassedParameters[i], SelfFuncStmt.PassedParameters[i]._Type);
      {if SelfFuncStmt.PassedParameters[i]._Type.IsValueType then 
      il.Emit(Emit.OpCodes.Box, SelfFuncStmt.PassedParameters[i]._Type);}
    end;  
    
    var mthdinfo := SelfFuncStmt._Function.MthdBuilder.GetBaseDefinition;
    if not mthdinfo.IsVirtual then
      il.Emit(Emit.OpCodes.Call, MthdInfo)
    else
      il.Emit(Emit.OpCodes.CallVirt, MthdInfo);  
    
  end
end;


procedure GCodeGenerator.GenStmt(Stmt: SStmtNode; AsExpr: boolean);
begin
  //if Stmt = nil then exit;
  
  if Options.Debug then MarkSequencePoint(il, Stmt.FileName , Stmt.BeginLine, Stmt.BeginColumn, Stmt.EndLine, Stmt.EndColumn);
  
  if (Stmt is SStmtListNode) then
  begin
    for var i := 0 to (Stmt as SStmtListNode).StmtList.Count - 1 do 
      GenStmt((Stmt as SStmtListNode).StmtList[i], false);
  end

  else if (Stmt is SArrayElemNode) then
  begin
    var ArrayElemNode := SArrayElemNode(Stmt);
    GenExpr(ArrayElemNode.Arr, ArrayElemNode._Type.MakeArrayType);
    
    foreach Expr: SExprNode in ArrayElemNode.Index do 
      GenExpr(Expr, typeof(integer));
    
    il.Emit(Emit.OpCodes.Ldelem, ArrayElemNode._Type);
  end
  
  else if (Stmt is SDotAssignNode) then 
  begin
    var DotAssign := (stmt as SDotAssignNode);
    GenExpr(DotAssign.DotNode.FirstStmt, DotAssign.DotNode.FirstStmt._Type);
    GenExpr(DotAssign.Expr, DotAssign.Expr._Type);
    GenStmt(DotAssign.DotNode.SecondStmt, AsExpr);
  end
  
  else if (Stmt is SPropertyAssignNode) then 
  begin
    var PropertyAssign := (stmt as SPropertyAssignNode);
    GenExpr(PropertyAssign.Expr, PropertyAssign.Prop._Type);
    GenStmt(PropertyAssign.Prop, AsExpr);
  end
  
  else if (Stmt is SVarAssignNode) then 
  begin
    var Assign := (stmt as SVarAssignNode);
    GenExpr(assign.Expr, Assign.Expr._Type); 
    Store(assign.Variable.Name, Assign.Expr._Type);
  end
  
  else if (Stmt is SArrayAssignNode) then 
  begin
    var ArrayAssign := (stmt as SArrayAssignNode);
    
    GenExpr(ArrayAssign.Arr.Arr, ArrayAssign.Arr._Type.MakeArrayType);
    foreach Expr: SExprNode in ArrayAssign.Arr.Index do 
      GenExpr(Expr, typeof(integer));
    
    GenExpr(ArrayAssign.Expr, ArrayAssign.Expr._Type); 
    
    il.Emit(Emit.OpCodes.Stelem, ArrayAssign.Arr._Type);
  end
  
  else if (Stmt is SDeclareNode) then 
  begin
    var DeclareNode := (stmt as SDeclareNode);
    SymbolTable.Item[DeclareNode.Name] := il.DeclareLocal(DeclareNode._Type);
  end
  
  else if (Stmt is SDeclareAndAssignNode) then 
  begin
    var DeclareAndAssignNode := (stmt as SDeclareAndAssignNode);
    
    var Declare := new SDeclareNode;
    Declare.Name := DeclareAndAssignNode.Name;
    Declare._Type := DeclareAndAssignNode._Type;
    GenStmt(Declare, false);
    
    var Assign := new SVarAssignNode;
    Assign.Variable := DeclareAndAssignNode;
    Assign.Expr := DeclareAndAssignNode.Expr;
    GenStmt(Assign, false);
  end
  
  else if (Stmt is SVarListNode) then
  begin
    for var i := 0 to (Stmt as SVarListNode).VarList.Count - 1 do 
      GenStmt((Stmt as SVarListNode).VarList[i], false);
  end
  
  else if (Stmt is SPropertyNode) then
  begin
    var PropertyNode := SPropertyNode(Stmt);
    
    foreach Expr: SExprNode in PropertyNode.PassedParameters do 
      GenExpr(Expr, Expr._Type);
    
    var MthdInfo: MethodInfo;
    
    if PropertyNode.NeedRead then
      MthdInfo := PropertyNode.Prop.GetGetMethod
    else
      MthdInfo := PropertyNode.Prop.GetSetMethod;
    
    if not mthdinfo.IsVirtual then
      il.Emit(Emit.OpCodes.Call, MthdInfo)
    else
      il.Emit(Emit.OpCodes.CallVirt, MthdInfo);  
  end
  
  else if (Stmt is SDotNode) then
  begin
    var DotNode := SDotNode(Stmt);
    GenExpr(DotNode.FirstStmt, DotNode.FirstStmt._Type);
    {if DotNode.FirstStmt._Type.IsValueType then 
      il.Emit(Emit.OpCodes.Box, DotNode.FirstStmt._Type);}
    GenStmt(DotNode.SecondStmt, AsExpr);
  end
  
  
  else if (Stmt is SCallFunctionNode) then
  begin
    GenFunction(Stmt as SCallFunctionNode);
    if ((Stmt as SCallFunctionNode)._Type <> typeof(void)) and not AsExpr then
      il.Emit(OpCodes.Pop);
  end
  
  else if (Stmt is SExitNode) then 
  begin
    if not GenExitMark then
      ExitLabel := il.DefineLabel;
    il.Emit(OpCodes.Br, ExitLabel);
    GenExitMark := True;
  end
  
  else if (Stmt is SBreakNode) then 
  begin
    if BreakLabels.Count > 0 then 
      il.Emit(OpCodes.Br, BreakLabels.Peek)
    else
      raise new Exception('Нельзя вставлять процедуру break вне тела цикла');
  end
  
  else if (Stmt is SContinueNode) then 
  begin
    if ContinueLabels.Count > 0 then 
      il.Emit(OpCodes.Br, ContinueLabels.Peek)
    else
      raise new Exception('Нельзя вставлять процедуру continue вне тела цикла');
  end
  
  else if (Stmt is SReturnNode) then 
  begin
    if (MethodBuilder.ReturnType <> typeof(void)) then
    begin
      var Return := (stmt as SReturnNode);
      GenExpr(Return.Expr, MethodBuilder.ReturnType);
      il.Emit(OpCodes.Ret);
    end 
    else raise new Exception('Нельзя использовать функцию return в процедуре');
    
  end
  
  else if (Stmt is SPrintNode) then 
  begin
    var Print := (stmt as SPrintNode);
    GenExpr(Print.Expr, typeof(object));
    il.Emit(Emit.OpCodes.Call, typeof(System.Console).GetMethod('WriteLine', new System.&Type[1] (Print.Expr._Type)));
  end
  
  else if (Stmt is SRaiseNode) then 
  begin
    var &Raise := (stmt as SRaiseNode);
    GenExpr(&Raise.Expr, typeof(System.Exception));
    il.Emit(Emit.OpCodes.Throw);
  end
  
  else if (Stmt is SIfNode) then 
  begin
    var ifElseStmt := SIfNode(Stmt);
    if (ifElseStmt.ElseBody <> nil) then
    begin
      var ElseLabel := il.DefineLabel;
      var EndLabel := il.DefineLabel;
      GenExpr(ifElseStmt.Condition, typeof(boolean));
      il.Emit(OpCodes.Brfalse, ElseLabel);
      GenStmt(ifElseStmt.ThenBody, false);
      il.Emit(OpCodes.Br, EndLabel);
      il.MarkLabel(ElseLabel);
      GenStmt(ifElseStmt.ElseBody, false);
      il.MarkLabel(EndLabel)
    end
    else
    begin
      GenExpr(ifElseStmt.Condition, typeof(boolean));
      var EndLabel := il.DefineLabel;
      il.Emit(OpCodes.Brfalse, EndLabel);
      GenStmt(ifElseStmt.ThenBody, false);
      il.MarkLabel(EndLabel)
    end
  end
  
  else if (Stmt is SLabelDefNode) then 
  begin
    var name := (stmt as SLabelDefNode).LabelNode.Name;
    if not LabelSymbolTable.ContainsKey(name) then 
      LabelSymbolTable[name] := il.DefineLabel;
    il.MarkLabel(LabelSymbolTable[name]);
    if (stmt as SLabelDefNode).Body <> nil then 
      GenStmt((stmt as SLabelDefNode).Body, false);
  end
  
  else if (Stmt is SGotoNode) then 
  begin
    var name := (stmt as SGotoNode).LabelNode.Name;
    if not LabelSymbolTable.ContainsKey(name) then
      LabelSymbolTable[name] := il.DefineLabel;
    il.Emit(Emit.OpCodes.Br, LabelSymbolTable[name]);
  end
  
  else if (Stmt is SForNode) then 
  begin
    var forLoop := (stmt as SForNode);
    
    var LabelCheckExpr := il.DefineLabel;
    var LabelBody := il.DefineLabel;
    var ContinueLabel := il.DefineLabel;
    var BreakLabel := il.DefineLabel;
    
    
    BreakLabels.Push(BreakLabel);
    ContinueLabels.Push(ContinueLabel);    
    
    GenStmt(forLoop.InitStmt, false);
    il.Emit(OpCodes.Br, LabelCheckExpr);
    il.MarkLabel(LabelBody); 
    GenStmt(forLoop.Body, false);
    il.MarkLabel(ContinueLabel);
    GenStmt(forLoop.IncStmt, false);
    il.MarkLabel(LabelCheckExpr);
    GenExpr(forLoop.WhileExpr, typeof(boolean));
    il.Emit(OpCodes.Brtrue, LabelBody);
    il.MarkLabel(BreakLabel);
    
    BreakLabels.Pop;
    ContinueLabels.Pop;
  end
  
  else if (Stmt is SRepeatNode) then 
  begin
    var repeatUntilLoop := SRepeatNode(stmt);
    var StartLabel := il.DefineLabel;
    var BreakLabel := il.DefineLabel;
    
    BreakLabels.Push(BreakLabel);
    ContinueLabels.Push(StartLabel);   
    
    il.MarkLabel(StartLabel);
    GenStmt(repeatUntilLoop.Body, false);
    GenExpr(repeatUntilLoop.Condition, typeof(boolean));
    il.Emit(OpCodes.Brfalse, StartLabel);
    il.MarkLabel(BreakLabel);
  end
  
  else if (Stmt is SWhileNode) then 
  begin
    var whileLoop := SWhileNode(stmt);
    
    var StartLabel := il.DefineLabel;
    var EndLabel := il.DefineLabel;
    
    BreakLabels.Push(EndLabel);
    ContinueLabels.Push(StartLabel); 
    
    il.MarkLabel(StartLabel);
    GenExpr(whileLoop.Condition, typeof(boolean));
    il.Emit(OpCodes.Brfalse, EndLabel);
    GenStmt(whileLoop.Body, false);
    il.Emit(OpCodes.Br, StartLabel);
    il.MarkLabel(EndLabel)
  end
  
  else if (Stmt is STryNode) then 
  begin
    var TryNode := STryNode(stmt);
    il.BeginExceptionBlock;
    GenStmt(TryNode.TryStatements, false);
    
    if TryNode.ExceptionFilters <> nil then 
    begin
      foreach a: SExceptionFilterNode in TryNode.ExceptionFilters do
      begin
        il.BeginCatchBlock(a.ExceptionType);
        SymbolTable.Item[a.ExceptionVar.Name] := il.DeclareLocal(a.ExceptionVar._Type);
        Store(a.ExceptionVar.Name, a.ExceptionVar._Type);
        GenStmt(a.Body, false);
      end;
    end;
    
    if TryNode.FinallyStatements <> nil then 
    begin
      il.BeginFinallyBlock;
      GenStmt(TryNode.FinallyStatements, false);
    end;
    il.EndExceptionBlock;
  end
  
  else
    raise new System.Exception('Не знаю как сгенерировать ' + stmt.GetType.ToString);
  
end;


procedure GCodeGenerator.GenExpr(Expr: SExprNode; params ExpectedTypes: array of &Type);
type arroftype = array of &Type;
begin
  //var deliveredType := TypeOfExpr(expr);
  
  var ExpectedTypes_NoBUG: arroftype := ExpectedTypes.Clone as arroftype;
  
  if (Expr is SStringLiteral) then
  begin
    il.Emit(Emit.OpCodes.Ldstr, SStringLiteral(expr).Value);
  end
  
  else if (Expr is SCostantNullNode) then
  begin
    il.Emit(Emit.OpCodes.Ldnull); 
  end
  
  else if (Expr is SIntegerLiteral) then
  begin
    il.Emit(Emit.OpCodes.Ldc_I4, SIntegerLiteral(expr).Value); 
  end
  
  else if (Expr is SRealLiteral) then
  begin
    il.Emit(Emit.OpCodes.Ldc_R8, SRealLiteral(expr).Value);
  end 
  
  else if (Expr is SCharLiteral) then
  begin
    il.Emit(Emit.OpCodes.Ldc_I4, SCharLiteral(expr).Value); 
  end 
  
  else if (Expr is SBooleanLiteral) then
  begin
    if SBooleanLiteral(expr).Value then
      il.Emit(Emit.OpCodes.Ldc_I4, 1) else il.Emit(Emit.OpCodes.Ldc_I4, 0);
  end
  
  else if (Expr is SVariableNode) then
  begin
    var ident := SVariableNode(expr).Name;
    
    if SymbolTable.ContainsKey(ident) then
      if not expr.IsDotExpr then 
        il.Emit(Emit.OpCodes.Ldloc, SymbolTable[ident])
      else il.Emit(Emit.OpCodes.Ldloca, SymbolTable[ident])
    
    else if ArgsSymbolTable.ContainsKey(ident) then
      if not expr.IsDotExpr then 
        il.Emit(Emit.OpCodes.Ldarg, ArgsSymbolTable[ident])
      else il.Emit(Emit.OpCodes.Ldarga, ArgsSymbolTable[ident])
    
    
    else if GlobalSymbolTable.ContainsKey(ident) then 
      {if not expr.IsDotExpr then 
        il.Emit(Emit.OpCodes.Ldsfld, GlobalSymbolTable[ident])
      else }
      il.Emit(Emit.OpCodes.Ldsfld, GlobalSymbolTable[ident])
    
    
    else if (ident.ToLower = 'result') and GenResult then 
      if not expr.IsDotExpr then 
        il.Emit(Emit.OpCodes.Ldloc, ResultVar)
      else il.Emit(Emit.OpCodes.Ldloca, ResultVar)
    else
      raise new System.Exception('необъявленная переменная "' + ident + '"');
    
  end
  
  else if (Expr is SDotNode) then
  begin
    GenStmt((Expr as SDotNode), true);
  end
  
  else if (Expr is SPropertyNode) then
  begin
    GenStmt((Expr as SPropertyNode), true);
  end
  
  else if (Expr is SCallFunctionNode) then
  begin
    GenFunction(Expr as SCallFunctionNode);
  end
  
  else if (Expr is SArrayElemNode) then
  begin
    GenStmt((Expr as SArrayElemNode), true);
  end
  
  else if (Expr is SNewArrayNode) then
  begin
    // il.Emit(OpCodes.Nop);
    var NewArray := SNewArrayNode(Expr);
    if NewArray.Length <> nil then GenExpr(NewArray.Length, typeof(integer))
    else il.Emit(OpCodes.Ldc_I4, 0);
    il.Emit(OpCodes.Newarr, NewArray.OfType);
  end
  
  else if (Expr is STypeOfNode) then
  begin
    var TypeOfNode := STypeOfNode(Expr);
    il.Emit(Emit.OpCodes.Ldtoken, TypeOfNode.TypeExpr);
    il.Emit(Emit.OpCodes.Call, typeof(System.&Type).GetMethod('GetTypeFromHandle', new System.&Type[1] (typeof(System.RuntimeTypeHandle))));
  end
  
  else if (Expr is SSizeOfNode) then
  begin
    var SizeOfNode := SSizeOfNode(Expr);
    il.Emit(Emit.OpCodes.Ldloc, il.DeclareLocal(SizeOfNode.TypeExpr));
    il.Emit(Emit.OpCodes.Box, SizeOfNode.TypeExpr);
    il.Emit(Emit.OpCodes.Call, typeof(System.Runtime.InteropServices.Marshal).GetMethod('SizeOf', new System.&Type[1] (typeof(object))));
  end
  
  else if (Expr is SNewObjNode) then
  begin
    var NewObj := SNewObjNode(Expr);
    for var i := 0 to NewObj.PassedParameters.Count - 1 do
      GenExpr(NewObj.PassedParameters[i], NewObj.PassedParameters[i]._Type);
    il.Emit(OpCodes.Newobj, NewObj.ConstInfo);
  end
  
  else if (Expr is SActionNode) then
  begin
    GenActionExprNode((Expr as SActionNode), ExpectedTypes_NoBUG)
  end
  
  else raise new Exception('не знаю как сгенерировать след. выражение типа ' + Expr.GetType.ToString);
  
  foreach t: &Type in ExpectedTypes_NoBUG do
    if Expr._Type.IsSubclassOf(t) then exit;
  
  if &Array.IndexOf(ExpectedTypes_NoBUG, Expr._Type) = -1 then
    if (&Array.IndexOf(ExpectedTypes_NoBUG, typeof(string)) <> -1) and (Expr._Type <> typeof(string)) then
    begin
      {il.Emit(Emit.OpCodes.Box, Expr._Type);
      il.Emit(Emit.OpCodes.Callvirt, typeof(object).GetMethod('ToString'));}
    end
    else 
    begin
      if (&Array.IndexOf(ExpectedTypes_NoBUG, typeof(real)) <> -1) and (Expr._Type = typeof(integer)) then
        il.Emit(Emit.OpCodes.Conv_R8)
      else raise new System.Exception('Нельзя преобразовать тип ' + Expr._Type.Name + ' к  ' + ArrayToStr(ExpectedTypes_NoBUG, ','));
    end;
end;



procedure GCodeGenerator.GenActionExprNode(Expr: SActionNode; params ExpectedTypes: array of &Type);
begin
  if (Expr is SBinaryOperation) then 
  begin
    if Expr.Operands.Count = 2 then
    begin
      GenExpr(expr.Operands[0], Expr._Type);
      GenExpr(expr.Operands[1], Expr._Type);
      
      if (Expr._Type = typeof(integer)) or (Expr._Type = typeof(real)) then
      begin
        if (Expr is SAddBinaryOperation) then 
          case (Expr as SAddBinaryOperation).Action of
            Addition: il.Emit(Emit.OpCodes.Add);
            Subtraction: il.Emit(Emit.OpCodes.Sub);
          end
        else if (Expr is SMulBinaryOperation) then 
          case (Expr as SMulBinaryOperation).Action of
            Multiplication: il.Emit(Emit.OpCodes.Mul);
            Division: il.Emit(Emit.OpCodes.Div);
          end;
      end
      else if (Expr._Type = typeof(string)) then 
      begin
        il.Emit(Emit.OpCodes.Call, typeof(string).GetMethod('Concat', new System.&Type[2](typeof(string), typeof(string))));
      end else raise new CodeGenException(string.Format('Бинарная операция {0} не преминима к типу {1}}', Expr.ToString, Expr._Type.ToString), Expr)
      
    end
    else if (Expr.Operands.Count = 1) and (Expr is SAddBinaryOperation) and ((Expr as SAddBinaryOperation).Action = Subtraction) then
    begin
      GenExpr(expr.Operands[0], Expr._Type);
      il.Emit(Emit.OpCodes.Neg);
    end
    else raise new System.Exception('Бинарные операции должны иметь 2 операнда');
  end
  
  else if (Expr is SIntegerOperation) then 
  begin
    if Expr.Operands.Count = 2 then
    begin
      GenExpr(expr.Operands[0], typeof(integer)); 
      GenExpr(expr.Operands[1], typeof(integer));
      case (Expr as SIntegerOperation).Action of
        DivisionInteger: il.Emit(Emit.OpCodes.Div);
        ModInteger: il.Emit(Emit.OpCodes.Rem);
      end;
    end else raise new System.Exception('Целочисленные операции должны иметь 2 операнда');
  end
  
  else if (Expr is SCompareOperation) then 
  begin
    if Expr.Operands.Count = 2 then
    begin
      GenExpr(expr.Operands[0], expr.Operands[0]._Type);
      GenExpr(expr.Operands[1], expr.Operands[1]._Type);
      case (Expr as SCompareOperation).Action of
        Equal:
          begin
            il.Emit(Emit.OpCodes.Ceq);
          end;
        
        NoEqual:
          begin
            il.Emit(Emit.OpCodes.Ceq);
            il.Emit(Emit.OpCodes.Ldc_I4, 0);
            il.Emit(Emit.OpCodes.Ceq);
          end;
        
        GreaterThan:
          begin
            il.Emit(Emit.OpCodes.Cgt);
          end;
        
        GreaterThanOrEqual:
          begin
            il.Emit(Emit.OpCodes.Clt);
            il.Emit(Emit.OpCodes.Ldc_I4, 0);
            il.Emit(Emit.OpCodes.Ceq);
          end;
        
        LessThan:
          begin
            il.Emit(Emit.OpCodes.Clt);
          end;
        
        LessThanOrEqual:
          begin
            il.Emit(Emit.OpCodes.Cgt);
            il.Emit(Emit.OpCodes.Ldc_I4, 0);
            il.Emit(Emit.OpCodes.Ceq);
          end;
      end;
    end else raise new System.Exception('Операции сравнения должны иметь 2 операнда');
  end
  
  else if (Expr is SLogicalOperation) then 
  begin
    if (Expr as SLogicalOperation).Action = logic_not then
    begin
      if Expr.Operands.Count = 1 then
      begin
        il.Emit(Emit.OpCodes.Ldc_I4, 0);
        il.Emit(Emit.OpCodes.Ceq);
      end else raise new System.Exception('Логическая операция "not" должна иметь один операнд');
    end
    else 
    if Expr.Operands.Count = 2 then
    begin
      case (Expr as SLogicalOperation).Action of
        logic_and:
          begin
            GenExpr(expr.Operands[0], typeof(boolean));
            var FalseLabel := il.DefineLabel;
            il.Emit(OpCodes.Dup);
            il.Emit(OpCodes.Brfalse, FalseLabel);
            GenExpr(expr.Operands[1], typeof(boolean));
            il.Emit(Emit.OpCodes.&And);
            il.MarkLabel(FalseLabel)
          end;
        logic_or:
          begin
            GenExpr(expr.Operands[0], typeof(boolean));
            var FalseLabel := il.DefineLabel;
            il.Emit(OpCodes.Dup);
            il.Emit(OpCodes.Brtrue, FalseLabel);
            GenExpr(expr.Operands[1], typeof(boolean));
            il.Emit(Emit.OpCodes.&Or);
            il.MarkLabel(FalseLabel)
          end;
        logic_xor:
          begin
            GenExpr(expr.Operands[0], typeof(boolean));
            GenExpr(expr.Operands[1], typeof(boolean));
            il.Emit(Emit.OpCodes.&Xor);
          end;
      end;
    end else raise new System.Exception('Логические операции (and, or, xor) должны иметь 2 операнда');
  end 
  else raise new Exception('Не знаю как сгенерировать выражение' + Expr.GetType.ToString)
  // il.Emit(Emit.OpCodes.Pop);
end;


procedure GCodeGenerator.Store(Name: string; _type: &Type);
begin
  if GlobalSymbolTable.ContainsKey(name) then
  begin
    il.Emit(OpCodes.Stsfld,  GlobalSymbolTable[name]);
    exit;
  end;
  
  var locb: LocalBuilder;
  
  if (name.ToLower = 'result') then
  begin
    if (MethodBuilder.ReturnType <> typeof(void)) then
    begin
      if not GenResult then ResultVar := Il.DeclareLocal(MethodBuilder.ReturnType);
      locb := ResultVar;
      GenResult := True;
    end 
    else raise new Exception('Нельзя использовать переменную result в процедуре');
  end
  else if SymbolTable.ContainsKey(name) then
    locb := SymbolTable[name];
  
  if locb <> nil then
  begin
    if (locb.LocalType = _type) then
    begin
      il.Emit(Emit.OpCodes.Stloc, locb);
    end
    else
      raise new System.Exception('переменная "' + name + '" обьявлена как ' + locb.LocalType.Name + ' , но присваивается к типу ' + _type.Name)
  end
  else
    raise new System.Exception('необъявленная переменная "' + name + '"');
end;

procedure GCodeGenerator.MarkSequencePoint(il: Emit.ILGenerator; fname: string; BeginLine, BeginColumn, EndLine, EndColumn: integer);
begin
  if docs.ContainsKey(fname) then 
    il.MarkSequencePoint(docs[fname], BeginLine+1, BeginColumn, EndLine+1, EndColumn)
  else 
  begin
    docs.Add(fname, modb.DefineDocument(fname, SymDocumentType.Text, SymLanguageType.Pascal, SymLanguageVendor.Microsoft));
    il.MarkSequencePoint(docs[fname], BeginLine+1, BeginColumn, EndLine+1, EndColumn)
  end;
 
  //il.MarkSequencePoint(doc, Stmt.BeginLine+1, Stmt.BeginColumn, Stmt.EndLine+1, Stmt.EndColumn);
end;



end.