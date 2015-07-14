call clean.bat
"C:\Program Files\Borland\Delphi6\BIN\dcc32.exe" bcreationdate.dpr
bcreationdate.exe
"C:\Program Files\Borland\Delphi6\BIN\dcc32.exe" -CG -GD -Dnomodeless -Dshortstrings bircd.dpr
upx --best bircd.exe
