// Создание оконного приложения
{$apptype windows}
{$reference 'System.Windows.Forms.dll'}

uses 
  System,
  System.Windows.Forms;

var 
  myForm: Form;
  
begin
  myForm := new Form;
  myForm.Text := 'Оконное приложение';
  Application.Run(myForm);
end.
