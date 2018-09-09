/// Юнит конвертора синтаксического дерева в семантическое, одновременно оптимизирующий дерево
unit TreeConverter;

interface

uses
  System, 
  System.IO, 
  System.Collections,
  System.Collections.Generic, 
  System.Reflection, 
  System.Reflection.Emit,
  ASyntaxTree,
  ASemanticTree,
  CommonUnit;

type
  SemanticException = class(Exception)
    Loc: Location;
    constructor Create(message: string; Loc: Location);
    begin
      inherited Create(message);
      self.Loc := Loc;
    end;
  end;
  
  
  GetSyntaxTreeProc = function(UnitName: string; Dir: string): UnitTree;
  
  GConverter = class
  private 
    GetSyntaxTree: GetSyntaxTreeProc;
    
    LocalVars: List<string>;
    Variables: Dictionary<string, SVariableNode>;
    
    // Methods: Dictionary<FunctionNode, SFunctionNode>;
    
    OtherMethods: List<SFunctionNode>;
    
    Methods: Dictionary<FunctionNode, SFunctionNode>;
    
    //Labels: Dictionary<string, SLabelNode>;
    LabelsName: List<string>;
    Labels: List<SLabelNode>;
    
    // namepace которые прописаны в uses
    usesNamespaces: List<string>;
    usesAliases: Dictionary<string, string>;
    
    
    procedure DelVarFromList(Name: string);
    procedure VarToList(Name: string; Variable: SVariableNode);
    
    function ParametersMatch(parameters: array of &Type; ParametersInfo: array of ParameterInfo): boolean;
    
    function GetType(typeName: string): &Type;
    function GetMethod(_type: &Type; mthdName: string; ParamTypes: array of &Type): MethodInfo;
    function GetProperty(_type: &Type; propName: string; ParamTypes: array of &Type): PropertyInfo;
    
    
    function GetVar(Name: string; Loc: Location): SVariableNode;
    function CreateMainFunctionNode: SFunctionNode;
    
    function GetStandartAssemblyPath: string;
    procedure InitNamespaces(_Assembly: Assembly);
    procedure LoadAssembly(Name: string; Loc: Location);
    
    function SelfFunctionExist(Name: string): boolean;
    function GetSelfFunction(Name: string; PassedParameters: List<ExpressionNode>): SCallOwnFunctionNode;
    
    
    function ConvertSubIdentNode(_type: &Type; Ident: IdentNode; IdentParseIndex: integer; ForRead: boolean): SStmtNode;
    function ConvertIdentNode(Ident: IdentNode; ForRead: boolean): SStmtNode;
    
    function ConvertFunctionNode(Func: FunctionNode): SFunctionNode;
    function ConvertFunctionNode(Func: NetFunctionNode): SNetFunctionNode;
    function ConvertFunctionNode(Func: NativeFunctionNode): SNativeFunctionNode;
    
    function ConvertStatementNode(Stmt: StatementNode): SStmtNode;
    
    function ConvertExpressionNode(Expr: ExpressionNode; ExpectedType: &Type): SExprNode;
    function ConvertExpressionNode(Expr: ExpressionNode): SExprNode;
    
    function OptimizeExpressionNode(Expr: SExprNode): SExprNode;
    
    procedure Optimize;
    
    function ConvertExpressionNodeAndOptimize(Expr: ExpressionNode): SExprNode;
    
    function ConvertTypeExpressionNode(TypeExpr: TypeExpression): STypeExpr;
    
    //  procedure CreateSemanticTree(SyntaxTree: ProgramNode): SProgramNode;
    procedure CreateSemanticTree;
  protected 
    TypeList: Dictionary<string, STypeExpr>;
  public 
    SyntaxTree: ProgramNode;
    SemanticTree: SProgramNode;
    constructor Create(Prog: ProgramNode; GetSyntaxTree: GetSyntaxTreeProc);
    constructor Create(Prog: ProgramNode; GetSyntaxTree: GetSyntaxTreeProc; Recourse: boolean);
  end;


var
  Types := new Dictionary<string, &Type>;
  Assemblies := new List<Assembly>;
  namespaces := new List<string>;
  
  AllUnitsFilenames := new List<string>;
  AllUnits := new List<GConverter>;

implementation

constructor GConverter.Create(Prog: ProgramNode; GetSyntaxTree: GetSyntaxTreeProc; Recourse: boolean);
begin
  if not Recourse then 
  begin
    Types := new Dictionary<string, &Type>;
    Assemblies := new List<Assembly>;
    namespaces := new List<string>;
    
    AllUnitsFilenames := new List<string>;
    AllUnits := new List<GConverter>;
  end;
  
  self.GetSyntaxTree := GetSyntaxTree;
  SyntaxTree := Prog;
  CreateSemanticTree;
end;

constructor GConverter.Create(Prog: ProgramNode; GetSyntaxTree: GetSyntaxTreeProc);
begin
  Types := new Dictionary<string, &Type>;
  Assemblies := new List<Assembly>;
  namespaces := new List<string>;
  
  AllUnitsFilenames := new List<string>;
  AllUnits := new List<GConverter>;
  
  self.GetSyntaxTree := GetSyntaxTree;
  SyntaxTree := Prog;
  CreateSemanticTree;
end;

procedure GConverter.CreateSemanticTree;
begin
  if (SyntaxTree is UnitTree) then 
  begin
    SemanticTree := new SUnitTree;
    (SemanticTree as SUnitTree).UnitName := (SyntaxTree as UnitTree).UnitName;
  end
  else if (SyntaxTree is LibraryTree) then 
  begin
    SemanticTree := new SLibraryTree;
    (SemanticTree as SLibraryTree).LibraryName := (SyntaxTree as LibraryTree).LibraryName;
  end
  else 
  begin
    SemanticTree := new SProgramTree;
    (SemanticTree as SProgramTree).ProgramName := (SyntaxTree as ProgramTree).ProgramName;
  end;
  
  SemanticTree.GlobalVarList := new List<SGlobalVarNode>;
  SemanticTree.SGeneric_Functions := new List<SFunctionNode>;
  SemanticTree.UsedUnits := new List<SProgramNode>;
  TypeList := new Dictionary<string, STypeExpr>;
  
  // Init vars
  LocalVars := new List<string>;
  Variables := new Dictionary<string, SVariableNode>;
  
  Methods := new Dictionary<FunctionNode, SFunctionNode>;  
  
  usesAliases := new Dictionary<string, string>;
  
  //namespaces := new List<string>;
  //Types := new Dictionary<string, &Type>;
  
  // Стандартная библиотека подключается в любом случае
  LoadAssembly('mscorlib.dll', SyntaxTree);
  
  // Обработка директив
  foreach d: CompilerDirective in Options.CompilerDirectives do
  begin
    if d.Name.ToLower = 'reference' then LoadAssembly(d.Value, d);
  end;
  
  
  OtherMethods := new List<SFunctionNode>;
  usesNamespaces := new List<string>;
  foreach a: IdentNode in SyntaxTree.Generic_Uses do
    if namespaces.Contains(a.ToString.ToLower) then 
      usesNamespaces.Add(a.ToString.ToLower)
    else
    begin
      if not (Path.GetFileNameWithoutExtension(SyntaxTree.SourceFilename) = a.ToString) then
      begin
        var GConv: GConverter;
        if AllUnitsFilenames.Contains(a.ToString) then 
        begin
          GConv := AllUnits[AllUnitsFilenames.IndexOf(a.ToString)];
        end
        else
        begin
          var g := GetSyntaxTree(a.ToString, Path.GetDirectoryName(self.SyntaxTree.SourceFilename));
          GConv := new GConverter(g, GetSyntaxTree, true);
          AllUnits.Add(GConv);
          AllUnitsFilenames.Add(Path.GetFileNameWithoutExtension(g.SourceFilename));
        end;
        
        SemanticTree.UsedUnits.Add(GConv.SemanticTree);
        
          // Добавляем методы из Юнита для того, чтобы потом на них ссылаться
        foreach f: SFunctionNode in  GConv.SemanticTree.SGeneric_Functions do
          OtherMethods.Add(f);
        
        foreach variable: SGlobalVarNode in  GConv.SemanticTree.GlobalVarList do
          VarToList(variable.Name, variable);
        
        
          // добавление того TypeList'a сюда
        foreach pair: KeyValuePair<string, STypeExpr> in GConv.TypeList do
        begin
          TypeList.Add(pair.Key, pair.Value);
        end;
        
        {foreach pair: KeyValuePair<string, &Type> in Types do
        begin
        if not Types.ContainsKey(pair.Key) then 
        Types.Add(pair.Key, pair.Value);
        end;}
        
      end;
    end;
  
  for var i := 0 to SyntaxTree.Generic_Types.Count - 1 do
  begin
    if not TypeList.ContainsKey(SyntaxTree.Generic_Types[i].Name) then 
      TypeList.Add(SyntaxTree.Generic_Types[i].Name, ConvertTypeExpressionNode(SyntaxTree.Generic_Types[i].Expr))
    else raise new SemanticException(string.Format('повторное обьявление {0}', SyntaxTree.Generic_Types[i].Name), SyntaxTree.Generic_Types[i])
  end;
  
  // Верификация UsesAliases
  
  
  foreach pair: KeyValuePair<IdentNode, IdentNode> in SyntaxTree.Generic_UsesAliases do
    if namespaces.Contains(pair.Value.ToString.ToLower) then
      usesAliases.Add(pair.Key.ToString.ToLower,  pair.Value.ToString.ToLower)
    else
      raise new SemanticException(string.Format('{0} не являеться namespace{1}ом', pair.Key.ToString, #39), pair.Key);
  
  
  for var i := 0 to SyntaxTree.Generic_Vars.Count - 1 do
  begin
    if (SyntaxTree.Generic_Vars[i] is TypeVarNode) then
    begin
      var TypeVarN := TypeVarNode(SyntaxTree.Generic_Vars[i]);
      
      var GlobalDeclareNode := new SGlobalDeclareNode;
      GlobalDeclareNode.Name := TypeVarN.Name;
      GlobalDeclareNode._Type := ConvertTypeExpressionNode(SyntaxTree.Generic_Vars[i].Expr);
      
      VarToList(GlobalDeclareNode.Name, GlobalDeclareNode);
      
      SemanticTree.GlobalVarList.Add(GlobalDeclareNode);
    end;
  end;
  
  
  
  {if optimize and not isUnit then
    SemanticTree.SGeneric_Functions.Insert(0, CreateMainFunctionNode)
  else
  begin}
  if SemanticTree is SProgramTree then SemanticTree.SGeneric_Functions.Insert(0, CreateMainFunctionNode);
  foreach fNode: FunctionNode in SyntaxTree.Generic_Functions do
    if not methods.ContainsKey(fNode) then
      SemanticTree.SGeneric_Functions.Add(ConvertFunctionNode(fNode));
  //end;
  
  
  
end;

function GConverter.GetVar(Name: string; Loc: Location): SVariableNode;
begin
  Name := Name.ToLower;
  if Variables.ContainsKey(Name) then
    Result := Variables[Name]
  else raise new SemanticException('необъявленная переменная "' + Name + '"', Loc);
end;

procedure GConverter.VarToList(Name: string; Variable: SVariableNode);
begin
  Name := Name.ToLower;
  if not Variables.ContainsKey(Name) then
  begin
    Variables.Add(Name, Variable);
    LocalVars.Add(Name);
  end
  else
    raise new Exception('Повторное обьявление переменной ' + Name);
end;

procedure GConverter.DelVarFromList(Name: string);
begin
  Name := Name.ToLower;
  Variables.Remove(Name);
  LocalVars.Remove(Name);
end;

function NoVoidOrNil(_type: &Type): boolean;
begin
  if (_type <> typeof(void)) and (_type <> nil) then 
    Result := True
  else Result := False;
end;

function GConverter.CreateMainFunctionNode: SFunctionNode;
begin
  var Func := new NetFunctionNode;
  Func.IsFunction := False;
  Func.Name := 'Main';
  Func.Body := SyntaxTree.MainFunction;
  Func.ParametersType := new List<FunctionParameter>;
  
  // Создание параметра (string[] args)
  var param := new FunctionParameterVar;
  param.Name := 'args';
  
  var ArgsArr := new TypeExprArray;
  var OfTypeExpr := new TypeExpressionRef;
  OfTypeExpr.TypeName := 'system.string';
  ArgsArr.OfType := OfTypeExpr;
  param.TypeExpr := ArgsArr; 
  
  Func.ParametersType.Add(param);
  
  {  Func.IsFunction := True;
    var RetType := new TypeExpressionRef;
    RetType.TypeName := 'System.Int32';
    Func.ReturnType := RetType;}
  
  Result := ConvertFunctionNode(Func);
end;


function GConverter.ConvertFunctionNode(Func: FunctionNode): SFunctionNode;
begin
  if Func is NativeFunctionNode then 
    Result := ConvertFunctionNode((Func as NativeFunctionNode))
  else if Func is NetFunctionNode then 
    Result := ConvertFunctionNode((Func as NetFunctionNode))
  else raise new Exception('фигня');
end;


function GConverter.ConvertFunctionNode(Func: NativeFunctionNode): SNativeFunctionNode;
begin
  Result := new SNativeFunctionNode;
  
  Result.Name := func.Name;
  
  Result.DllName := func.DllName;
  Result.DllNameMethod := func.DllNameMethod;
  
  if func.CharSet <> nil then 
  begin
    var d := new Dictionary<string, System.Runtime.InteropServices.CharSet>;
    d.Add('ansi', System.Runtime.InteropServices.CharSet.Ansi);
    d.Add('auto', System.Runtime.InteropServices.CharSet.Auto);
    d.Add('none', System.Runtime.InteropServices.CharSet.None);
    d.Add('unicode', System.Runtime.InteropServices.CharSet.Unicode);
    if d.ContainsKey(func.CharSet) then 
      Result.CharSet := d[func.CharSet]
    else
      raise new Exception('не определена кодировка вызова подпрограммы из неуправляемой dll');
  end
  else Result.CharSet := System.Runtime.InteropServices.CharSet.Unicode; // по умолчанию
  
  if (func.IsFunction) then 
    Result.ReturnType := ConvertTypeExpressionNode(Func.ReturnType)
  else 
    Result.ReturnType := typeof(void); 
  
  Result.ParametersType := new List<SParameterNode>;
  
  for var i := 0 to Func.ParametersType.Count - 1 do
  begin
    if (Func.ParametersType[i] is FunctionParameterVar) then 
    begin
      var SParamType := new SParameterNode;
      SParamType.Name := (Func.ParametersType[i] as FunctionParameterVar).Name;
      SParamType._Type := ConvertTypeExpressionNode(Func.ParametersType[i].TypeExpr);
      Result.ParametersType.Add(SParamType);
    end
    else if (Func.ParametersType[i] is FunctionParameterList) then 
    begin
      var ParameterList := FunctionParameterList(Func.ParametersType[i]);
      var _type := ConvertTypeExpressionNode(ParameterList.TypeExpr);
      for var a := 0 to ParameterList.ParList.Count - 1 do
      begin
        var SParamType := new SParameterNode;
        SParamType.Name := ParameterList.ParList[a];
        SParamType._Type := _type;
        Result.ParametersType.Add(SParamType);
      end;
    end;
  end;
  
  Methods[Func] := Result;
  
end;


function GConverter.ConvertFunctionNode(Func: NetFunctionNode): SNetFunctionNode;
begin
  Result := new SNetFunctionNode;
  
  Result.Name := func.Name;
  
  if (func.IsFunction) then 
    Result.ReturnType := ConvertTypeExpressionNode(Func.ReturnType)
  else 
    Result.ReturnType := typeof(void); 
  
  Result.ParametersType := new List<SParameterNode>;
  
  LabelsName := new List<string>;
  Labels := new List<SLabelNode>;
  
  var oldLocalVars := LocalVars;
  LocalVars := new List<string>;
  
  for var i := 0 to Func.ParametersType.Count - 1 do
  begin
    if (Func.ParametersType[i] is FunctionParameterVar) then 
    begin
      var SParamType := new SParameterNode;
      SParamType.Name := (Func.ParametersType[i] as FunctionParameterVar).Name;
      SParamType._Type := ConvertTypeExpressionNode(Func.ParametersType[i].TypeExpr);
      
      Result.ParametersType.Add(SParamType);
      
      VarToList(SParamType.Name, SParamType)
    end
    else if (Func.ParametersType[i] is FunctionParameterList) then 
    begin
      var ParameterList := FunctionParameterList(Func.ParametersType[i]);
      var _type := ConvertTypeExpressionNode(ParameterList.TypeExpr);
      for var a := 0 to ParameterList.ParList.Count - 1 do
      begin
        var SParamType := new SParameterNode;
        SParamType.Name := ParameterList.ParList[a];
        SParamType._Type := _type;
        
        Result.ParametersType.Add(SParamType);
        
        VarToList(SParamType.Name, SParamType)
      end;
    end;
  end;
  
  
  if (func.IsFunction) and (Result.ReturnType <> typeof(void)) then 
  begin
    var ResVar := new SVariableNode;
    ResVar._Type := Result.ReturnType;
    ResVar.Name := 'result';
    
    VarToList('result', ResVar);
  end;
  
  Methods[Func] := Result;
  
  Result.Body := ConvertStatementNode(func.Body);
  
  for var i := 0 to LocalVars.Count - 1 do Variables.Remove(LocalVars.Item[i]);
  LocalVars := oldLocalVars;
  
  for var i := 0 to LabelsName.Count - 1 do
  begin
    if not Labels[i].HasLabelDefNode then 
      raise new SemanticException(string.Format('Label {0} нигде не обьявлен, чтобы на него ссылаться', LabelsName[i]), Labels[i]);
  end;
  
  LabelsName.Clear;
  Labels.Clear;
end;

function GConverter.GetSelfFunction(Name: string; PassedParameters: List<ExpressionNode>): SCallOwnFunctionNode;
begin
  Result := new SCallOwnFunctionNode;
  
  // Добавление типов параметров
  Result.PassedParameters := new List<SExprNode>;
  for var i := 0 to PassedParameters.Count - 1 do 
  begin
    Result.PassedParameters.Add(ConvertExpressionNode(PassedParameters[i]));
  end;
  
  var OtherOverloadFunctions := new List<SFunctionNode>;
  for var i := 0 to OtherMethods.Count - 1 do
  begin
    if OtherMethods[i].Name.ToLower = Name then 
      OtherOverloadFunctions.Add(OtherMethods[i]);
  end;
  
  for var i := 0 to OtherOverloadFunctions.Count - 1 do
  begin
    var ParametersMatch: boolean;
    if not (OtherOverloadFunctions[i].ParametersType.Count <> Result.PassedParameters.Count) then 
    begin
      ParametersMatch := True;
      for var a := 0 to OtherOverloadFunctions[i].ParametersType.Count - 1 do
      begin
        if not OtherOverloadFunctions[i].ParametersType[a]._Type.IsAssignableFrom(Result.PassedParameters[a]._Type) then
        begin
          ParametersMatch := False;
          break;
        end;
      end;
    end else ParametersMatch := False;
    
    if ParametersMatch then
    begin
      Result._Function := OtherOverloadFunctions[i];
      Result._Type := OtherOverloadFunctions[i].ReturnType;
      exit;
    end;
  end;
  
  
  
  // Поиск overload функций
  var OverloadFunctions := new List<FunctionNode>;
  for var i := 0 to SyntaxTree.Generic_Functions.Count - 1 do
  begin
    if SyntaxTree.Generic_Functions[i].Name.ToLower = Name then 
      OverloadFunctions.Add(SyntaxTree.Generic_Functions[i]);
  end; 
  
  
  for var i := 0 to OverloadFunctions.Count - 1 do
  begin
    
    var ParametersMatch: boolean;
    
    if not (OverloadFunctions[i].ParametersType.Count <> Result.PassedParameters.Count) then 
    begin
      ParametersMatch := True;
      for var a := 0 to OverloadFunctions[i].ParametersType.Count - 1 do
      begin
        if not ConvertTypeExpressionNode(OverloadFunctions[i].ParametersType[a].TypeExpr).IsAssignableFrom(Result.PassedParameters[a]._Type) then
        begin
          ParametersMatch := False;
          break;
        end;
      end;
    end else ParametersMatch := False;
    
    if ParametersMatch then
    begin
      var SFunc: SFunctionNode;
      if Methods.ContainsKey(OverloadFunctions[i]) then 
        SFunc := Methods[OverloadFunctions[i]]
      else
      begin
        SFunc := ConvertFunctionNode(OverloadFunctions[i]);
        SemanticTree.SGeneric_Functions.Add(SFunc);
      end;
      Result._Function := SFunc;
      Result._Type := SFunc.ReturnType;
      exit;
    end;
  end; 
  
  Result := nil;
end;

function GConverter.SelfFunctionExist(Name: string): boolean;
begin
  Result := False;
  for var i := 0 to SyntaxTree.Generic_Functions.Count - 1 do
    if (SyntaxTree.Generic_Functions[i].Name.ToLower) = Name then 
    begin
      Result := True;
      exit;
    end;  
  for var i := 0 to OtherMethods.Count - 1 do
    if (OtherMethods[i].Name.ToLower) = Name then 
    begin
      Result := True;
      exit;
    end;     
  
end;

// typeName must be LowerCase
function GConverter.GetType(typeName: string): &Type;
begin
  // Обработка на uses Alias
  var typeNameStrArr := typeName.Split('.');
  foreach s: string in self.usesAliases.Keys do
  begin
    if typeNameStrArr[0] = s then 
    begin
      typeName := self.usesAliases[s];
      for var i := 1 to typeNameStrArr.Length - 1 do
        typeName := typeName + '.' + typeNameStrArr[i];
    end;
  end;
  
  if Types.ContainsKey(typeName) then 
    Result := Types[typeName]
  else
  begin
    foreach names: IdentNode in SyntaxTree.Generic_Uses do
    begin
      if Types.ContainsKey(names.ToString.ToLower + '.' + typeName) then 
      begin
        Result := Types[names.ToString.ToLower + '.' + typeName];
        exit;
      end;
    end;
  end;
end;



function GConverter.ParametersMatch(parameters: array of &Type; ParametersInfo: array of ParameterInfo): boolean;
begin
  Result := True;
  if ParametersInfo.Length = parameters.Length then
  begin
    for var i := 0 to parameters.Length - 1 do
      if not (ParametersInfo[i].ParameterType.IsAssignableFrom(parameters[i]))  then
      begin
        Result := False;
        exit;
      end;
  end else Result := False;
end;

// propName must be LowerCase
function GConverter.GetProperty(_type: &Type; propName: string; ParamTypes: array of &Type): PropertyInfo;
begin
  var props := _type.GetProperties;
  foreach pi: PropertyInfo in props do
    if pi.Name.ToLower = propName then 
    begin
      if ParametersMatch(ParamTypes, pi.GetIndexParameters) then 
      begin
        result := pi;
        exit;
      end;
    end;
end;

// mthdName must be LowerCase
function GConverter.GetMethod(_type: &Type; mthdName: string; ParamTypes: array of &Type): MethodInfo;
begin
  var mthds := _type.GetMethods;
  foreach mi: MethodInfo in mthds do
    if mi.Name.ToLower = mthdName then
    begin
      if ParametersMatch(ParamTypes, mi.GetParameters) then 
      begin
        result := mi;
        exit;
      end;
    end;
end;

function GConverter.ConvertSubIdentNode(_type: &Type; Ident: IdentNode; IdentParseIndex: integer; ForRead: boolean): SStmtNode;
begin
  
  if not (Ident.IdentList.Count >= 1) then raise new SemanticException('ожидался идентификатор', Ident);
  
  var CurRealIdentName := Ident.IdentList[IdentParseIndex];
  var CurIdentName := CurRealIdentName.ToLower;
  
  var _Types := new &Type[Ident.BracketList.Count];
  var PassPar := new List<SExprNode>;
  
  var SquareTypes := new &Type[Ident.SquareBracketList.Count];
  var SquarePassPar := new List<SExprNode>;
  
  if Ident.IdentList.Count - 1 = IdentParseIndex then
  begin
    
    for var a := 0 to Ident.BracketList.Count - 1 do
    begin
      var par := ConvertExpressionNode(Ident.BracketList[a]);
      PassPar.Add(par);
      _Types[a] := par._Type;
    end;
    
    for var a := 0 to Ident.SquareBracketList.Count - 1 do
    begin
      var par := ConvertExpressionNode(Ident.SquareBracketList[a]);
      SquareTypes[a] := par._Type;
      SquarePassPar.Add(par);
    end;
  end;
  
  /// Нельзя использовать стандартный метод, так как он чувствителен к регистру
  var MthdInfo := GetMethod(_type, CurIdentName, _Types);
  if MthdInfo <> nil then
  begin
    var CallFunctionNode := new SCallOtherFunctionNode;
    CallFunctionNode.MthdInfo := MthdInfo;
    CallFunctionNode._Type := MthdInfo.ReturnType;
    CallFunctionNode.PassedParameters := PassPar;
    Result := CallFunctionNode;
  end
  else
  begin
    var Prop := GetProperty(_type, CurIdentName, SquareTypes);
    if Prop <> nil then
    begin
      var PropertyNode := new SPropertyNode;
      PropertyNode.PassedParameters := SquarePassPar;
      PropertyNode.NeedRead := ForRead;
      PropertyNode.Prop := Prop;
      PropertyNode._Type :=  Prop.PropertyType;
      Result := PropertyNode;
    end
    else
    begin
      var b := _type;
      
      var d := b.GetMembers(BindingFlags.Public or BindingFlags.Default or BindingFlags.Static);
      
      var g := b.GetMember(CurRealIdentName);
      
      if g.Length = 1 then
        for var i := 0 to d.Length - 1 do 
          if d[i] = g[0] then
          begin
            var IntLit := new SIntegerLiteral;
            IntLit.Value := i;
            IntLit._Type := typeof(integer);
            Result := IntLit;
          end;
    end;
  end;
  
  
  
  if Result = nil then 
    raise new SemanticException('Неизвестный идентификатор ' + CurIdentName, Ident )
    else
  begin
    if ((SquarePassPar.Count > 0))  and (Ident.IdentList.Count = IdentParseIndex - 1)  then 
    begin
      if (Result is SExprNode) and NoVoidOrNil((Result as SExprNode)._Type) then
        if (Result as SExprNode)._Type.IsArray then 
        begin
          var ArrayElemNode := new SArrayElemNode;
          ArrayElemNode.Arr := SExprNode(Result);
          ArrayElemNode.Index := SquarePassPar;
          ArrayElemNode._Type := (Result as SExprNode)._Type.GetElementType;
          Result := ArrayElemNode;
        end;
    end;
    
    if Ident.IdentList.Count - 1 > IdentParseIndex then
    begin
      if (Result is SExprNode) and NoVoidOrNil((Result as SExprNode)._Type) then
      begin
        var FirstStmt := SExprNode(Result);
        Result := new SDotNode;
        (Result as SDotNode).FirstStmt := FirstStmt;
        (Result as SDotNode).SecondStmt := ConvertSubIdentNode(FirstStmt._Type, Ident, IdentParseIndex + 1, ForRead);
        if ((Result as SDotNode).SecondStmt is SExprNode) then
          (Result as SDotNode)._Type := ((Result as SDotNode).SecondStmt as SExprNode)._Type;
        exit;
      end else raise new SemanticException(string.Format('{0} не возвращает ничего, поэтому точка после него запрещена', CurRealIdentName), Ident);
    end 
    else if Ident.SubIdentNode <> nil then 
    begin
      if (Result is SExprNode) and NoVoidOrNil((Result as SExprNode)._Type) then
      begin
        var FirstStmt := SExprNode(Result);
        Result := new SDotNode;
        (Result as SDotNode).FirstStmt := FirstStmt;
        (Result as SDotNode).SecondStmt := ConvertSubIdentNode(FirstStmt._Type, Ident.SubIdentNode, 0, ForRead);
        if ((Result as SDotNode).SecondStmt is SExprNode) then
          (Result as SDotNode)._Type := ((Result as SDotNode).SecondStmt as SExprNode)._Type;
        exit;
      end else raise new SemanticException(string.Format('{0} не возвращает ничего, поэтому точка после него запрещена', CurRealIdentName), Ident);
    end;
  end;
end;



function GConverter.ConvertIdentNode(Ident: IdentNode; ForRead: boolean): SStmtNode;
begin
  
  var CurRealIdentName := '';
  for var IdentParseIndex := 0 to Ident.IdentList.Count - 1 do 
  begin
    if IdentParseIndex = 0 then
      CurRealIdentName := Ident.IdentList[IdentParseIndex]
    else 
      CurRealIdentName := CurRealIdentName + '.' + Ident.IdentList[IdentParseIndex];
    var CurIdentName := CurRealIdentName.ToLower;
    
    // Если это namespace или namespace-alias то прыгаем дальше
    if Namespaces.Contains(CurIdentName) or self.usesAliases.ContainsKey(CurIdentName) then
      continue;
    
    if Variables.ContainsKey(CurIdentName) then
      Result := GetVar(CurIdentName, Ident)
    else if SelfFunctionExist(CurIdentName) then
    begin
      if Ident.IdentList.Count - 1 = IdentParseIndex then
        Result := GetSelfFunction(CurIdentName, Ident.BracketList)
      else
      begin
        Result := GetSelfFunction(CurIdentName, new List<ExpressionNode>);
      end;
      if Result = nil then raise new SemanticException('не найдено подходящей процедуры ' + CurRealIdentName, Ident);
    end
    else
    begin
      var t := GetType(CurIdentName);
      if t <> nil then
      begin
        Result := ConvertSubIdentNode(t, Ident, IdentParseIndex + 1, ForRead);
        exit;
      end;
    end;
    
    
    if Result = nil then 
      raise new SemanticException('Неизвестный идентификатор ' + CurIdentName, Ident )
    else
    begin
      if (Ident.IdentList.Count - 1 > IdentParseIndex) and (Result is SExprNode) then
      begin
        var FirstStmt := SExprNode(Result);
        Result := new SDotNode;
        (Result as SDotNode).FirstStmt := FirstStmt;
        (Result as SDotNode).SecondStmt := ConvertSubIdentNode(FirstStmt._Type, Ident, IdentParseIndex + 1, ForRead);
        if ((Result as SDotNode).SecondStmt is SExprNode) then
          (Result as SDotNode)._Type := ((Result as SDotNode).SecondStmt as SExprNode)._Type;
        exit;
      end;
      (*
      if (Ident.SquareBracketExpr <> nil) and (Ident.IdentList.Count = IdentParseIndex - 1)  then 
      begin
      if (Result is SExprNode) and NoVoidOrNil((Result as SExprNode)._Type) then
      if (Result as SExprNode)._Type.IsArray then 
      begin
      var ArrayElemNode := new SArrayElemNode;
      ArrayElemNode.Arr := SExprNode(Result);
      ArrayElemNode.Index := ConvertExpressionNode(Ident.SquareBracketExpr);
      ArrayElemNode._Type := (Result as SExprNode)._Type.GetElementType;
      Result := ArrayElemNode;
      end;
      end;
      
      if Ident.IdentList.Count - 1 > IdentParseIndex then
      begin
      if (Result is SExprNode) and NoVoidOrNil((Result as SExprNode)._Type) then
      begin
      var FirstStmt := SExprNode(Result);
      Result := new SDotNode;
      (Result as SDotNode).FirstStmt := FirstStmt;
      (Result as SDotNode).SecondStmt := ConvertSubIdentNode(FirstStmt._Type, Ident, IdentParseIndex + 1, ForRead);
      if ((Result as SDotNode).SecondStmt is SExprNode) then
      (Result as SDotNode)._Type := ((Result as SDotNode).SecondStmt as SExprNode)._Type;
      exit;
      end else raise new SemanticException(string.Format('{0} не возвращает ничего, поэтому точка после него запрещена', CurRealIdentName), Ident);
      end 
      else if Ident.SubIdentNode <> nil then 
      begin
      if (Result is SExprNode) and NoVoidOrNil((Result as SExprNode)._Type) then
      begin
      var FirstStmt := SExprNode(Result);
      Result := new SDotNode;
      (Result as SDotNode).DotFirstStmtAdd(FirstStmt);
      (Result as SDotNode).SecondStmt := ConvertSubIdentNode(FirstStmt._Type, Ident.SubIdentNode, 0, ForRead);
      if ((Result as SDotNode).SecondStmt is SExprNode) then
      (Result as SDotNode)._Type := ((Result as SDotNode).SecondStmt as SExprNode)._Type;
      exit;
      end else raise new SemanticException(string.Format('{0} не возвращает ничего, поэтому точка после него запрещена', CurRealIdentName), Ident);
      end; *)
    end;
    
    
  end; // for 
end;

function GConverter.ConvertStatementNode(Stmt: StatementNode): SStmtNode;
label 53;
begin
  if Stmt = nil then 
  begin
    Result := nil;
    exit;
  end;
  
  if (Stmt is StatementsNode) then
  begin
    Result := new SStmtListNode;
    (Result as SStmtListNode).StmtList := new List<SStmtNode>;
    
    var oldLocalVars := LocalVars;
    LocalVars := new List<string>;
    
    for var i := 0 to (Stmt as StatementsNode).Statements.Count - 1 do 
      (Result as SStmtListNode).StmtList.Add(ConvertStatementNode((Stmt as StatementsNode).Statements[i]));
    
    for var i := 0 to LocalVars.Count - 1 do Variables.Remove(LocalVars.Item[i]);
    LocalVars := oldLocalVars;
  end
  
  else if (Stmt is ExitNode) then 
  begin
    Result := new SExitNode;
  end
  
  else if (Stmt is BreakNode) then 
  begin
    Result := new SBreakNode;
  end
  
  else if (Stmt is ContinueNode) then 
  begin
    Result := new SContinueNode;
  end
  
  else if (Stmt is ReturnNode) then 
  begin
    Result := new SReturnNode;
    (Result as SReturnNode).Expr := ConvertExpressionNode((Stmt as ReturnNode).Expr);
  end
  
  else if (Stmt is PrintNode) then 
  begin
    Result := new SPrintNode;
    (Result as SPrintNode).Expr := ConvertExpressionNode((Stmt as PrintNode).Expr);
  end
  
  else if (Stmt is RaiseNode) then 
  begin
    Result := new SRaiseNode;
    (Result as SRaiseNode).Expr := ConvertExpressionNode((Stmt as RaiseNode).Expr);
    if typeof(System.Exception).IsSubclassOf((Result as SRaiseNode).Expr._Type) then
      raise new SemanticException('Тип исключения должен быть System.Exception или его потомком',
      (Stmt as RaiseNode).Expr);
  end
  
  else if (Stmt is AssignNode) then 
  begin
    var AssignN := AssignNode(Stmt);
    var t := ConvertIdentNode(AssignN.Ident, false);
    if (t is SVariableNode) then 
    begin
      Result := new SVarAssignNode;
      (Result as SVarAssignNode).Expr := ConvertExpressionNode(AssignN.Expr);
      (Result as SVarAssignNode).Variable := SVariableNode(t)
    end
    else if (t is SPropertyNode) then
    begin
      Result := new SPropertyAssignNode;
      (Result as SPropertyAssignNode).Expr := ConvertExpressionNode(AssignN.Expr);
      (Result as SPropertyAssignNode).Prop := SPropertyNode(t);
    end
    else if (t is SArrayElemNode) then
    begin
      Result := new SArrayAssignNode;
      (Result as SArrayAssignNode).Expr := ConvertExpressionNode(AssignN.Expr);
      (Result as SArrayAssignNode).Arr := SArrayElemNode(t);
    end
    else if (t is SDotNode) and (((t as SDotNode).SecondStmt is SVariableNode)
      or ((t as SDotNode).SecondStmt is SPropertyNode) or ((t as SDotNode).SecondStmt is SArrayElemNode)) then
    begin
      Result := new SDotAssignNode;
      (Result as SDotAssignNode).Expr := ConvertExpressionNode(AssignN.Expr);
      (Result as SDotAssignNode).DotNode := SDotNode(t);
    end
    else raise new SemanticException('не найдена переменная', AssignN)
  end
  
  else if (Stmt is TypeDeclareNode) then 
  begin
    var TypeDeclareStmt := TypeDeclareNode(stmt);
    if TypeDeclareStmt.VarList.Count = 1 then 
    begin
      var SDeclare := new SDeclareNode;
      SDeclare.Name := TypeDeclareStmt.VarList[0];
      SDeclare._Type := ConvertTypeExpressionNode(TypeDeclareStmt.Expr);
      
      VarToList(SDeclare.Name, SDeclare);
      
      Result := SDeclare;
    end
    else
    begin
      var VarListNode := new SVarListNode;
      VarListNode.VarList := new List<SVariableNode>;
      for var i := 0 to TypeDeclareStmt.VarList.Count - 1 do
      begin
        var SDeclare := new SDeclareNode;
        SDeclare.Name := TypeDeclareStmt.VarList[i];
        SDeclare._Type := ConvertTypeExpressionNode(TypeDeclareStmt.Expr);
        
        VarToList(SDeclare.Name, SDeclare);
        
        VarListNode.VarList.Add(SDeclare);
      end;
      Result := VarListNode;
    end;
  end
  
  else if (Stmt is ExprDeclareNode) then 
  begin
    var ExprDeclareStmt := ExprDeclareNode(stmt);
    
    if ExprDeclareStmt.VarList.Count = 1 then 
    begin
      var SDeclareAndAssign := new SDeclareAndAssignNode;
      SDeclareAndAssign.Name := ExprDeclareStmt.VarList[0];
      SDeclareAndAssign.Expr := ConvertExpressionNode(ExprDeclareStmt.Expr);
      SDeclareAndAssign._Type := SDeclareAndAssign.Expr._Type;
      
      VarToList(SDeclareAndAssign.Name, SDeclareAndAssign);
      
      Result := SDeclareAndAssign;
    end
    else
    begin
      var VarListNode := new SVarListNode;
      VarListNode.VarList := new List<SVariableNode>;
      for var i := 0 to ExprDeclareStmt.VarList.Count - 1 do
      begin
        
        var SDeclareAndAssign := new SDeclareAndAssignNode;
        SDeclareAndAssign.Name := ExprDeclareStmt.VarList[i];
        SDeclareAndAssign.Expr := ConvertExpressionNode(ExprDeclareStmt.Expr);
        SDeclareAndAssign._Type := SDeclareAndAssign.Expr._Type;
        
        VarToList(SDeclareAndAssign.Name, SDeclareAndAssign);
        
        VarListNode.VarList.Add(SDeclareAndAssign);
      end;
      Result := VarListNode;
    end;
  end
  
  else if (Stmt is IfNode) then 
  begin
    var ifElseStmt := IfNode(Stmt);
    var SIfElse := new SIfNode;
    SIfElse.Condition := ConvertExpressionNode(ifElseStmt.Condition);
    SIfElse.ThenBody := ConvertStatementNode(ifElseStmt.ThenBody);
    SIfElse.ElseBody := ConvertStatementNode(ifElseStmt.ElseBody);
    Result := SIfElse;
  end
  
  else if (Stmt is LabelNode) then 
  begin
    var Syn_Label := LabelNode(stmt);
    
    var Sem_Label := new SLabelDefNode;
    
    if not LabelsName.Contains(Syn_Label.Name) then 
    begin
      var SLabel := new SLabelNode;
      SLabel.Name := Syn_Label.Name;
      SLabel.HasLabelDefNode := True;
      SLabel.HasGotoNode := False;
      Sem_Label.LabelNode := SLabel;
      
      LabelsName.Add(SLabel.Name);
      Labels.Add(SLabel);
    end 
    else
    begin
      Sem_Label.LabelNode := Labels[LabelsName.IndexOf(Syn_Label.Name)];
      Sem_Label.LabelNode.HasLabelDefNode := True;
    end;
    
    Sem_Label.Body := ConvertStatementNode(Syn_Label.Body);
    
    Result := Sem_Label;
  end
  
  else if (Stmt is GotoNode) then 
  begin
    
    var Syn_Goto := GotoNode(stmt);
    
    var Sem_Goto := new SGotoNode;
    
    if not LabelsName.Contains(Syn_Goto.Name) then 
    begin
      var SLabel := new SLabelNode;
      SLabel.Name := Syn_Goto.Name;
      SLabel.HasLabelDefNode := False;
      SLabel.HasGotoNode := True;
      Sem_Goto.LabelNode := SLabel;
      LabelsName.Add(SLabel.Name);
      Labels.Add(SLabel);
    end 
    else
    begin
      Sem_Goto.LabelNode := Labels[LabelsName.IndexOf(Syn_Goto.Name)];
      Sem_Goto.LabelNode.HasGotoNode := True;
    end;
    
    Result := Sem_Goto;
    
  end
  
  else if (Stmt is ForNode) then 
  begin
    
    var ForLoop := ForNode(stmt);
    
    var Sem_ForLoop := new SForNode;
    
    
    var DeclareNameVar := '';
    // Gen InitStatement
    if ForLoop.DeclareCounter then
    begin
      var InitStatement := new SDeclareAndAssignNode;
      InitStatement.Name := ForLoop.CounterName;
      InitStatement.Expr := ConvertExpressionNode(ForLoop.FromExpression, typeof(integer));
      InitStatement._Type := InitStatement.Expr._Type;
      
      DeclareNameVar := InitStatement.Name;
      
      VarToList(InitStatement.Name, InitStatement);
      
      Sem_ForLoop.InitStmt := InitStatement;
    end
    else
    begin
      var InitStatement := new SVarAssignNode;
      InitStatement.Expr := ConvertExpressionNode(ForLoop.FromExpression, typeof(integer));
      InitStatement.Variable := GetVar(ForLoop.CounterName, ForLoop);
      Sem_ForLoop.InitStmt := InitStatement;
    end;
    
    // Gen Body
    Sem_ForLoop.Body := ConvertStatementNode(ForLoop.Body);
    
    // Gen IncStatement 
    
    var IncExpr := new SAddBinaryOperation;
    IncExpr._Type := typeof(integer);
    
    IncExpr.Operands := new List<SExprNode>;
    IncExpr.Operands.Add(GetVar(ForLoop.CounterName, ForLoop));
    
    var IntLiteral := new SIntegerLiteral;
    IntLiteral.Value := 1;
    IntLiteral._Type := typeof(integer);
    
    IncExpr.Operands.Add(IntLiteral);
    
    if ForLoop.&DownTo then IncExpr.Action := Subtraction else
      IncExpr.Action := Addition;
    
    var IncStatement :=  new SVarAssignNode;
    IncStatement.Expr := IncExpr;  
    IncStatement.Variable := GetVar(ForLoop.CounterName, ForLoop);
    
    Sem_ForLoop.IncStmt := IncStatement;
    
    // Gen WhileExpr
    var WhileExpr := new SCompareOperation;
    WhileExpr.Operands := new List<SExprNode>;
    WhileExpr.Operands.Add(GetVar(ForLoop.CounterName, ForLoop));
    WhileExpr.Operands.Add(ConvertExpressionNode(forloop.ToExpression, typeof(integer)));
    WhileExpr._Type := typeof(boolean);
    
    if ForLoop.&DownTo then WhileExpr.Action := GreaterThanOrEqual else
      WhileExpr.Action := LessThanOrEqual;
    
    Sem_ForLoop.WhileExpr := WhileExpr;
    
    DelVarFromList(DeclareNameVar);
    
    Result := Sem_ForLoop;
  end
  
  else if (Stmt is RepeatNode) then 
  begin
    var repeatUntilLoop := RepeatNode(stmt);
    
    var SrepeatUntilLoop := new SRepeatNode;
    SrepeatUntilLoop.Body := ConvertStatementNode(repeatUntilLoop.Body);
    SrepeatUntilLoop.Condition := ConvertExpressionNode(repeatUntilLoop.Condition);
    
    Result := SrepeatUntilLoop;
  end
  
  else if (Stmt is WhileNode) then 
  begin
    var whileLoop := WhileNode(stmt);
    
    var SwhileLoop := new SWhileNode;
    SwhileLoop.Body := ConvertStatementNode(whileLoop.Body);
    SwhileLoop.Condition := ConvertExpressionNode(whileLoop.Condition);
    
    Result := SwhileLoop;
  end
  
  
  else if (Stmt is TryNode) then 
  begin
    var TryNode := TryNode(stmt);
    var STryNode_ := new STryNode;
    STryNode_.TryStatements := ConvertStatementNode(TryNode.TryStatements);
    
    STryNode_.ExceptionFilters := new List<SExceptionFilterNode>;
    foreach a: ExceptionFilterNode in TryNode.ExceptionFilters do
    begin
      var SExceptionFilter := new SExceptionFilterNode;
      SExceptionFilter.ExceptionType :=  self.ConvertTypeExpressionNode(a.ExceptionType);
      
      var ExceptionVar := new SVariableNode;
      ExceptionVar._Type := SExceptionFilter.ExceptionType;
      ExceptionVar.Name := a.ExceptionVarName;
      
      SExceptionFilter.ExceptionVar := ExceptionVar;
      
      VarToList(SExceptionFilter.ExceptionVar.Name, ExceptionVar);
      SExceptionFilter.Body := ConvertStatementNode(a.Body);
      DelVarFromList(SExceptionFilter.ExceptionVar.Name);
      
      STryNode_.ExceptionFilters.Add(SExceptionFilter);
    end;
    
    STryNode_.FinallyStatements := ConvertStatementNode(TryNode.FinallyStatements);
    Result := STryNode_;
  end
  
  else if (Stmt is IdentNodeStmt) then 
  begin
    Result := ConvertIdentNode((Stmt as IdentNodeStmt).Ident, true);
  end
  else
    raise new SemanticException('Не знаю как сгенерировать ' + stmt.GetType.ToString, stmt);
  if Result <> nil then Result.LocCopyFrom(stmt);  
end;


function GConverter.OptimizeExpressionNode(Expr: SExprNode): SExprNode;
begin
  
  /// Ааа.. ну никак не могу придумать!!!
  {if (Expr is SBinaryOperation) or (Expr is SIntegerOperation) then
  begin
  var AddOp := (Expr is SAddBinaryOperation);
  
  end}
end;

function GConverter.ConvertExpressionNodeAndOptimize(Expr: ExpressionNode): SExprNode;
begin
  Result := OptimizeExpressionNode(ConvertExpressionNode(Expr));
end;

function GConverter.ConvertExpressionNode(Expr: ExpressionNode): SExprNode;
begin
  if (Expr is StringLiteral) then
  begin
    var StrLiteral := new SStringLiteral;
    StrLiteral._type := typeof(string);
    StrLiteral.Value := (Expr as StringLiteral).Value;
    Result := StrLiteral;
  end
  
  else if (Expr is NewNode) then
  begin
    var NewN := NewNode(Expr);
    var _type := ConvertTypeExpressionNode(NewN.TypeExpr);
    if (NewN.TypeExpr is TypeExprArray) then 
    begin
      var NewArrayNode := new SNewArrayNode;
      
      if (NewN.TypeExpr is TypeExprArrayWithIndex) then 
        NewArrayNode.Length := ConvertExpressionNode((NewN.TypeExpr as TypeExprArrayWithIndex).IndexExpr);
      
      NewArrayNode.OfType := ConvertTypeExpressionNode( (NewN.TypeExpr as TypeExprArray).OfType );
      NewArrayNode._Type := _type;
      Result := NewArrayNode;
    end
    else
    begin
      var NewObjNode := new SNewObjNode;
      NewObjNode.PassedParameters := new List<SExprNode>;
      var _Types := new &Type[NewN.Parameters.Count];
      for var a := 0 to NewN.Parameters.Count - 1 do
      begin
        var par := ConvertExpressionNode(NewN.Parameters[a]);
        NewObjNode.PassedParameters.Add(par);
        _Types[a] := par._Type;
      end;
      
      NewObjNode._Type := _type;
      
      NewObjNode.ConstInfo := _type.GetConstructor(_Types);
      
      if NewObjNode.ConstInfo = nil then
        raise new SemanticException('не найден конструктор для ' + _type.ToString, NewN);
      
      Result := NewObjNode;
    end;
  end
  
  else if (Expr is ConstantNullNodeExpr) then
  begin
    Result := new SCostantNullNode;
    Result._Type := typeof(system.object);
  end
  
  else if (Expr is IntegerLiteral) then
  begin
    var IntLiteral := new SIntegerLiteral;
    IntLiteral._type := typeof(integer);
    IntLiteral.Value := (Expr as IntegerLiteral).Value;
    Result := IntLiteral;
  end
  
  else if (Expr is RealLiteral) then
  begin
    var _RealLiteral := new SRealLiteral;
    _RealLiteral._type := typeof(real);
    _RealLiteral.Value := (Expr as RealLiteral).Value;
    Result := _RealLiteral;
  end 
  
  
  else if (Expr is BooleanLiteral) then
  begin
    var BoolLiteral := new SBooleanLiteral;
    BoolLiteral._type := typeof(boolean);
    BoolLiteral.Value := (Expr as BooleanLiteral).Value;
    Result := BoolLiteral;
  end
  
  else if (Expr is CharLiteral) then
  begin
    var _CharLiteral := new SCharLiteral;
    _CharLiteral._type := typeof(char);
    _CharLiteral.Value := (Expr as CharLiteral).Value;
    Result := _CharLiteral;
  end 
  
  else if (Expr is TypeOfNode) then
  begin
    var _TypeOfNode := new STypeOfNode;
    _TypeOfNode.TypeExpr := ConvertTypeExpressionNode((Expr as TypeOfNode).TypeExpr);
    _TypeOfNode._type := typeof(System.&Type);
    Result := _TypeOfNode;
  end 
  
  else if (Expr is SizeOfNode) then
  begin
    var _SizeOfNode := new SSizeOfNode;
    _SizeOfNode.TypeExpr := ConvertTypeExpressionNode((Expr as SizeOfNode).TypeExpr);
    // Если это простой числовой тип, то выдадим константу его размера
    if TypeSizes.ContainsKey(_SizeOfNode.TypeExpr) then 
    begin
      var IntLiteral := new SIntegerLiteral;
      IntLiteral._type := typeof(integer);
      IntLiteral.Value := TypeSizes[_SizeOfNode.TypeExpr];
      Result := IntLiteral;
    end
    else
    begin
      _SizeOfNode._type := typeof(integer);
      Result := _SizeOfNode;
    end;
  end 
  
  else if (Expr is ExprDot) then 
  begin
    var DotNode := new SDotNode;
    DotNode.FirstStmt := ConvertExpressionNode((Expr as ExprDot).Expr);
    DotNode.SecondStmt := self.ConvertSubIdentNode(DotNode.FirstStmt._Type, (Expr as ExprDot).SubIdent, 0, true);
    DotNode._Type := (DotNode.SecondStmt as SExprNode)._Type;
    Result := DotNode;
  end
  
  else if (Expr is IdentNodeExpr) then 
  begin
    var t := ConvertIdentNode((Expr as IdentNodeExpr).Ident, true);
    if (t is SExprNode) then 
      Result := SExprNode(t)
    else raise new SemanticException('не возвращает значение ' + (Expr as IdentNodeExpr).Ident.ToString, t);
  end
  
  else if (Expr is ExpressionsNode) then
  begin
    var Operands := new List<SExprNode>;
    
    if (Expr is BinaryOperation) or (Expr is IntegerOperation) or (Expr is  CompareOperation) or (Expr is LogicalOperation) then 
    begin
      Operands := new List<SExprNode>;
      for var i := 0 to (Expr as ExpressionsNode).Nodes.Count - 1 do
      begin
        Operands.Add(ConvertExpressionNode((Expr as ExpressionsNode).Nodes[i]));
      end;
    end;
    
    if (Expr is BinaryOperation) then 
    begin
      if (Expr is AddBinaryOperation) then 
      begin
        var AddBinaryOp := new SAddBinaryOperation;
        AddBinaryOp.Operands := Operands;
        AddBinaryOp.Action := (Expr as AddBinaryOperation).Action;
        
        // Исключительный случай для String
        
        if (AddBinaryOp.Action = Addition) and ((AddBinaryOp.Operands[0]._Type = typeof(string)) or (AddBinaryOp.Operands[1]._Type = typeof(string))) then
          AddBinaryOp._Type := typeof(string)
        
        else if (AddBinaryOp.Action = Subtraction) and (AddBinaryOp.Operands.Count = 1) then 
          AddBinaryOp._Type := AddBinaryOp.Operands[0]._Type
        else if AddBinaryOp.Operands[0]._Type = typeof(real) then
        begin
          if (AddBinaryOp.Operands[1]._Type = typeof(integer)) or  (AddBinaryOp.Operands[1]._Type = typeof(real)) then 
            AddBinaryOp._Type := typeof(real)
          else raise new SemanticException('ошибкин', Expr);
        end
        
        else if AddBinaryOp.Operands[0]._Type = typeof(integer) then
        begin
          if (AddBinaryOp.Operands[1]._Type = typeof(real)) then 
            AddBinaryOp._Type := typeof(real)
          else if (AddBinaryOp.Operands[1]._Type = typeof(integer)) then 
            AddBinaryOp._Type := typeof(integer)
          else raise new SemanticException('ошибкин', Expr);
        end
        
        else raise new SemanticException('ошибкин', Expr);
        
        Result := AddBinaryOp;  
      end
      
      else if (Expr is MulBinaryOperation) then
      begin
        var MulBinaryOp := new SMulBinaryOperation;
        MulBinaryOp.Operands := Operands;
        MulBinaryOp.Action := (Expr as MulBinaryOperation).Action;
        
        if MulBinaryOp.Operands[0]._Type = typeof(real) then
        begin
          if (MulBinaryOp.Operands[1]._Type = typeof(integer)) or  (MulBinaryOp.Operands[1]._Type = typeof(real)) then 
            MulBinaryOp._Type := typeof(real)
          else raise new SemanticException('ошибкин', Expr);
        end
        
        else if MulBinaryOp.Operands[0]._Type = typeof(integer) then
        begin
          if (MulBinaryOp.Operands[1]._Type = typeof(real)) then 
            MulBinaryOp._Type := typeof(real)
          else if (MulBinaryOp.Operands[1]._Type = typeof(integer)) then 
            if MulBinaryOp.Action = Division then
              MulBinaryOp._Type := typeof(real)
            else
              MulBinaryOp._Type := typeof(integer)
          else raise new SemanticException('ошибкин', Expr);
        end
        
        else raise new SemanticException('ошибкин', Expr);
        
        
        Result := MulBinaryOp;  
      end
      
      else raise new SemanticException('ошибка', Expr);
    end
    
    else if (Expr is IntegerOperation) then 
    begin
      var SIntegerOp := new SIntegerOperation;
      SIntegerOp.Operands := Operands;
      SIntegerOp.Action := (Expr as IntegerOperation).Action;
      SIntegerOp._Type := typeof(integer);
      Result := SIntegerOp;
    end
    else if (Expr is CompareOperation) then 
    begin
      var SCompareOp := new SCompareOperation;
      SCompareOp.Operands := Operands;
      SCompareOp.Action := (Expr as CompareOperation).Action;
      SCompareOp._Type := typeof(boolean);
      Result := SCompareOp;
    end
    else if (Expr is LogicalOperation) then 
    begin
      var SLogicalOp := new SLogicalOperation;
      SLogicalOp.Operands := Operands;
      SLogicalOp.Action := (Expr as LogicalOperation).Action;
      SLogicalOp._Type := typeof(boolean);
      Result := SLogicalOp;
    end
    else
    begin
      if (Expr as ExpressionsNode).Nodes.Count = 1 then
        Result := ConvertExpressionNode((Expr as ExpressionsNode).Nodes[0])
      else raise new SemanticException('Ошибка конвертации деревьев ', Expr);
    end;
  end;
  
  if Result <> nil then
  begin
    Result.LocCopyFrom(Expr);
  end;
end;

function GConverter.ConvertTypeExpressionNode(TypeExpr: TypeExpression): STypeExpr;
begin
  if (TypeExpr is TypeExpressionRef) then
  begin
    if TypeList.ContainsKey((TypeExpr as TypeExpressionRef).TypeName.ToLower) 
      then result := TypeList[(TypeExpr as TypeExpressionRef).TypeName.ToLower]
    else
    begin
      result := GetType((TypeExpr as TypeExpressionRef).TypeName.ToLower); 
      if result = nil then 
        raise new SemanticException('не cуществует такого типа ' + (TypeExpr as TypeExpressionRef).TypeName, TypeExpr)
    end;  
  end
  
  else if (TypeExpr is TypeExprArray) then
  begin
    result := ConvertTypeExpressionNode((TypeExpr as TypeExprArray).OfType).MakeArrayType;
  end
  else raise new SemanticException('не могу узнать тип типового выражения ' + TypeExpr.GetType.ToString, TypeExpr);
  //if Result <> nil then Result.LocCopyFrom(TypeExpr);
end;




procedure GConverter.LoadAssembly(Name: string; Loc: Location);
  
  function SafelyAssemblyLoad(path: string): Assembly;
  begin
    var Stream := &File.OpenRead(path);
    var Buffer := new byte[Stream.Length];
    Stream.Read(buffer, 0, Stream.Length);
    Stream.Close();
    Result := Assembly.Load(Buffer);
    Buffer := nil;
    GC.Collect;
  end;

begin
  var _AssemblySearchPath := new List<string>;
  var t := Milliseconds;
  
  _AssemblySearchPath.Add(Path.GetFullPath(System.Reflection.Assembly.GetEntryAssembly().ManifestModule.FullyQualifiedName));
  _AssemblySearchPath.Add(Environment.CurrentDirectory);
  _AssemblySearchPath.Add(Path.GetDirectoryName(loc.FileName));
  _AssemblySearchPath.Add(GetStandartAssemblyPath);
  
  foreach s: string in _AssemblySearchPath do
  begin
    var fname := Path.Combine(s, Name);
    if &File.Exists(fname) then
    begin
      foreach a: Assembly in Assemblies do
        if a.ManifestModule.FullyQualifiedName = Path.GetFullPath(fname) then exit; // повторно не загружаем 
      
      var _Assembly := SafelyAssemblyLoad(Path.Combine(s, Name));
      
      foreach a: Assembly in Assemblies do
        if a.FullName = _Assembly.FullName then exit; // не обрабатываем повторно ту же сборку только из другово места
      
      if not Assemblies.Contains(_Assembly) then // повторно не загружаем одну и туже сборку
      begin
        Assemblies.Add(_Assembly);
        InitNameSpaces(_Assembly);
        OutputProc( new MessageInfo(string.Format('Чтение {0}...', _Assembly.ManifestModule.Name) + string.Format(' выполнено за {1} мс', _Assembly.ManifestModule.Name, Milliseconds - t)));
      end;
      exit;
    end;
  end;
  
  raise new SemanticException(string.Format('Не найдена сборка {0}', Name), Loc);
end;

procedure GConverter.InitNamespaces(_Assembly: Assembly);
begin
  var _Types := _Assembly.GetTypes;
  
  foreach t: &Type in _Types do
  begin
    if (t.IsVisible) and (t.IsPublic) then
    begin
      Types.Add(t.Namespace.ToLower + '.' + t.Name.ToLower, t);
      if not namespaces.Contains(t.Namespace.ToLower) then 
        namespaces.Add(t.Namespace.ToLower);
    end;
  end;
end;

function GConverter.GetStandartAssemblyPath: string;
begin
  Result := Path.GetDirectoryName(Assembly.GetAssembly(typeof(object)).ManifestModule.FullyQualifiedName);
end;

procedure GConverter.Optimize;
begin
  
end;

function GConverter.ConvertExpressionNode(Expr: ExpressionNode; ExpectedType: STypeExpr): SExprNode;
begin
  Result := ConvertExpressionNode(Expr);
  if not (result._Type = ExpectedType) then 
    raise new SemanticException(Format('ожидался тип {0}, а встречен {1}', ExpectedType.ToString, result._Type), result);
end;






end.