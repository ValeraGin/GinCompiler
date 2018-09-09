unit SettingsFormUnit;

{$reference 'System.Windows.Forms.dll'}
{$reference 'System.Drawing.dll'}

{$resource 'resources\settings.png'}

{$resource 'resources\options_main.png'}
{$resource 'resources\options_editor.png'}
{$resource 'resources\options_compiler.png'}
{$resource 'resources\options_intellisense.png'}

uses
  System,
  System.Drawing,
  System.Collections,
  System.ComponentModel,
  System.Windows.Forms,
  
  CommonUnit;

type
  SettingsForm = class(Form)
  private 
    MainStripButton, CompilerStripButton, IntellisenseStripButton, EditorStripButton: ToolStripButton;
    ToolStripTab: ToolStrip;
    OKButton, CancelButton: Button;
    Tab: TabControl;
    MainTab, CompileTab, IntellisenseTab, EditorTab: TabPage;
    GenDebugInfo, Optimize: CheckBox;
    
    
    procedure OnVisibleChange(sender: object; args: System.EventArgs);
    begin
      if self.Visible then 
      begin
        GenDebugInfo.Checked := Options.Debug;
      end;
    end;
    
    procedure OKButton_Click(sender: object; args: System.EventArgs);
    begin
      Options.Debug := GenDebugInfo.Checked;
      Options.Optimize := Optimize.Checked;
      Close;
    end;
    
    procedure CancelButton_Click(sender: object; args: System.EventArgs);
    begin
      Close;
    end;
    
    procedure ToolStripButton_Click(sender: object; args: System.EventArgs);
    begin
      Tab.SelectedTab := ((sender as ToolStripButton).Tag as TabPage);
      foreach b: ToolStripButton in ToolStripTab.Items do 
        b.Checked := (b = sender);
    end;
    
    procedure InitControls;
  public 
    constructor Create;
    begin
      InitControls;
    end;
  end;

procedure SettingsForm.InitControls;
begin
  var g := Bitmap.FromStream(GetResourceStream('settings.png')) as Bitmap;
  Icon := System.Drawing.Icon.FromHandle(g.GetHicon);
  
  self.VisibleChanged += OnVisibleChange; 
  
  Size := new System.Drawing.Size(331, 350);
  FormBorderStyle := System.Windows.Forms.FormBorderStyle.FixedSingle;
  MaximizeBox := False;
  MinimizeBox := False;
  Text := 'Настройки';
  
  Tab := new TabControl;
  Tab.Dock := DockStyle.Fill;
  Tab.Appearance := TabAppearance.FlatButtons;
  Tab.ItemSize := new System.Drawing.Size(0, 1);
  Tab.SizeMode := TabSizeMode.Fixed;
  
  MainTab := new TabPage;
  Tab.TabPages.Add(MainTab);
  
  CompileTab := new TabPage;
  
  GenDebugInfo := new CheckBox;
  GenDebugInfo.Checked :=  Options.Debug;
  GenDebugInfo.AutoSize := True;
  GenDebugInfo.Text := 'Генерировать отладочную информацию';
  GenDebugInfo.Location := new Point(10, 10);
  CompileTab.Controls.Add(GenDebugInfo);
  
  Optimize := new CheckBox;
  Optimize.Checked :=  Options.Optimize;
  Optimize.AutoSize := True;
  Optimize.Text := 'Оптимизация';
  Optimize.Location := new Point(10, 35);
  CompileTab.Controls.Add(Optimize);
  
  Tab.TabPages.Add(CompileTab);
  
  
  IntellisenseTab := new TabPage;
  Tab.TabPages.Add(IntellisenseTab);
  
  EditorTab := new TabPage;
  Tab.TabPages.Add(EditorTab);
  
  self.Controls.Add(Tab);
  
  ToolStripTab := new ToolStrip;
  ToolStripTab.Height := 44;
  ToolStripTab.GripStyle := ToolStripGripStyle.Hidden;
  ToolStripTab.BackColor := System.Drawing.Color.FromKnownColor(KnownColor.Window);
  
  MainStripButton := new ToolStripButton;
  MainStripButton.Click += ToolStripButton_Click;
  MainStripButton.Tag := self.MainTab;
  MainStripButton.Padding.Left := 10;
  MainStripButton.Checked := True;
  MainStripButton.AutoSize := True;
  MainStripButton.ImageScaling := ToolStripItemImageScaling.None;
  MainStripButton.TextImageRelation := TextImageRelation.ImageAboveText;
  MainStripButton.Text := ' Основное ';
  MainStripButton.Image := Image.FromStream(GetResourceStream('options_main.png'));
  ToolStripTab.Items.Add(MainStripButton);
  
  CompilerStripButton := new ToolStripButton;
  CompilerStripButton.Click += ToolStripButton_Click;
  CompilerStripButton.Tag := self.CompileTab;
  CompilerStripButton.Padding.Left := 10;
  CompilerStripButton.AutoSize := True;
  CompilerStripButton.ImageScaling := ToolStripItemImageScaling.None;
  CompilerStripButton.TextImageRelation := TextImageRelation.ImageAboveText;
  CompilerStripButton.Text := ' Компилятор ';
  CompilerStripButton.Image := Image.FromStream(GetResourceStream('options_compiler.png'));
  ToolStripTab.Items.Add(CompilerStripButton);
  
  EditorStripButton := new ToolStripButton;
  EditorStripButton.Click += ToolStripButton_Click;
  EditorStripButton.Tag := self.EditorTab;
  EditorStripButton.Padding.Left := 10;
  EditorStripButton.AutoSize := True;
  EditorStripButton.ImageScaling := ToolStripItemImageScaling.None;
  EditorStripButton.TextImageRelation := TextImageRelation.ImageAboveText;
  EditorStripButton.Text := ' Редактор ';
  EditorStripButton.Image := Image.FromStream(GetResourceStream('options_editor.png'));
  ToolStripTab.Items.Add(EditorStripButton);
  
  IntellisenseStripButton := new ToolStripButton;
  IntellisenseStripButton.Click += ToolStripButton_Click;
  IntellisenseStripButton.Tag := self.IntellisenseTab;
  IntellisenseStripButton.AutoSize := True;
  IntellisenseStripButton.ImageScaling := ToolStripItemImageScaling.None;
  IntellisenseStripButton.TextImageRelation := TextImageRelation.ImageAboveText;
  IntellisenseStripButton.Text := ' Подсказки по коду ';
  IntellisenseStripButton.Image := Image.FromStream(GetResourceStream('options_intellisense.png'));
  ToolStripTab.Items.Add(IntellisenseStripButton);
  
  self.Controls.Add(ToolStripTab);
  
  var ButtonPanel := new Panel;
  ButtonPanel.Height := 36;
  ButtonPanel.Dock := DockStyle.Bottom;
  
  OKButton := new Button;
  OKButton.Click += OKButton_Click;
  OKButton.Location := new Point(161, 6);
  OKButton.Text := 'OK';
  ButtonPanel.Controls.Add(OKButton);
  
  CancelButton := new Button;
  CancelButton.Click += CancelButton_Click;
  CancelButton.Location := new Point(244, 6);
  CancelButton.Text := 'Отмена';
  ButtonPanel.Controls.Add(CancelButton);
  
  self.Controls.Add(ButtonPanel);
  
  ToolStripButton_Click(CompilerStripButton, nil);
  
  OKButton.Select;
  
end;


begin
end. 