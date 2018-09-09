// Перегрузка имен подпрограмм
procedure proc(i: integer);
begin
  writeln('integer');
end;

procedure proc(c: char);
begin
  writeln(c);
end;

procedure proc(r: real);
begin
  writeln('real');
end;

begin
  proc(#50);
end.  