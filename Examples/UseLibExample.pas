{$apptype windows} // убираем консоль по умолчанию
{$reference 'lib.dll'}
begin
  lib.lib.MsgBox('вызов функции lib.dll', 'вызов функции lib.dll');
end.