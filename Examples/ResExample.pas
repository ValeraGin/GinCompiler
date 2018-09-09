{$reference 'System.Windows.Forms.dll'}
{$reference 'System.Drawing.dll'}
{$resource '2.png'}

uses 
  System, System.Windows.Forms, System.Drawing;

var 
  myForm: Form;
  
begin
  myForm := new Form;
  //myForm.Text := 'Загрузка изображения из ресурсов';
  MyForm.BackgroundImage := Image.FromStream(GetResourceStream('2.png'));
  Application.Run(myForm);
end.