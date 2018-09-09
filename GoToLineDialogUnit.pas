unit GoToLineDialogUnit;

{$reference 'System.Windows.Forms.dll'}
{$reference 'System.Drawing.dll'}

uses
  System,
  System.Drawing,
  System.Collections,
  System.ComponentModel,
  System.Windows.Forms;

type
  GoToLineDialog = class(Form)
  private 
    buttonOk: Button;
    buttonCancel: Button;
    labelMessage: System.Windows.Forms.Label;
    numericUpDown: System.Windows.Forms.NumericUpDown;
    
    function GetLine: integer;
    begin
      result := integer(numericUpDown.Value);
    end;
    
    procedure SetLine(value: integer);
    begin
      numericUpDown.Value := value;
    end;
    
    procedure SetLineCount(value: integer);
    begin
      numericUpDown.Maximum := value;
      labelMessage.Text := Format('Номер строки (1 - {0}):', value);
    end;
    
    procedure buttonOk_Click(sender: object; e: System.EventArgs);
    begin
      self.DialogResult := System.Windows.Forms.DialogResult.OK;
      self.Close;
    end;
    
    procedure buttonCancel_Click(sender: object; e: System.EventArgs);
    begin
      self.DialogResult := System.Windows.Forms.DialogResult.Cancel;
      self.Close;
    end;
    
    procedure InitControls;
    begin
      self.buttonOk := new System.Windows.Forms.Button;
      self.buttonCancel := new System.Windows.Forms.Button;
      self.labelMessage := new System.Windows.Forms.Label;
      self.numericUpDown := new System.Windows.Forms.NumericUpDown;
      ((System.ComponentModel.ISupportInitialize)(self.numericUpDown)).BeginInit;
      self.SuspendLayout;
            //
            // buttonOk
            //
      self.buttonOk.Anchor := ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Bottom or System.Windows.Forms.AnchorStyles.Right)));
      self.buttonOk.Location := new System.Drawing.Point(105, 55);
      self.buttonOk.Size := new System.Drawing.Size(75, 23);
      self.buttonOk.TabIndex := 0;
      self.buttonOk.Text := 'OK';
      self.buttonOk.UseVisualStyleBackColor := true;
      self.buttonOk.Click += self.buttonOk_Click;
            //
            // buttonCancel
            //
      self.buttonCancel.Anchor := ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Bottom or System.Windows.Forms.AnchorStyles.Right)));
      self.buttonCancel.DialogResult := System.Windows.Forms.DialogResult.Cancel;
      self.buttonCancel.Location := new System.Drawing.Point(186, 55);
      self.buttonCancel.Size := new System.Drawing.Size(75, 23);
      self.buttonCancel.TabIndex := 1;
      self.buttonCancel.Text := 'Отмена';
      self.buttonCancel.UseVisualStyleBackColor := true;
      self.buttonCancel.Click += self.buttonCancel_Click;
            //
            // labelMessage
            //
      self.labelMessage.AutoSize := true;
      self.labelMessage.Location := new System.Drawing.Point(12, 9);
      self.labelMessage.Size := new System.Drawing.Size(111, 13);
      self.labelMessage.TabIndex := 2;
      self.labelMessage.Text := 'Номер строки (1 - max):';
            //
            // numericUpDown
            //
      self.numericUpDown.Anchor := ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top or System.Windows.Forms.AnchorStyles.Left)
                       or System.Windows.Forms.AnchorStyles.Right)));
      self.numericUpDown.Location := new System.Drawing.Point(15, 27);
      self.numericUpDown.Margin := new System.Windows.Forms.Padding(3, 5, 3, 5);
      self.numericUpDown.Maximum := Decimal.One;
      self.numericUpDown.Minimum := System.Decimal.One;
      self.numericUpDown.Size := new System.Drawing.Size(246, 20);
      self.numericUpDown.TabIndex := 3;
      self.numericUpDown.Value := Decimal.One;
            //
            // GoToLineDialog
            //
      self.AcceptButton := self.buttonOk;
      self.AutoScaleDimensions := new System.Drawing.SizeF(single(6), single(13));
      self.AutoScaleMode := System.Windows.Forms.AutoScaleMode.Font;
      self.CancelButton := self.buttonCancel;
      self.ClientSize := new System.Drawing.Size(273, 90);
      self.Controls.Add(self.numericUpDown);
      self.Controls.Add(self.labelMessage);
      self.Controls.Add(self.buttonCancel);
      self.Controls.Add(self.buttonOk);
      self.FormBorderStyle := System.Windows.Forms.FormBorderStyle.FixedDialog;
      self.MaximizeBox := false;
      self.MinimizeBox := false;
      self.ShowIcon := false;
      self.ShowInTaskbar := false;
      self.StartPosition := System.Windows.Forms.FormStartPosition.CenterParent;
      self.Text := 'Перейти к строке';
      ((System.ComponentModel.ISupportInitialize)(self.numericUpDown)).EndInit;
      self.ResumeLayout(false);
      self.PerformLayout;
    end;
  
  
  public 
    constructor Create;
    begin
      InitControls;
    end;
    property Line: integer read GetLine write SetLine;
    property LineCount: integer write SetLineCount;
  end;

begin
end. 