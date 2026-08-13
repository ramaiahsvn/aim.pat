@echo off
REM ==========================================================================
REM  run-test.cmd - first Windows run of Bpr.QiScript 2.22.28 (GnD central perso)
REM  na-003/012 patwin-laptop
REM
REM  DROP THIS FILE INSIDE the 2.22.28 release folder and double-click it, or
REM  run it from a prompt. It never modifies the release folder: it builds a
REM  working copy in .\run\ and does everything there.
REM
REM  It expects, in the same folder as itself:
REM     windows-32\Bpr.QiScript.dll   windows-64\Bpr.QiScript.dll
REM     qiscript.ini                  qiscript.c.perso-bio.dat
REM     com\bnprs\jni\qiScript.class  (or .java, if a JDK is present)
REM
REM  Optional: put a portable JDK/JRE in .\jdk\  -> it will be found automatically.
REM
REM  Usage:  run-test.cmd ["<exact PC/SC reader name>"]
REM  With no argument it lists the readers and stops, so nothing touches a card
REM  until you have supplied the right name.
REM ==========================================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"

set "LOG=%~dp0qi-test-run.log"
echo ============================================================ > "%LOG%"
echo  Bpr.QiScript 2.22.28 Windows test run                      >> "%LOG%"
echo  started %DATE% %TIME%                                      >> "%LOG%"
echo  host %COMPUTERNAME%  user %USERNAME%                        >> "%LOG%"
echo ============================================================ >> "%LOG%"

call :both ""
call :both "== [1] locate a Java runtime =="

REM ---- find java.exe: bundled jdk, JAVA_HOME, PATH, then Program Files ----
set "JAVA="
if exist "%~dp0jdk\bin\java.exe" set "JAVA=%~dp0jdk\bin\java.exe"
if not defined JAVA if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" set "JAVA=%JAVA_HOME%\bin\java.exe"
if not defined JAVA for /f "delims=" %%i in ('where java.exe 2^>nul') do if not defined JAVA set "JAVA=%%i"
if not defined JAVA for /f "delims=" %%i in ('dir /s /b "%ProgramFiles%\java.exe" 2^>nul') do if not defined JAVA set "JAVA=%%i"
if not defined JAVA for /f "delims=" %%i in ('dir /s /b "%ProgramFiles(x86)%\java.exe" 2^>nul') do if not defined JAVA set "JAVA=%%i"

if not defined JAVA (
  call :both "  NO JAVA RUNTIME FOUND."
  call :both "  A JVM is unavoidable - the JNI library is the card-I/O path."
  call :both "  Either unzip a portable JDK into:  %~dp0jdk\"
  call :both "  or set JAVA_HOME. Then re-run this script."
  goto :finish
)
call :both "  java: !JAVA!"

REM ---- bitness decides which DLL, and it is the JVM's, not the machine's ----
set "BITS="
for /f "tokens=3" %%b in ('"!JAVA!" -XshowSettings:properties -version 2^>^&1 ^| findstr /c:"sun.arch.data.model"') do set "BITS=%%b"
if not defined BITS (
  call :both "  could not read sun.arch.data.model - aborting rather than guessing"
  goto :finish
)
call :both "  JVM bitness: !BITS!-bit  -> using windows-!BITS!"
if "!BITS!"=="64" call :both "  NOTE: x64 was never affected by the JNICALL bug. A 32-bit JVM would"
if "!BITS!"=="64" call :both "        additionally exercise the __stdcall fix, which is windows-32 only."

set "SRCDLL=%~dp0windows-!BITS!\Bpr.QiScript.dll"
if not exist "!SRCDLL!" (
  call :both "  MISSING: !SRCDLL!"
  goto :finish
)

call :both ""
call :both "== [2] verify the DLL by hash =="
if "!BITS!"=="32" set "WANT=aab1eefc392e72b58e0c4c3f37e91b2892a8a27a317cfa16f061eecda9af7e55"
if "!BITS!"=="64" set "WANT=918415ce493e7dcb25cf8cf63a18ea411abee15c86170b9d97037fea73093031"
set "GOT="
for /f "skip=1 delims=" %%h in ('certutil -hashfile "!SRCDLL!" SHA256 2^>nul') do if not defined GOT set "GOT=%%h"
set "GOT=!GOT: =!"
call :both "  expected !WANT!"
call :both "  actual   !GOT!"
if /i "!GOT!"=="!WANT!" (
  call :both "  MATCH - this is the released 2.22.28 build"
) else (
  call :both "  MISMATCH - this is NOT the 2.22.28 artefact. Stopping."
  call :both "  (the DLL carries no version resource, so sha256 is the only identifier)"
  goto :finish
)

call :both ""
call :both "== [3] environment =="
sc query SCardSvr | findstr /c:"STATE" >> "%LOG%" 2>&1
sc query SCardSvr | findstr /c:"STATE"
for /f "tokens=3" %%s in ('sc query SCardSvr ^| findstr /c:"STATE"') do set "SCSTATE=%%s"
if /i not "!SCSTATE!"=="4" call :both "  WARNING: smart-card service not RUNNING (expect -402)"

call :both ""
call :both "== [4] readers present =="
certutil -scinfo 2>&1 | findstr /i /c:"Reader:" >> "%LOG%"
certutil -scinfo 2>&1 | findstr /i /c:"Reader:"
if errorlevel 1 call :both "  (no 'Reader:' lines - reader may be absent; expect -2146435026)"

REM ---- reader name must be supplied explicitly; never guess it ----
set "READER=%~1"
if "!READER!"=="" (
  call :both ""
  call :both "  No reader name given. Copy the EXACT name from the list above"
  call :both "  (including trailing instance numbers) and re-run, in quotes, e.g."
  call :both ""
  call :both "      run-test.cmd  OMNIKEY AG 3121 USB 00 00      <- wrap in quotes"
  call :both ""
  call :both "  Stopping here so nothing touches a card yet."
  goto :finish
)
call :both "  reader: !READER!"

call :both ""
call :both "== [5] build working copy in .\run\ =="
if not exist "%~dp0run\com\bnprs\jni" mkdir "%~dp0run\com\bnprs\jni" >nul 2>&1
copy /y "!SRCDLL!" "%~dp0run\Bpr.QiScript.dll" >nul
copy /y "%~dp0qiscript.ini" "%~dp0run\" >nul
copy /y "%~dp0qiscript.c.perso-bio.dat" "%~dp0run\" >nul
if exist "%~dp0com\bnprs\jni\qiScript.class" copy /y "%~dp0com\bnprs\jni\qiScript.class" "%~dp0run\com\bnprs\jni\" >nul
if exist "%~dp0com\bnprs\jni\qiScript.java"  copy /y "%~dp0com\bnprs\jni\qiScript.java"  "%~dp0run\com\bnprs\jni\" >nul
cd /d "%~dp0run"

if not exist "com\bnprs\jni\qiScript.class" (
  call :both "  no .class present - trying to compile"
  set "JAVAC=!JAVA:java.exe=javac.exe!"
  if exist "!JAVAC!" ( "!JAVAC!" com\bnprs\jni\qiScript.java ) else ( call :both "  no javac and no .class - cannot continue" & goto :finish )
)
call :both "  working dir ready"

REM ==========================================================================
REM  STAGE 1 - CARD REMOVED. This still crosses the JNI boundary, loads the
REM  licence and builds the whole APDU script, so it fully exercises the
REM  __stdcall fix at zero risk to a card. Expect -2146435060.
REM ==========================================================================
call :both ""
call :both "== [6] STAGE 1: card REMOVED (expect -2146435060) =="
call :both "  Remove the card from the reader, then press a key."
pause >nul
call :runjava

REM ==========================================================================
REM  STAGE 2 - TEST CARD. Central personalisation WRITES and is IRREVERSIBLE.
REM ==========================================================================
call :both ""
call :both "== [7] STAGE 2: insert the TEST card =="
call :both "  *** central perso WRITES to the card and CANNOT be undone ***"
call :both "  *** use a TEST card, never a cardholder card              ***"
call :both "  Insert the test card, then press a key. Ctrl+C to stop here."
pause >nul
call :runjava

call :both ""
call :both "== result codes =="
call :both "   0            success"
call :both "  -2146435060   no card in reader   (expected in stage 1)"
call :both "  -2146435063   reader name mismatch"
call :both "  -2146435026   no reader connected"
call :both "  -402          smart-card service not running"
call :both "  -401 / -301   qiscript.ini missing/empty, or key rejected"
call :both "  -444          a card command was rejected - note the command number and SW"

:finish
echo. >> "%LOG%"
echo finished %DATE% %TIME% >> "%LOG%"
echo.
echo ============================================================
echo  Full log written to:
echo    %LOG%
echo  Send that file back - it has everything needed to read the result.
echo ============================================================
echo.
pause
endlocal
exit /b

REM ---- echo to console and log together ----
:both
echo %~1
echo %~1 >> "%LOG%"
exit /b

REM ---- run the harness EXACTLY ONCE, then replay its output to console + log.
REM      Batch has no tee, and running java twice would attempt to personalise
REM      the card twice. Single invocation only.
:runjava
set "OUTF=%TEMP%\qi_out_%RANDOM%.txt"
"!JAVA!" -Djava.library.path=. com.bnprs.jni.qiScript "!READER!" > "!OUTF!" 2>&1
set "RC=!ERRORLEVEL!"
type "!OUTF!"
type "!OUTF!" >> "%LOG%"
del "!OUTF!" >nul 2>&1
call :both "  (java exit: !RC!)"
exit /b
