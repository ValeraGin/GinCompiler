// Убираем консоль
{$apptype window}

function MessageBox(h: integer; m: string; c: string; t: integer): integer; 
  external 'User32.dll' name 'MessageBox'; 

begin
  // call native dll function
  MessageBox(0, 'Вызов функции MessageBox из User32.dll', 'call native dll function', 0);
end.