{$DEFINE DEBUG}

begin
{$IFDEF DEBUG}
writeln('DEBUG');
{$ELSE}
writeln('not DEBUG');
{$ENDIF}
end.