@echo off& set root=%1& set title= Auto Upgrade with edition switch support 
set "EDITION_SWITCH="
set "SKIP_11_SETUP_CHECKS=1"
set OPTIONS=/SelfHost /Auto Upgrade /MigChoice Upgrade /Compat IgnoreWarning /MigrateDrivers All /ResizeRecoveryPartition Disable /ShowOOBE None /Telemetry Disable /CompactOS Disable /DynamicUpdate Enable /SkipSummary /Eula Accept

pushd "%~dp0"& if defined root pushd %root% 
for %%i in ("x86\" "x64\" "") do if exist "%%~isources\setupprep.exe" set "dir=%%~i"
pushd "%dir%sources" || (echo "%dir%sources" & timeout /t 5 & exit /b)
setlocal EnableDelayedExpansion

::# start sources\setup if under winpe (when booted from media)
reg query "HKLM\Software\Microsoft\Windows NT\CurrentVersion\WinPE">nul 2>nul && (start "WinPE" sources\setup.exe &exit /b)

::# elevate so that workarounds can be set under windows
fltmc>nul || (set _="%~f0" %*& powershell -nop -c start -verb runas cmd \"/d/x/r call $env:_\"& exit /b)

::# undo any previous regedit edition rename (if upgrade was interrupted)
set EI=& set PN=& set NT="HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion"  
for /f "tokens=2*" %%R in ('reg query %NT% /v EditionID_undo /reg:64 2^>nul') do set "EI=%%S"
for /f "tokens=2*" %%R in ('reg query %NT% /v ProductName_undo /reg:64 2^>nul') do set "PN=%%S"
for %%a in (32 64) do (
 if defined EI reg add %NT% /v EditionID /d "%EI%" /f /reg:%%a   & reg delete %NT% /v EditionID_undo /f /reg:%%a
 if defined PN reg add %NT% /v ProductName /d "%EI%" /f /reg:%%a & reg delete %NT% /v ProductName_undo /f /reg:%%a
) >nul 2>nul

::# get current version
set EditionID=& set ProductName=& set NT="HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion"                       
for /f "tokens=2*" %%R in ('reg query %NT% /v EditionID /reg:64 2^>nul') do set "EditionID=%%S"
for /f "tokens=2*" %%R in ('reg query %NT% /v ProductName /reg:64 2^>nul') do set "ProductName=%%S"
for /f "tokens=2*" %%R in ('reg query %NT% /v CurrentBuildNumber /reg:64 2^>nul') do set "CurrentBuild=%%S"
for /f "tokens=2-3 delims=[." %%i in ('ver') do for %%s in (%%i) do set /a Version=%%s*10+%%j

::# WIM_INFO w_5=wim_5th b_5=build_5th p_5=patch_5th a_5=arch_5th l_5=lang_5th e_5=edi_5th d_5=desc_5th i_5=edi_5th i_Core=index
set "0=%~f0"& set wim=& set ext=.esd& if exist install.wim (set ext=.wim) else if exist install.swm set ext=.swm
set snippet=powershell -nop -c iex ([io.file]::ReadAllText($env:0)-split'#[:]wim_info[:]')[1]; WIM_INFO install%ext% 0 0  
set w_count=0& for /f "tokens=1-7 delims=," %%i in ('"%snippet%"') do (set w_%%i=%%i,%%j,%%k,%%l,%%m,%%n,%%o& set /a w_count+=1
set b_%%i=%%j& set p_%%i=%%k& set a_%%i=%%l& set l_%%i=%%m& set e_%%i=%%n& set d_%%i=%%o& set i_%%n=%%i& set i_%%i=%%n)

::# print available editions in install.esd via wim_info snippet
echo;------------------------------------------------------------------------------------
for /l %%i in (1,1,%w_count%) do call echo;%%w_%%i%%
echo;------------------------------------------------------------------------------------

::# get requested edition in EI.cfg or PID.txt or OPTIONS
if exist product.ini for /f "tokens=1,2 delims==" %%O in (product.ini) do if not "%%P" equ "" (set pid_%%O=%%P& set pn_%%P=%%O)
set EI=& set Name=& set nID=& set reg=& set "cfg_filter=EditionID Channel OEM Retail Volume _Default VL 0 1 ^$"
if exist EI.cfg for /f "tokens=*" %%i in ('findstr /v /i /r "%cfg_filter%" EI.cfg') do (set EI=%%i& set nID=%%i)
if exist PID.txt for /f "delims=;" %%i in (PID.txt) do set %%i 2>nul
if not defined Value for %%s in (%OPTIONS%) do if defined pn_%%s (set Name=!pn_%%s!& set Name=!Name:gvlk=!)
if defined Value if not defined Name for %%s in (%Value%) do (set Name=!pn_%%s!& set Name=!Name:gvlk=!)
if defined EDITION_SWITCH (set nID=%EDITION_SWITCH%) else if defined Name for %%s in (%Name%) do (set nID=%Name%)
if not defined nID set nID=%EditionID%& if not defined EditionID set nID=Professional& set EditionID=Professional
if /i "%EditionID%" equ "%nID%" (set changed=) else set changed=1

::# upgrade matrix to automatically fallback to an edition that would keep files and apps
set HOME=Starter HomeBasic HomePremium CoreConnectedCountrySpecific CoreConnectedSingleLanguage CoreConnected Core
set HOME_N=StarterN HomeBasicN HomePremiumN CoreConnectedN CoreN & set HOME_S=CoreSingleLanguage CoreCountrySpecific
set ULT=Ultimate ProfessionalStudent ProfessionalCountrySpecific ProfessionalSingleLanguage& set CLOUD=Cloud
set ULT_N=UltimateN ProfessionalStudentN& set CLOUD_N=CloudN
set EDU=Education& set ENT=Enterprise& set LTS=EnterpriseG EnterpriseS IoTEnterpriseS Embedded& set IOT=IoTEnterprise
set EDU_N=EducationN& set ENT_N=EnterpriseN& set LTS_N=EnterpriseGN EnterpriseSN
set PRO=ProfessionalEducation ProfessionalWorkstation Professional& set MIX=%ENT% %EDU% !PRO! %CLOUD%
set PRO_N=ProfessionalEducationN ProfessionalWorkstationN ProfessionalN& set MIX_N=%ENT_N% %EDU_N% !PRO_N! %CLOUD_N%
for %%C in (%LTS_N%)  do if /i %%C equ %nID% (set nID=EnterpriseN)
for %%C in (%LTS%)    do if /i %%C equ %nID% (set nID=Enterprise)
for %%C in (%ULT_N%)  do if /i %%C equ %nID% (set nID=ProfessionalN)
for %%C in (%ULT%)    do if /i %%C equ %nID% (set nID=Professional)
for %%C in (%MIX_N%)  do if /i %%C equ %nID% (set nID=ProfessionalN& set reg=%%C& if defined i_%%C set nID=%%C)
for %%C in (%MIX%)    do if /i %%C equ %nID% (set nID=Professional&  set reg=%%C& if defined i_%%C set nID=%%C)
for %%C in (%HOME_N%) do if /i %%C equ %nID% (set nID=CoreN& set reg=CoreN& if not defined i_CoreN set nID=ProfessionalN)
for %%C in (%HOME%)   do if /i %%C equ %nID% (set nID=Core&  set reg=Core&  if not defined i_Core  set nID=Professional)
for %%C in (%HOME_S%) do if /i %%C equ %nID% (set nID=Core& set reg=%%C& if defined i_%%C set nID=%%C)
for %%C in (%IOT%)    do if /i %%C equ %nID% (set nID=Enterprise& set reg=%%C)
set index=& for /l %%i in (1,1,%w_count%) do if /i !i_%%i! equ !nID! (set nID=!i_%%i!& set index=%%i)
if not defined index set index=1& set nID=!i_1!& if defined i_Professional set index=!i_Professional!& set nID=Professional
set Build=!b_%index%!& set OPTIONS=%OPTIONS% /ImageIndex %index%& if defined changed if not defined reg (set reg=!nID!)
echo;Current edition: %EditionID% & echo;Regedit edition: %reg% & echo;Index: %index%  Image: %nID%
timeout /t 10

::# prevent usage of MCT for intermediary upgrade in Dynamic Update (causing 7 to 19H1 instead of 7 to 21H2 for example) 
if "%Build%" gtr "15063" (set OPTIONS=%OPTIONS% /UpdateMedia Decline)

::# skip windows 11 upgrade checks via launch option trick - this way, can still run setup.exe directly to not skip checks
if "%Build%" geq "22000" if "%SKIP_11_SETUP_CHECKS%" equ "1" (set OPTIONS=/Product Server %OPTIONS%)

::# auto upgrade with edition lie workaround to keep files and apps - all 1904x builds allow up/downgrade between them
if defined reg call :rename %reg%
start "auto" setupprep.exe %OPTIONS%
exit /b

:rename EditionID
set NT="HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
(reg query %NT% /v ProductName_undo      /reg:32 || reg add %NT% /v ProductName_undo /d "%ProductName%" /f /reg:32
 reg query %NT% /v ProductName_undo      /reg:64 || reg add %NT% /v ProductName_undo /d "%ProductName%" /f /reg:64
 reg query %NT% /v EditionID_undo        /reg:32 || reg add %NT% /v EditionID_undo   /d "%EditionID%"   /f /reg:32
 reg query %NT% /v EditionID_undo        /reg:64 || reg add %NT% /v EditionID_undo   /d "%EditionID%"   /f /reg:64
 reg add   %NT% /v EditionID /d "%~1" /f /reg:32 &  reg add %NT% /v ProductName      /d "%~1"           /f /reg:32
 reg add   %NT% /v EditionID /d "%~1" /f /reg:64 &  reg add %NT% /v ProductName      /d "%~1"           /f /reg:64
) >nul 2>nul &exit /b

#:WIM_INFO:# [PARAMS]: "file" [optional]Index or 0 = all  Output 0 = txt 1 = xml 2 = file.txt 3 = file.xml 4 = xml object
set ^ #=$f0=[io.file]::ReadAllText($env:0); $0=($f0-split '#[:]WIM_INFO[:]' ,3)[1]; $1=$env:1-replace'([`@$])','`$1'; iex($0+$1)
set ^ #=& set "0=%~f0"& set 1=;WIM_INFO %*& powershell -nop -c "%#%"& exit /b %errorcode%
function WIM_INFO ($file = 'install.esd', $index = 0, $out = 0) { :info while ($true) {
  $block = 2097152; $bytes = new-object 'Byte[]' ($block); $begin = [uint64]0; $final = [uint64]0; $limit = [uint64]0
  $steps = [int]([uint64]([IO.FileInfo]$file).Length / $block - 1); $enc = [Text.Encoding]::GetEncoding(28591); $delim = @()
  foreach ($d in '/INSTALLATIONTYPE','/WIM') {$delim += $enc.GetString([Text.Encoding]::Unicode.GetBytes([char]60+ $d +[char]62))}
  $f = new-object IO.FileStream ($file, 3, 1, 1); $p = 0; $p = $f.Seek(0, 2)
  for ($o = 1; $o -le $steps; $o++) { 
    $p = $f.Seek(-$block, 1); $r = $f.Read($bytes, 0, $block); if ($r -ne $block) {write-host invalid block $r; break}
    $u = [Text.Encoding]::GetEncoding(28591).GetString($bytes); $t = $u.LastIndexOf($delim[0], [StringComparison]::Ordinal) 
    if ($t -lt 0) { $p = $f.Seek(-$block, 1)} else { [void]$f.Seek(($t -$block), 1)
      for ($o = 1; $o -le $block; $o++) { [void]$f.Seek(-2, 1); if ($f.ReadByte() -eq 0xfe) {$begin = $f.Position; break} }
      $limit = $f.Length - $begin; if ($limit -lt $block) {$x = $limit} else {$x = $block}
      $bytes = new-object 'Byte[]' ($x); $r = $f.Read($bytes, 0, $x) 
      $u = [Text.Encoding]::GetEncoding(28591).GetString($bytes); $t = $u.IndexOf($delim[1], [StringComparison]::Ordinal)
      if ($t -ge 0) {[void]$f.Seek(($t + 12 -$x), 1); $final = $f.Position} ; break } }
  if ($begin -gt 0 -and $final -gt $begin) {
    $x = $final - $begin; [void]$f.Seek(-$x, 1); $bytes = new-object 'Byte[]' ($x); $r = $f.Read($bytes, 0, $x)
    if ($r -ne $x) {$f.Dispose(); break} else {[xml]$xml = [Text.Encoding]::Unicode.GetString($bytes); $f.Dispose()}
  } else {$f.Dispose()} ; break :info }
  if ($out -eq 1) {[console]::OutputEncoding=[Text.Encoding]::UTF8; $xml.Save([Console]::Out); ''; return} 
  if ($out -eq 3) {try{$xml.Save(($file-replace'esd$','xml'))}catch{}; return}; if ($out -eq 4) {return $xml}
  $txt = ''; foreach ($i in $xml.WIM.IMAGE) {if ($index -gt 0 -and $($i.INDEX) -ne $index) {continue}; [int]$a='1'+$i.WINDOWS.ARCH
  $txt+= $i.INDEX+','+$i.WINDOWS.VERSION.BUILD+','+$i.WINDOWS.VERSION.SPBUILD+','+$(@{10='x86';15='arm';19='x64';112='arm64'}[$a])
  $txt+= ','+$i.WINDOWS.LANGUAGES.LANGUAGE+','+$i.WINDOWS.EDITIONID+','+$i.NAME+[char]13+[char]10}; $txt=$txt-replace',(?=,)',', '
  if ($out -eq 2) {try{[io.file]::WriteAllText(($file-replace'esd$','txt'),$txt)}catch{}; return}; if ($out -eq 0) {return $txt}
} #:WIM_INFO:# Quick WIM SWM ESD ISO info v2 - lean and mean snippet by AveYo, 2021
