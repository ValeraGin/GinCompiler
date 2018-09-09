unit ReplaceDialogUnit;

{$reference 'System.Windows.Forms.dll'}
{$reference 'System.Drawing.dll'}

uses
  System,
  System.Drawing,
  System.Collections,
  System.ComponentModel,
  System.Windows.Forms;

type
  OnReplaceEvent = procedure(FindText, ReplaceText: string; MatchCase, ReplaceAll: boolean);
  
  ReplaceDialog = class(Form)
  private 
    textBoxFindText: TextBox;
    checkBoxMatchCase: CheckBox;
    buttonClose: Button;
    textBoxReplaceText: TextBox;
    labelReplaceWith: &Label;
    buttonReplace: Button;
    buttonReplaceAll: Button;
    labelFindWhat: &Label;
    
    OnReplace: OnReplaceEvent;
    
    
    function GetFindText: string;
    begin
      result := textBoxFindText.Text;
    end;
    
    procedure SetFindText(value: string);
    begin
      textBoxFindText.Text := value;
    end;
    
    function GetReplaceText: string;
    begin
      result := textBoxReplaceText.Text;
    end;
    
    procedure SetReplaceText(value: string);
    begin
      textBoxReplaceText.Text := value;
    end;
    
    function GetMatchCase: boolean;
    begin
      result := checkBoxMatchCase.Checked;
    end;
    
    procedure SetMatchCase(value: boolean);
    begin
      checkBoxMatchCase.Checked := value;
    end;
    
    procedure buttonReplace_Click(sender: object; e: System.EventArgs);
    begin
      self.Cursor := Cursors.WaitCursor;
      self.OnReplace(self.FindText, self.ReplaceText, self.MatchCase, false);
      self.Cursor := Cursors.Default;
    end;
    
    procedure buttonReplaceAll_Click(sender: object; e: System.EventArgs);
    begin
      self.Cursor := Cursors.WaitCursor;
      self.OnReplace(self.FindText, self.ReplaceText, self.MatchCase, true);
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
        self.buttonReplace.Enabled := false;
        self.buttonReplaceAll.Enabled := false;
      end
      else
      begin
        self.buttonReplace.Enabled := true;
        self.buttonReplaceAll.Enabled := true;
      end;
    end;
    
    procedure textBoxReplaceText_TextChanged(sender: object; e: System.EventArgs);
    begin
    end;
    
    procedure ReplaceDialog_KeyDown(sender: object; e: KeyEventArgs);
    begin
      if(e .KeyCode = Keys.Escape) then
      begin
        self.Close;
      end;
    end;
     
    procedure ReplaceDialog_Closing(sender: object; e: CancelEventArgs);
    begin
      e.Cancel := True;
      Hide;
    end;
    
    procedure InitControls;
    begin
      self.labelFindWhat := new System.Windows.Forms.Label();
      self.textBoxFindText := new System.Windows.Forms.TextBox();
      self.buttonReplace := new System.Windows.Forms.Button();
      self.checkBoxMatchCase := new System.Windows.Forms.CheckBox();
      self.buttonClose := new System.Windows.Forms.Button();
      self.textBoxReplaceText := new System.Windows.Forms.TextBox();
      self.labelReplaceWith := new System.Windows.Forms.Label();
      self.buttonReplaceAll := new System.Windows.Forms.Button();
      self.SuspendLayout();
      //
      // labelFindWhat
      //
      self.labelFindWhat.Location := new System.Drawing.Point(8, 8);
      self.labelFindWhat.AutoSize := true;
      self.labelFindWhat.TabIndex := 0;
      self.labelFindWhat.Text := 'Искать';
      self.labelFindWhat.TextAlign := System.Drawing.ContentAlignment.MiddleLeft;
      //
      // textBoxFindText
      //
      self.textBoxFindText.Location := new System.Drawing.Point(96, 8);
      self.textBoxFindText.Size := new System.Drawing.Size(280, 21);
      self.textBoxFindText.TabIndex := 1;
      self.textBoxFindText.Text := '';
      self.textBoxFindText.TextChanged += self.textBoxFindText_TextChanged;
      //
      // buttonReplace
      //
      self.buttonReplace.Location := new System.Drawing.Point(408, 8);
      self.buttonReplace.Size := new System.Drawing.Size(100, 23);
      self.buttonReplace.TabIndex := 2;
      self.buttonReplace.Text := 'Заменить';
      self.buttonReplace.Click += self.buttonReplace_Click;
      //
      // checkBoxMatchCase
      //
      self.checkBoxMatchCase.Location := new System.Drawing.Point(96, 72);
      self.checkBoxMatchCase.AutoSize := true;
      self.checkBoxMatchCase.TabIndex := 6;
      self.checkBoxMatchCase.Text := 'Учитывать регистр';
      //
      // buttonClose
      //
      self.buttonClose.Location := new System.Drawing.Point(408, 72);
      self.buttonClose.Size := new System.Drawing.Size(100, 23);
      self.buttonClose.TabIndex := 7;
      self.buttonClose.Text := 'Отмена';
      self.buttonClose.Click += self.buttonClose_Click;
      //
      // textBoxReplaceText
      //
      self.textBoxReplaceText.Location := new System.Drawing.Point(96, 40);
      self.textBoxReplaceText.Size := new System.Drawing.Size(280, 21);
      self.textBoxReplaceText.TabIndex := 4;
      self.textBoxReplaceText.Text := '';
      self.textBoxReplaceText.TextChanged += self.textBoxReplaceText_TextChanged;
      //
      // labelReplaceWith
      //
      self.labelReplaceWith.Location := new System.Drawing.Point(8, 40);
      self.labelReplaceWith.AutoSize := true;
      self.labelReplaceWith.TabIndex := 3;
      self.labelReplaceWith.Text := 'Заменить на';
      self.labelReplaceWith.TextAlign := System.Drawing.ContentAlignment.MiddleLeft;
      //
      // buttonReplaceAll
      //
      self.buttonReplaceAll.Location := new System.Drawing.Point(408, 40);
      self.buttonReplaceAll.Size := new System.Drawing.Size(100, 23);
      self.buttonReplaceAll.TabIndex := 5;
      self.buttonReplaceAll.Text := 'Заменить все';
      self.buttonReplaceAll.Click += self.buttonReplaceAll_Click;
      //
      // ReplaceDialog
      //
      self.AutoScaleBaseSize := new System.Drawing.Size(6, 14);
      self.ClientSize := new System.Drawing.Size(521, 104);
      self.Controls.Add(self.buttonReplaceAll);
      self.Controls.Add(self.textBoxReplaceText);
      self.Controls.Add(self.textBoxFindText);
      self.Controls.Add(self.labelReplaceWith);
      self.Controls.Add(self.buttonClose);
      self.Controls.Add(self.checkBoxMatchCase);
      self.Controls.Add(self.buttonReplace);
      self.Controls.Add(self.labelFindWhat);
      self.Font := new System.Drawing.Font('Verdana', 8.25, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((System.Byte)(0)));
      self.FormBorderStyle := System.Windows.Forms.FormBorderStyle.FixedToolWindow;
      self.KeyPreview := true;
      self.ShowInTaskbar := false;
      self.Text := 'Замена';
      self.TopMost := true;
      self.KeyDown += self.ReplaceDialog_KeyDown;
      self.Closing += self.ReplaceDialog_Closing;
      self.ResumeLayout(false);
    end;
  
  public 
    property FindText: string read GetFindText write SetFindText;
    property ReplaceText: string read GetReplaceText write SetReplaceText;
    property MatchCase: boolean read GetMatchCase write SetMatchCase;
    constructor Create(OnReplace: OnReplaceEvent);
    begin
      InitControls;
      self.OnReplace := OnReplace;
    end;
  end;

begin
end. 