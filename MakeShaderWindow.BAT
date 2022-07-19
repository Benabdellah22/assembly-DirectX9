SET FILE=ShaderWindow
SET PATH=C:\masm32\bin\

@echo off
	
if not exist ShaderWindow.rc goto delexe
%PATH%Rc.exe /v ShaderWindow.rc
%PATH%Cvtres.exe /machine:ix86 ShaderWindow.res

:delexe
if exist %FILE%.exe del %FILE%.exe

%PATH%Ml.exe /c /coff /Cp %FILE%.asm
if errorlevel 1 goto errorasm

if not exist ShaderWindow.obj goto nores

%PATH%Link.exe /SUBSYSTEM:WINDOWS /VERSION:4.0 %FILE%.obj ShaderWindow.res
if errorlevel 1 goto errorlink

if exist %FILE%.obj del %FILE%.obj
if exist ShaderWindow.obj del ShaderWindow.obj
if exist ShaderWindow.res del ShaderWindow.res

dir %FILE%.*
goto Show

:nores
%PATH%Link.exe /SUBSYSTEM:WINDOWS /VERSION:4.0 %FILE%.obj
if errorlevel 1 goto errorlink

if exist %FILE%.obj del %FILE%.obj

dir %FILE%.*
goto Show

:errorlink
echo _
echo Link error
goto Done

:errorasm
echo _
echo Assembly Error
goto Done

:Show
%FILE%.exe
:Done
pause

