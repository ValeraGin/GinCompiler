// �������������� � �������� ������� ���������
uses System;

procedure PrintBin(x: integer);
begin
  if x=0 then exit;
  PrintBin(x div 2);
  Console.Write(x mod 2);
end;

begin
  writeln('������� �����');
  var i:= Convert.ToInt32(Console.ReadLine);
  writeln('�������� ������������� �����: ');
  PrintBin(i);
  Console.ReadLine;
end. 