// Преобразование в двоичную систему счисления
uses System;

procedure PrintBin(x: integer);
begin
  if x=0 then exit;
  PrintBin(x div 2);
  Console.Write(x mod 2);
end;

begin
  writeln('Введите число');
  var i:= Convert.ToInt32(Console.ReadLine);
  writeln('Двоичное представление числа: ');
  PrintBin(i);
  Console.ReadLine;
end. 