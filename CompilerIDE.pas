unit CompilerIDE;

{$reference 'ICSharpCode.TextEditor.dll'}
{$reference 'System.Windows.Forms.dll'}
{$reference 'System.Drawing.dll'}

// Иконки для меню;
{$resource 'resources\new.png'}
{$resource 'resources\open.png'} 
{$resource 'resources\save.png'}
{$resource 'resources\recent.png'}
{$resource 'resources\exit.png'}

{$resource 'resources\bootom_panel.png'}

{$resource 'resources\undo.png'}
{$resource 'resources\redo.png'}

{$resource 'resources\settings.png'}

{$resource 'resources\start.png'}
{$resource 'resources\stop.png'}
{$resource 'resources\compile.png'}

(*{$hhresource 'resources\cut.png' }*)
{$resource 'resources\copy.png'}
{$resource 'resources\paste.png'}

{$resource 'resources\find.png'}
{$resource 'resources\find_next.png'}
{$resource 'resources\replace.png'}
{$resource 'resources\go_to_line.png'}

{$resource 'resources\help.png'}
{$resource 'resources\examples.png'}
{$resource 'resources\example.png'}
{$resource 'resources\about.png'}


uses
  PABCSystem, 
  
  System,
  System.IO,
  System.Diagnostics,
  System.Drawing,
  System.Windows.Forms,
  ICSharpCode.TextEditor,
  ICSharpCode.TextEditor.Document,
  Microsoft.Win32,
  
  
  SettingsFormUnit,
  AboutFormUnit,
  
  FindDialogUnit, 
  ReplaceDialogUnit,
  GoToLineDialogUnit,
  
  CompilerUnit,
  
  CommonUnit;

const
  /// Имя программмы для заголовка формы
  MyAppName = 'Simple GinCompiler IDE';
  /// Расширения
  TextFileExt = '*.pas';  
  /// Фильтр для диалогов Open и Save
  TextFileFilter = 'GinPascal программы (' + TextFileExt + ')|' + TextFileExt;  

type
  Debug = class
  private 
    inputStream: StreamWriter;
    outputStream: StreamReader;
    programFileName: string;
    procedure OnReceiveOutputMessage(sender: object; args: System.Diagnostics.DataReceivedEventArgs);
    begin
    end;
  
  public 
    programProcess := new Process;
    constructor Create(ProgramFileName: string);
    begin
      self.programFileName := ProgramFileName;
    end;
    
    function Run: boolean;
    begin
      Result := False;
      programProcess.StartInfo.FileName := programFileName;
      programProcess.StartInfo.UseShellExecute := false;
      programProcess.StartInfo.CreateNoWindow := true;
      programProcess.StartInfo.RedirectStandardOutput := true;
      programProcess.StartInfo.RedirectStandardInput := true;
      
      //ProgramProcess.StartInfo.StandardOutputEncoding := System.Text.Encoding.Default;
      programProcess.StartInfo.StandardOutputEncoding := System.Text.Encoding.GetEncoding(866);
      
      programProcess.OutputDataReceived += self.OnReceiveOutputMessage;
      
      if FileExists(programFileName) then
      begin
        Result := programProcess.Start;
        programProcess.BeginOutputReadLine();
      end;
    end;
    
    function Kill: boolean;
    begin
      Result := False;
      if not programProcess.HasExited then 
        programProcess.Kill;
      Result := True;
    end;
  end;
  
  
  
  RecentOpenFile = procedure(fname: string);
  RecentMenu = class(ToolStripMenuItem)
  private 
    const RecentFilesKey = 'RecentFiles';
    /// На сколько сжимать пункты меню в Меню "История"
    const RecentMenuLength = 50;
    /// Имя файлов для меню "История" в реестре
    const FilesName = 'OpenFile_№'; 
    
    RegAppName: string;
    OpenProc: RecentOpenFile;
    
    procedure Click(sender: object; args: System.EventArgs);
    begin
      OpenProc(string((sender as ToolStripItem).Tag));
    end;
  
  public 
    RecentFiles: System.Collections.Specialized.StringCollection;
  
    procedure Save;
    begin
      Registry.CurrentUser.DeleteSubKey('Software\' + RegAppName + '\' + RecentFilesKey, false);
      var RegKey := Registry.CurrentUser.CreateSubKey('Software\' + RegAppName + '\' + RecentFilesKey);
      for var i := 0 to RecentFiles.Count - 1 do
        RegKey.SetValue(FilesName + IntToStr(i), RecentFiles[i]);
    end;
    
    procedure AddFile(fname: string);
    begin
      if not RecentFiles.Contains(fname) then 
      begin
        var m: ToolStripMenuItem;
        if length(fname) <= RecentMenuLength then 
          m := new ToolStripMenuItem(fname, nil, Click )
        else
          m := new ToolStripMenuItem('...' + Copy(fname, length(fname) - RecentMenuLength, length(fname)), nil, Click);
        m.Tag := fname;
        DropDownItems.Insert(0, m);
        RecentFiles.Insert(0, fname);
      end
      else
      begin
        DropDownItems.Insert(0, DropDownItems[RecentFiles.IndexOf(fname)]);
        RecentFiles.Remove(fname);
        RecentFiles.Insert(0, fname);
      end;
    end;
    
    constructor Create(MenuName, RegAppName: string; OpenProc: RecentOpenFile);
    begin
      inherited Create('История', nil, nil);
      self.RegAppName := RegAppName;
      RecentFiles := new System.Collections.Specialized.StringCollection;
      self.OpenProc := OpenProc;
      var RegKey := Registry.CurrentUser.OpenSubKey('Software\' + RegAppName + '\' + RecentFilesKey, true);
      if RegKey <> nil then 
      begin
        var NameList := RegKey.GetValueNames;
        for var i := NameList.Length - 1 downto 0 do
        begin
          var s := string(RegKey.GetValue(NameList[i]));
          AddFile(s);
        end;       
      end;
    end;
  end;
  
  
  
  
  EditorForm = class(Form)
  private 
    settingsFrm: SettingsForm;
    aboutFrm: AboutForm;
    editor: TextEditorControl;
    editorFormStatusBar: StatusBar;
    editorFormMainMenu: ToolStrip;
    toolBar: ToolStrip;
    errorList, compilerOutputList: ListBox;
    bottomPanelSplitter: Splitter;
    
    findDlg: FindDialog;
    findMatch: System.Text.RegularExpressions.Match;
    
    replaceDlg: ReplaceDialog;
    goToLineDlg: GoToLineDialog;
    
    outputList: TextBox;
    statePanel, RowPanel, ColumnPanel: StatusBarPanel;
    
    miFile, miEdit, miView, miProgram, miOptions, miHelp,
    
    miOpen, miSave, miSaveAs, miClose,
    
    miBottomPanel,
    
    miUndo, miRedo, miCut, miCopy, miPaste, miFind, miFindNext, miReplace, miGoToLine,
    
    miStart, miStop, miCompile,
    miSettings,
    miHelpFile, miExamples, miAbout: ToolStripMenuItem;
    
    
    openButton, saveButton,
    cutButton, copyButton, pasteButton,
    undoButton, redoButton,
    startButton, stopButton, compileButton: ToolStripButton;
    
    miRecentMenu: RecentMenu;
    
    debuger: Debug;
    
    outputControlTab: TabControl;
    inputPanel: Panel;
    input: TextBox;
    inputEnterBtn: Button;
    
    programOutputTab, errorOutputTab, compilerOutputTab: TabPage;
    
    addStringStr: string;
    procedure AddStringInvoke;
    procedure OnProcessExit;
    
    procedure WriteCompilerMessage(Message: MessageInfo);
    
    function Compile: boolean;
    function Start: boolean;
    function Stop: boolean;
    
    procedure OnFind(FindText: string; MatchCase: boolean);
    procedure OnReplace(FindText, ReplaceText: string; MatchCase, ReplaceAll: boolean);
    
    procedure OnReceiveOutputMessage(sender: object; args: System.Diagnostics.DataReceivedEventArgs);
    procedure OnProcessExit(sender: object; args: System.EventArgs);
    
    procedure Undo_Click(sender: object; args: System.EventArgs);
    procedure Redo_Click(sender: object; args: System.EventArgs);
    procedure Cut_Click(sender: object; args: System.EventArgs);
    procedure Copy_Click(sender: object; args: System.EventArgs);
    procedure Paste_Click(sender: object; args: System.EventArgs);
    procedure Find_Click(sender: object; args: System.EventArgs);
    procedure FindNext_Click(sender: object; args: System.EventArgs);
    procedure Replace_Click(sender: object; args: System.EventArgs);
    procedure GoToLine_Click(sender: object; args: System.EventArgs);
    procedure BottomPanelVisible_Click(sender: object; args: System.EventArgs);
    procedure Start_Click(sender: object; args: System.EventArgs);
    procedure Stop_Click(sender: object; args: System.EventArgs);
    procedure Compile_Click(sender: object; args: System.EventArgs);
    procedure OpenFile_Click(sender: object; args: System.EventArgs);
    procedure SaveFile_Click(sender: object; args: System.EventArgs);
    procedure SaveAsFile_Click(sender: object; args: System.EventArgs);
    procedure Close_Click(sender: object; args: System.EventArgs);
    procedure Examples_Click(sender: object; args: System.EventArgs);
    procedure Settings_Click(sender: object; args: System.EventArgs);
    procedure About_Click(sender: object; args: System.EventArgs);
    procedure EditorPositionChanged(sender: object; args: System.EventArgs);
    procedure InputEnterBtn_Click(sender: object; args: System.EventArgs);
    procedure Closing(sender: object; args: System.ComponentModel.CancelEventArgs);
    
    procedure SaveParameters;
    procedure LoadParameters;
    
    procedure InitControls;
  public 
    constructor Create;
    procedure SaveFile(FileName: string);
    procedure OpenFile(FileName: string);
    procedure AddString(s: string);
  end;

procedure EditorForm.SaveParameters;
begin
 miRecentMenu.Save;

 var key:=Registry.CurrentUser.CreateSubKey('Software\'+'GinCompiler');
 key.SetValue('FormRect',self.Bounds); 
 key.SetValue('Left',IntToStr(Left));
 key.SetValue('Top',IntToStr(Top)); 
 key.SetValue('Width',IntToStr(Width));
 key.SetValue('Height',IntToStr(Height));
end;

procedure EditorForm.LoadParameters;
begin
 var key:=Registry.CurrentUser.OpenSubKey('Software\'+'GinCompiler');
 If key=nil then exit;
 Left:=StrToInt(key.GetValue('Left').ToString);
 Top:=StrToInt(key.GetValue('Top').ToString);
 Width:=StrToInt(key.GetValue('Width').ToString);
 Height:=StrToInt(key.GetValue('Height').ToString);
end;



procedure EditorForm.Find_Click(sender: object; args: System.EventArgs);
begin
  findDlg.ShowDialog(self);
end;


procedure EditorForm.Replace_Click(sender: object; args: System.EventArgs);
begin
  replaceDlg.Show;
end;

procedure EditorForm.OnFind(FindText: string; MatchCase: boolean);
begin
  var offset := editor.ActiveTextAreaControl.TextArea.Caret.Offset;
  var regexOptions := System.Text.RegularExpressions.RegexOptions.None;
  if not MatchCase then 
    regexOptions := System.Text.RegularExpressions.RegexOptions.IgnoreCase;
  var regex := new System.Text.RegularExpressions.Regex(FindText, regexOptions);  
  var mat := regex.Match(editor.Document.TextContent, offset);
  if mat.Success then 
  begin
    findMatch := mat;
    var loc := editor.Document.OffsetToPosition(mat.Index);
    editor.ActiveTextAreaControl.SelectionManager.ClearSelection;
    editor.ActiveTextAreaControl.Caret.Position := new ICSharpCode.TextEditor.TextLocation(loc.x, loc.y);
    editor.ActiveTextAreaControl.SelectionManager.SetSelection(new TextLocation(loc.x, loc.y), new TextLocation(loc.x + mat.Length, loc.y));
  end;
end;

procedure EditorForm.FindNext_Click(sender: object; args: System.EventArgs);
begin
  findMatch := findMatch.NextMatch;
  if findMatch.Success then 
  begin
    var loc := editor.Document.OffsetToPosition(findMatch.Index);
    editor.ActiveTextAreaControl.SelectionManager.ClearSelection;
    editor.ActiveTextAreaControl.Caret.Position := new ICSharpCode.TextEditor.TextLocation(loc.x, loc.y);
    editor.ActiveTextAreaControl.SelectionManager.SetSelection(new TextLocation(loc.x, loc.y), new TextLocation(loc.x + findMatch.Length, loc.y))
  end;
end;

procedure EditorForm.OnReplace(FindText, ReplaceText: string; MatchCase, ReplaceAll: boolean);
begin
  var regexOptions := System.Text.RegularExpressions.RegexOptions.None;
  if not MatchCase then 
    regexOptions := System.Text.RegularExpressions.RegexOptions.IgnoreCase;
  var mat: System.Text.RegularExpressions.Match;
  repeat
    var offset := editor.ActiveTextAreaControl.TextArea.Caret.Offset;
    var regex := new System.Text.RegularExpressions.Regex(FindText, regexOptions);  
    mat := regex.Match(editor.Document.TextContent, offset);
    if mat.Success then 
    begin
      var loc := editor.Document.OffsetToPosition(mat.Index);
      editor.ActiveTextAreaControl.SelectionManager.ClearSelection;
      editor.ActiveTextAreaControl.Caret.Position := new ICSharpCode.TextEditor.TextLocation(loc.x, loc.y);
      editor.Document.Remove(mat.Index, mat.Length);
      editor.Document.Insert(mat.Index, ReplaceText);
      editor.ActiveTextAreaControl.SelectionManager.SetSelection(new TextLocation(loc.x, loc.y), new TextLocation(loc.x + ReplaceText.Length, loc.y));
    end;
  until not (mat.Success and ReplaceAll);
end;


procedure EditorForm.AddStringInvoke;
begin
  outputControlTab.SelectTab(self.programOutputTab);
  outputList.Text := outputList.Text + addStringStr + System.Environment.NewLine;
end;

procedure EditorForm.AddString(s: string);
begin
  addStringStr := s;
  self.Invoke(AddStringInvoke);
end;

procedure EditorForm.OnReceiveOutputMessage(sender: object; args: System.Diagnostics.DataReceivedEventArgs);
begin
  if args.Data <> nil then 
  begin
    AddString(args.Data);
  end;
end;


procedure EditorForm.OnProcessExit;
begin
  self.stopButton.Enabled := False;
  self.miStop.Enabled := False;
end;


procedure EditorForm.OnProcessExit(sender: object; args: System.EventArgs);
begin
  self.Invoke(OnProcessExit);
end;


function EditorForm.Start: boolean;
begin
  Result := False;
  if compile then
  begin
    if (Path.GetExtension(options.OutFile) = '.dll') then
    begin
      MessageBox.Show('Нельзя запускать библиотеки', 'Сообщение', MessageBoxButtons.OK, MessageBoxIcon.Information)
    end
    else
    begin
      self.outputList.Clear;
      self.errorList.Items.Clear;
      self.stopButton.Enabled := True;
      if (debuger <> nil) and (not debuger.programProcess.HasExited) then debuger.programProcess.Kill;
      debuger := new Debug(Path.GetFullPath(options.OutFile));
      debuger.programProcess.EnableRaisingEvents := true;
      debuger.programProcess.OutputDataReceived += self.OnReceiveOutputMessage;
      debuger.programProcess.Exited += self.OnProcessExit;
      Result := debuger.Run;
      if Result then self.miStop.Enabled := True;
    end; 
  end;
end;

function EditorForm.Stop: boolean;
begin
  if debuger <> nil then 
    Result := debuger.Kill;
  self.stopButton.Enabled := False;
  self.miStop.Enabled := False;
end;



function EditorForm.Compile: boolean;
begin
  self.compilerOutputList.Items.Clear;
  SaveFile_Click(nil, nil);
  
  Result := False;
  if editor.FileName = nil then 
  begin
    SaveAsFile_Click(nil, nil);
    if editor.FileName = nil then exit;
  end;
  
  var cmp := new Compiler;
  Options.SourceFile := editor.FileName;
  Options.OutFile := Path.ChangeExtension(editor.FileName, '.exe');
  Result := cmp.Compile(WriteCompilerMessage);
end;



procedure EditorForm.InputEnterBtn_Click(sender: object; args: System.EventArgs);
begin
  if debuger <> nil then
  begin
    debuger.programProcess.StandardInput.WriteLine(input.Text);
    input.Text := '';
  end;
end;

procedure EditorForm.WriteCompilerMessage(Message: MessageInfo);
begin
  if Message.MType = Info then 
    compilerOutputList.Items.Add(Message.Text)
  else if  Message.MType = Error then 
  begin
    errorList.Items.Add(Message.Text);
     {   Editor.ActiveTextAreaControl.SelectionManager.SetSelection(new ICSharpCode.TextEditor.TextLocation(1, 1), 
      new ICSharpCode.TextEditor.TextLocation(4, 2));}
    outputControlTab.SelectTab(errorOutputTab);
    
    writeln(Message.Loc.FileName);
    editor.ActiveTextAreaControl.SelectionManager.SetSelection(new ICSharpCode.TextEditor.TextLocation(Message.Loc.BeginColumn - 1, Message.Loc.BeginLine - 1), 
       new ICSharpCode.TextEditor.TextLocation(Message.Loc.EndColumn - 1, Message.Loc.EndLine - 1));
    editor.ActiveTextAreaControl.Caret.Position := new ICSharpCode.TextEditor.TextLocation(Message.Loc.BeginColumn - 1, Message.Loc.BeginLine - 1);
  end;
  
end;

procedure EditorForm.Undo_Click(sender: object; args: System.EventArgs);
begin
  var undo := new ICSharpCode.TextEditor.Actions.Undo;
  undo.Execute(editor.ActiveTextAreaControl.TextArea);
end;


procedure EditorForm.Redo_Click(sender: object; args: System.EventArgs);
begin
  var redo := new ICSharpCode.TextEditor.Actions.Redo;
  redo.Execute(editor.ActiveTextAreaControl.TextArea);
end;


procedure EditorForm.Cut_Click(sender: object; args: System.EventArgs);
begin
  var Cut := new ICSharpCode.TextEditor.Actions.Cut;
  Cut.Execute(editor.ActiveTextAreaControl.TextArea);
end;


procedure EditorForm.Copy_Click(sender: object; args: System.EventArgs);
begin
  var copy := new ICSharpCode.TextEditor.Actions.Copy;
  copy.Execute(editor.ActiveTextAreaControl.TextArea);
end;


procedure EditorForm.Paste_Click(sender: object; args: System.EventArgs);
begin
  var paste := new ICSharpCode.TextEditor.Actions.Paste;
  paste.Execute(editor.ActiveTextAreaControl.TextArea);
end;


procedure EditorForm.GoToLine_Click(sender: object; args: System.EventArgs);
begin
  goToLineDlg.LineCount := editor.Document.TotalNumberOfLines;
  goToLineDlg.Line := editor.ActiveTextAreaControl.Caret.Line + 1;
  if goToLineDlg.ShowDialog(self) = System.Windows.Forms.DialogResult.OK then 
    editor.ActiveTextAreaControl.Caret.Position := new ICSharpCode.TextEditor.TextLocation(0, goToLineDlg.Line - 1);
end;


procedure EditorForm.BottomPanelVisible_Click(sender: object; args: System.EventArgs);
begin
  self.bottomPanelSplitter.Visible := not self.outputControlTab.Visible;
  self.outputControlTab.Visible := not self.outputControlTab.Visible;
end;



procedure EditorForm.Start_Click(sender: object; args: System.EventArgs);
begin
  Start;
end;

procedure EditorForm.Stop_Click(sender: object; args: System.EventArgs);
begin
  Stop;
end;

procedure EditorForm.Compile_Click(sender: object; args: System.EventArgs);
begin
  Compile;
end;

procedure EditorForm.SaveFile(FileName: string);
begin
  editor.SaveFile(FileName);
  self.Text := Path.GetFileName(editor.FileName) + ' - ' + MyAppName;
end;

procedure EditorForm.OpenFile(FileName: string);
begin
  FileName := Path.GetFullPath(FileName);
  editor.LoadFile(FileName);
  self.Text := Path.GetFileName(editor.FileName) + ' - ' + MyAppName;
  miRecentMenu.AddFile(FileName);
end;

constructor EditorForm.Create;
begin
  self.Text := 'Simple GinCompiler IDE';
  self.Size := new System.Drawing.Size(640, 480);
  
  settingsFrm := new SettingsForm;
  aboutFrm := new AboutForm;
  
  findDlg := new FindDialog(self.OnFind);
  replaceDlg := new ReplaceDialog(self.OnReplace);
  goToLineDlg := new GoToLineDialog;
  
  InitControls;
end;

procedure EditorForm.OpenFile_Click(sender: object; args: System.EventArgs);
begin
  var openFD := new OpenFileDialog;
  openFD.DefaultExt := TextFileExt;
  openFD.Filter := TextFileFilter;
  if openFD.ShowDialog = System.Windows.Forms.DialogResult.OK then 
    OpenFile(openFD.FileName);
end;

procedure EditorForm.SaveFile_Click(sender: object; args: System.EventArgs);
begin
  if editor.FileName = nil then
    SaveAsFile_Click(nil, nil)
  else SaveFile(editor.FileName);
end;

procedure EditorForm.SaveAsFile_Click(sender: object; args: System.EventArgs);
begin
  var saveFD := new SaveFileDialog;
  saveFD.DefaultExt := TextFileExt;
  saveFD.Filter := TextFileFilter;
  if saveFD.ShowDialog = System.Windows.Forms.DialogResult.OK then 
    SaveFile(saveFD.FileName);
end;

procedure EditorForm.Close_Click(sender: object; args: System.EventArgs);
begin
  self.Close;
end;

procedure EditorForm.EditorPositionChanged(sender: object; args: System.EventArgs);
begin
  RowPanel.Text := 'Строка ' + (editor.ActiveTextAreaControl.Caret.Line + 1).ToString;
  ColumnPanel.Text := 'Столбец ' + (editor.ActiveTextAreaControl.Caret.Column + 1).ToString;
end;


procedure EditorForm.Examples_Click(sender: object; args: System.EventArgs);
begin
  var exampleFileName := Io.Path.GetFullPath((sender as ToolStripMenuItem).Tag.ToString);
  if IO.&File.Exists(exampleFileName) then 
    OpenFile(exampleFileName)
  else MessageBox.Show('Пример "' + exampleFileName + '" отсутствует');
end;

procedure EditorForm.Settings_Click(sender: object; args: System.EventArgs);
begin
  settingsFrm.ShowDialog(self);
end;

procedure EditorForm.About_Click(sender: object; args: System.EventArgs);
begin
  aboutFrm.ShowDialog(self);
end;

procedure EditorForm.Closing(sender: object; args: System.ComponentModel.CancelEventArgs);
begin
  SaveParameters;
end;

procedure EditorForm.InitControls;
begin
  self.Size := new System.Drawing.Size(483, 806);
  (self as Form).Closing += Closing;
  
  // TextEditor 
  editor := new TextEditorControl;
  editor.Dock := DockStyle.Fill;
  var fsmProvider := new FileSyntaxModeProvider(Environment.CurrentDirectory);
  HighlightingManager.Manager.AddSyntaxModeFileProvider(fsmProvider); 
  editor.SetHighlighting('PAS'); 
  editor.ActiveTextAreaControl.Caret.PositionChanged += EditorPositionChanged;
  self.Controls.Add(editor);
  
  outputControlTab := new TabControl;
  outputControlTab.MinimumSize := new System.Drawing.Size(400, 100);
  outputControlTab.Height := 150;
  outputControlTab.Dock := DockStyle.Bottom;
  
  
  errorOutputTab := new TabPage('Список ошибок');
  errorList := new ListBox;
  errorList.Dock := DockStyle.Fill;
  errorOutputTab.Controls.Add(errorList);
  outputControlTab.TabPages.Add(errorOutputTab);
  
  compilerOutputTab := new TabPage('Вывод компилятора');
  compilerOutputList := new ListBox;
  compilerOutputList.Dock := DockStyle.Fill;
  compilerOutputTab.Controls.Add(compilerOutputList);
  outputControlTab.TabPages.Add(compilerOutputTab);
  
  
  programOutputTab := new TabPage('Вывод программы');
  
  outputList := new TextBox;
  outputList.Multiline := true;
  outputList.Dock := DockStyle.Fill;
  programOutputTab.Controls.Add(outputList);
  
  inputPanel := new Panel;
  inputPanel.Height := 20;
  inputPanel.Dock := DockStyle.Top;
  
  input := new TextBox;
  input.Dock := DockStyle.Fill;
  inputPanel.Controls.Add(input);
  
  inputEnterBtn := new Button;
  inputEnterBtn.Text := 'Ввести';
  inputEnterBtn.Dock := DockStyle.Right;
  inputEnterBtn.Click += InputEnterBtn_Click;
  inputPanel.Controls.Add(inputEnterBtn);
  
  programOutputTab.Controls.Add(inputPanel);
  
  outputControlTab.TabPages.Add(programOutputTab);
  
  bottomPanelSplitter := new Splitter;
  bottomPanelSplitter.BackColor := Color.CadetBlue;
  bottomPanelSplitter.Dock := DockStyle.Bottom;
  self.Controls.Add(bottomPanelSplitter);
  
  self.Controls.Add(outputControlTab); 
  
  
  
  // StatusBar
  editorFormStatusBar := new StatusBar;
  editorFormStatusBar.ShowPanels := True;
  statePanel := new StatusBarPanel;
  statePanel.BorderStyle := StatusBarPanelBorderStyle.None;
  statePanel.AutoSize := StatusBarPanelAutoSize.Spring;
  editorFormStatusBar.Panels.Add(statePanel);
  
  RowPanel := new StatusBarPanel;
  RowPanel.BorderStyle := StatusBarPanelBorderStyle.None;
  RowPanel.AutoSize := StatusBarPanelAutoSize.Contents;
  editorFormStatusBar.Panels.Add(RowPanel);
  
  ColumnPanel := new StatusBarPanel;
  ColumnPanel.BorderStyle := StatusBarPanelBorderStyle.None;
  ColumnPanel.AutoSize := StatusBarPanelAutoSize.Contents;
  editorFormStatusBar.Panels.Add(ColumnPanel);
  self.Controls.Add(editorFormStatusBar);
  
  
  toolBar := new ToolStrip;
  toolBar.GripStyle := System.Windows.Forms.ToolStripGripStyle.Hidden;
  
  openButton := new ToolStripButton('', new System.Drawing.Bitmap(GetResourceStream('open.png')), OpenFile_Click);
  saveButton := new ToolStripButton('',  new System.Drawing.Bitmap(GetResourceStream('save.png')), SaveFile_Click);
  
  //cutButton := new ToolStripButton('',  new System.Drawing.Bitmap(GetResourceStream('cut.png')), Cut_Click);
  cutButton := new ToolStripButton('', nil, Cut_Click);
  
  copyButton := new ToolStripButton('',  new System.Drawing.Bitmap(GetResourceStream('copy.png')), Copy_Click);
  pasteButton := new ToolStripButton('',  new System.Drawing.Bitmap(GetResourceStream('paste.png')), Paste_Click);
  undoButton := new ToolStripButton('',  new System.Drawing.Bitmap(GetResourceStream('undo.png')), Undo_Click);
  redoButton := new ToolStripButton('',  new System.Drawing.Bitmap(GetResourceStream('redo.png')), Redo_Click);  
  startButton := new ToolStripButton('',  new System.Drawing.Bitmap(GetResourceStream('start.png')), Start_Click);
  stopButton := new ToolStripButton('',  new System.Drawing.Bitmap(GetResourceStream('stop.png')), Stop_Click);
  stopButton.Enabled := False;
  compileButton := new ToolStripButton('',  new System.Drawing.Bitmap(GetResourceStream('compile.png')), Compile_Click);
  
  toolBar.Items.AddRange(new ToolStripItem[13](
    OpenButton, SaveButton, new ToolStripSeparator,
    CutButton, CopyButton, PasteButton, new ToolStripSeparator,
    UndoButton, RedoButton, new ToolStripSeparator,
    StartButton, StopButton, CompileButton
  ));
  
  
  self.Controls.Add(toolBar);
  
  // MainMenu
  editorFormMainMenu := new MenuStrip;
  editorFormMainMenu.GripStyle := System.Windows.Forms.ToolStripGripStyle.Hidden;
  
  // Файл
  miFile := new ToolStripMenuItem('Файл'); 
  miOpen := new ToolStripMenuItem('Открыть', new System.Drawing.Bitmap(GetResourceStream('open.png')), OpenFile_Click, Keys.Control or Keys.O);
  miSave := new ToolStripMenuItem('Сохранить', new System.Drawing.Bitmap(GetResourceStream('save.png')), SaveFile_Click, Keys.Control or Keys.S);
  miSaveAs := new ToolStripMenuItem('Сохранить как...', nil, SaveAsFile_Click);
  
  miRecentMenu := new RecentMenu('История', 'GinCompiler', OpenFile);
  miRecentMenu.Image := new System.Drawing.Bitmap(GetResourceStream('recent.png'));
  // miRecentMenu.
  
  miClose := new ToolStripMenuItem('Выход', new System.Drawing.Bitmap(GetResourceStream('exit.png')), Close_Click);
  miFile.DropDownItems.AddRange(new ToolStripItem[7](
    miOpen, miSave, miSaveAs, new ToolStripSeparator,
    miRecentMenu, new ToolStripSeparator,
    miClose
    ));
  
  // Правка
  miEdit := new ToolStripMenuItem('Правка');  
  miUndo := new ToolStripMenuItem('Отменить', new System.Drawing.Bitmap(GetResourceStream('undo.png')), Undo_Click);
  miRedo := new ToolStripMenuItem('Повторить', new System.Drawing.Bitmap(GetResourceStream('redo.png')), Redo_Click);
  
 // miCut := new ToolStripMenuItem('Вырезать', new System.Drawing.Bitmap(GetResourceStream('cut.png')), Cut_Click);
  miCut := new ToolStripMenuItem('Вырезать', nil,  Cut_Click);
  
  miCopy := new ToolStripMenuItem('Копировать', new System.Drawing.Bitmap(GetResourceStream('copy.png')), Copy_Click);
  miPaste := new ToolStripMenuItem('Вставить', new System.Drawing.Bitmap(GetResourceStream('paste.png')), Paste_Click);
  miFind := new ToolStripMenuItem('Найти...', new System.Drawing.Bitmap(GetResourceStream('find.png')), Find_Click, Keys.Control or Keys.F);
  miFindNext := new ToolStripMenuItem('Найти далее', new System.Drawing.Bitmap(GetResourceStream('find_next.png')), FindNext_Click, Keys.Control or Keys.L);
  miReplace := new ToolStripMenuItem('Заменить...', new System.Drawing.Bitmap(GetResourceStream('replace.png')),  Replace_Click, Keys.Control or Keys.R);
  miGoToLine := new ToolStripMenuItem('Перейти к строке..', new System.Drawing.Bitmap(GetResourceStream('go_to_line.png')), GoToLine_Click, Keys.Control or Keys.G);
  miEdit.DropDownItems.AddRange(new ToolStripItem[11](
     miUndo, miRedo, new ToolStripSeparator, 
     miCut, miCopy, miPaste, new ToolStripSeparator, 
     miFind, miFindNext, miReplace, miGoToLine
    ));
  
  // Вид
  miView := new ToolStripMenuItem('Вид');
  miBottomPanel := new ToolStripMenuItem('Нижняя панель', new System.Drawing.Bitmap(GetResourceStream('bootom_panel.png')), BottomPanelVisible_Click, Keys.F5);
  miView.DropDownItems.AddRange(new ToolStripItem[1](
     miBottomPanel
    ));
  
  // Программа
  miProgram := new ToolStripMenuItem('Программа');
  miStart := new ToolStripMenuItem('Выполнить', new System.Drawing.Bitmap(GetResourceStream('start.png')), Start_Click, Keys.F9);
  miStop := new ToolStripMenuItem('Остановить', new System.Drawing.Bitmap(GetResourceStream('stop.png')), Stop_Click, Keys.Control or Keys.F2);
  miStop.Enabled := False;
  miCompile := new ToolStripMenuItem('Компилировать', new System.Drawing.Bitmap(GetResourceStream('compile.png')), self.Compile_Click,  Keys.Control or Keys.F9);
  miProgram.DropDownItems.AddRange(new ToolStripItem[4](
     miStart, miStop, new ToolStripSeparator, 
     miCompile
    ));
  
  // Сервис
  miOptions := new ToolStripMenuItem('Сервис');  
  miSettings := new ToolStripMenuItem('Настройки', new System.Drawing.Bitmap(GetResourceStream('settings.png')), Settings_Click); 
  miOptions.DropDownItems.AddRange(new ToolStripItem[1](
     miSettings
    ));
  
  // Справка 
  miHelp := new ToolStripMenuItem('Помощь');  
  miHelpFile := new ToolStripMenuItem('Справка', new System.Drawing.Bitmap(GetResourceStream('help.png')));
  miExamples := new ToolStripMenuItem('Примеры', new System.Drawing.Bitmap(GetResourceStream('examples.png')));
  miAbout := new ToolStripMenuItem('О программе', new System.Drawing.Bitmap(GetResourceStream('about.png')), About_Click);
  miHelp.DropDownItems.AddRange(new ToolStripItem[4](
     miHelpFile, miExamples, new ToolStripSeparator, 
     miAbout
     ));
  
  // Добавление примеров
  var files := Directory.GetFiles('Examples', '*.pas');
  foreach f: string in files do
  begin
    var item := new ToolStripMenuItem(IO.Path.GetFileName(f), new System.Drawing.Bitmap(GetResourceStream('example.png')), Examples_Click);
    Item.Tag := IO.Path.GetFullPath(f);
    miExamples.DropDownItems.Add(item);
  end;
  
  editorFormMainMenu.Items.AddRange(new ToolStripItem[6](
     miFile, miEdit, miView, miProgram, miOptions, miHelp
     ));
  
  self.Controls.Add(editorFormMainMenu);
  
  LoadParameters;
  
  // открываем то, что было открыто в прошлый раз.
  If miRecentMenu.RecentFiles.Count > 0 then OpenFile(miRecentMenu.RecentFiles[0]);
end;

begin
end. 