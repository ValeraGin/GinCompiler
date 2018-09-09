unit FindDialogUnit;

{$reference 'System.Windows.Forms.dll'}
{$reference 'System.Drawing.dll'}

uses
  System,
  System.Drawing,
  System.Collections,
  System.ComponentModel,
  System.Windows.Forms;

type
  OnFindEvent = procedure(FindText: string; MatchCase: boolean);

  FindDialog = class(Form)
  private 
    textBoxFindText: TextBox;
    buttonFind: Button;
    checkBoxMatchCase: CheckBox;
    buttonClose: Button;
    labelFindWhat: &Label;
    
    OnFind: OnFindEvent;
    
    procedure InitControls;
    begin
      self.labelFindWhat := new &Label();
      self.textBoxFindText := new TextBox;
      self.buttonFind := new Button;
      self.checkBoxMatchCase := new CheckBox;
      self.buttonClose := new Button;
      self.SuspendLayout;
      //
      // labelFindWhat
      //
      self.labelFindWhat.Location := new System.Drawing.Point(8, 8);
      self.labelFindWhat.AutoSize := true;
      self.labelFindWhat.TabIndex := 0;
      self.labelFindWhat.Text := 'Искать';
      self.labelFindWhat.TextAlign := ContentAlignment.MiddleLeft;
      //
      // textBoxFindText
      //
      self.textBoxFindText.Location := new Point(96, 8);
      self.textBoxFindText.Size := new System.Drawing.Size(280, 21);
      self.textBoxFindText.TabIndex := 1;
      self.textBoxFindText.Text := '';
      self.textBoxFindText.TextChanged += self.textBoxFindText_TextChanged;
      //
      // buttonFind
      //
      self.buttonFind.Location := new Point(408, 8);
      self.buttonFind.TabIndex := 2;
      self.buttonFind.Text := 'Искать';
      self.buttonFind.Click += self.buttonFind_Click;
      //
      // checkBoxMatchCase
      //
      self.checkBoxMatchCase.Location := new Point(96, 40);
      self.checkBoxMatchCase.AutoSize := true;
      self.checkBoxMatchCase.TabIndex := 3;
      self.checkBoxMatchCase.Text := 'Учитывать регистр';
      //
      // buttonClose
      //
      self.buttonClose.Location := new Point(408, 40);
      self.buttonClose.TabIndex := 4;
      self.buttonClose.Text := 'Отмена';
      self.buttonClose.Click += self.buttonClose_Click;
      //
      // FindDialog
      //
      self.AutoScaleBaseSize := new System.Drawing.Size(6, 14);
      self.ClientSize := new System.Drawing.Size(496, 72);
      self.Controls.Add(self.buttonClose);
      self.Controls.Add(self.checkBoxMatchCase);
      self.Controls.Add(self.buttonFind);
      self.Controls.Add(self.textBoxFindText);
      self.Controls.Add(self.labelFindWhat);
      self.Font := new System.Drawing.Font('Verdana', 8.25, FontStyle.Regular, GraphicsUnit.Point, ((System.Byte)(0)));
      self.FormBorderStyle := System.Windows.Forms.FormBorderStyle.FixedToolWindow;
      self.KeyPreview := true;
      self.ShowInTaskbar := false;
      self.Text := 'Поиск';
      self.TopMost := true;
      self.KeyDown += self.FindDialog_KeyDown;
      self.Closing += self.FindDialog_Closing;
      self.ResumeLayout(false);
    end;
    
    function GetFindText: string;
    begin
      result := textBoxFindText.Text;
    end;
    
    procedure SetFindText(value: string);
    begin
      textBoxFindText.Text := value;
    end;
    
    function GetMatchCase: boolean;
    begin
      result := checkBoxMatchCase.Checked;
    end;
    
    procedure SetMatchCase(value: boolean);
    begin
      checkBoxMatchCase.Checked := value;
    end;
    
    procedure buttonFind_Click(sender: object; e: System.EventArgs);
    begin
      self.Cursor := Cursors.WaitCursor;
     
      self.OnFind(FindText, MatchCase);
      
      self.Cursor := Cursors.Default;
    end;
    
    procedure buttonClose_Click(sender: object; e: System.EventArgs);
    begin
      self.Close;
    end;
    
    procedure textBoxFindText_TextChanged(sender: object; e: System.EventArgs);
    begin
      if (self.textBoxFindText.Text.Equals(String.Empty)) then
      begin
        self.buttonFind.Enabled := false;
      end
      else
      begin
        self.buttonFind.Enabled := true;
      end;
    end;
    
    procedure FindDialog_KeyDown(sender: object; e: KeyEventArgs);
    begin
      if(e .KeyCode = Keys.Escape) then
      begin
        self.Close;
      end;
    end;
    
    procedure FindDialog_Closing(sender: object; e: CancelEventArgs);
    begin
      e.Cancel := True;
      Hide;
    end;

  public 
    property FindText: string read GetFindText write SetFindText;
    property MatchCase: boolean read GetMatchCase write SetMatchCase;
    constructor Create(OnFind: OnFindEvent);
    begin
      InitControls;
      self.OnFind:= OnFind;
    end;
  end;

begin
end. 