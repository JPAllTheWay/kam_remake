echo called build_utils.bat

@REM Unset vars we use to determine multiple includes
@SET RS_INIT=False
@SET KAM_FOLDER_INIT=False
@SET UPDATE_REV=False

call rsvars.bat

@REM Build utils applications, included into the final build

REM Build Campaign Builder
msbuild "..\Utils\Campaign builder\CampaignBuilder.dproj" /p:config=Release /t:Build /clp:ErrorsOnly /fl /flp:LogFile="build_campaign_builder.log"
if errorlevel 1 goto exit3

REM Build Dedicated Server (Console app)
msbuild ..\Utils\DedicatedServer\KaM_DedicatedServer.dproj /p:config=Release /t:Build /clp:ErrorsOnly /fl /flp:LogFile="build_dedicated_server.log"
if errorlevel 1 goto exit3

REM Build Dedicated Server (GUI app)
msbuild ..\Utils\DedicatedServerGUI\KaM_DedicatedServerGUI.dproj /p:config=Release /t:Build /clp:ErrorsOnly /fl /flp:LogFile="build_dedicated_server_gui.log"
if errorlevel 1 goto exit3

REM Build Script Validator
REM use debug conf, since release config compilation crashes with an interal error
msbuild ..\Utils\ScriptValidator\ScriptValidator.dproj /p:config=Debug /t:Build /clp:ErrorsOnly /fl /flp:LogFile="build_script_validator.log"
if errorlevel 1 goto exit3

REM Build Translation Manager
@REM msbuild ..\Utils\TranslationManager\TranslationManager.dproj /p:config=Release /t:Build /clp:ErrorsOnly /fl /flp:LogFile="build_translation_manager.log"
msbuild "..\Utils\TranslationManager\TranslationManager.dproj" /p:config=Release /t:Build /clp:ErrorsOnly /fl /flp:LogFile="build_translation_manager.log"
if errorlevel 1 goto exit3

REM Build Scripting Editor
if %IncludeScriptingEditor%==True (
  msbuild "%ScriptingEditorDir%"\ScriptingEditor.dproj /p:config=Release /t:Build /clp:ErrorsOnly /fl /flp:LogFile="build_script_editor.log"
  if errorlevel 1 goto exit3
)

call build_linux_servers.bat
if errorlevel 1 goto exit3

goto exit0

:exit3
@echo off
exit /B 3

:exit0
@echo off
exit /B 0

