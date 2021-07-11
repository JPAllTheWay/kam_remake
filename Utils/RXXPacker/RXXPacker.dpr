program RXXPacker;
{$I ..\..\KaM_Remake.inc}
{$APPTYPE CONSOLE}
uses
  Forms, SysUtils,
  {$IFDEF FPC}Interfaces,{$ENDIF}
  {$IFDEF MSWindows} Windows, {$ENDIF}
  {$IFDEF FPC} LResources, LCLIntf, {$ENDIF}
  RXXPackerForm in 'RXXPackerForm.pas' {RXXForm1},
	RXXPackerProc in 'RXXPackerProc.pas',
  KM_IoPNG in '..\..\src\utils\io\KM_IoPNG.pas',
  KM_Pics in '..\..\src\res\KM_Pics.pas',
  KM_ResSprites in '..\..\src\res\KM_ResSprites.pas',
  KM_ResSpritesEdit in '..\..\src\res\KM_ResSpritesEdit.pas',
  KM_ResPalettes in '..\..\src\res\KM_ResPalettes.pas',
  KM_ResTypes in '..\..\src\res\KM_ResTypes.pas',
  KM_SoftShadows in '..\..\src\utils\algorithms\KM_SoftShadows.pas',
  KM_Defaults in '..\..\src\common\KM_Defaults.pas',
  KM_CommonTypes in '..\..\src\common\KM_CommonTypes.pas',
  KM_CommonClasses in '..\..\src\common\KM_CommonClasses.pas',
  KM_Points in '..\..\src\common\KM_Points.pas',
  KM_CommonUtils in '..\..\src\utils\KM_CommonUtils.pas',
  KromUtils in '..\..\src\utils\KromUtils.pas',
  KM_FileIO in '..\..\src\utils\io\KM_FileIO.pas',
  KM_Outline in '..\..\src\navmesh\KM_Outline.pas',
  KM_PolySimplify in '..\..\src\navmesh\KM_PolySimplify.pas',
  KM_Render in '..\..\src\render\KM_Render.pas',
  KM_RenderControl in '..\..\src\render\KM_RenderControl.pas',
  KM_BinPacking in '..\..\src\utils\algorithms\KM_BinPacking.pas',
  PolyTriangulate in '..\..\src\ext\PolyTriangulate.pas',
  {$IFDEF FPC}
  BGRABitmap in '..\..\src\ext\BGRABitmap\BGRABitmap.pas',
  BGRAWinBitmap in '..\..\src\ext\BGRABitmap\BGRAWinBitmap.pas',
  BGRADefaultBitmap in '..\..\src\ext\BGRABitmap\BGRADefaultBitmap.pas',
  BGRABitmapTypes in '..\..\src\ext\BGRABitmap\BGRABitmapTypes.pas',
  BGRACanvas in '..\..\src\ext\BGRABitmap\BGRACanvas.pas',
  BGRAPen in '..\..\src\ext\BGRABitmap\BGRAPen.pas',
  BGRAPolygon in '..\..\src\ext\BGRABitmap\BGRAPolygon.pas',
  BGRAPolygonAliased in '..\..\src\ext\BGRABitmap\BGRAPolygonAliased.pas',
  BGRAFillInfo in '..\..\src\ext\BGRABitmap\BGRAFillInfo.pas',
  BGRABlend in '..\..\src\ext\BGRABitmap\BGRABlend.pas',
  BGRAGradientScanner in '..\..\src\ext\BGRABitmap\BGRAGradientScanner.pas',
  BGRATransform in '..\..\src\ext\BGRABitmap\BGRATransform.pas',
  BGRAResample in '..\..\src\ext\BGRABitmap\BGRAResample.pas',
  BGRAFilters in '..\..\src\ext\BGRABitmap\BGRAFilters.pas',
  BGRAText in '..\..\src\ext\BGRABitmap\BGRAText.pas',
  {$ENDIF}
  dglOpenGL in '..\..\src\ext\dglOpenGL.pas',
  KromOGLUtils in '..\..\src\utils\KromOGLUtils.pas';


{$IFDEF WDC}
{$R *.res}
{$ENDIF}

var
  I, K: Integer;
  forcedConsoleMode: Boolean;
  rxType: TRXType;
  lRxxPacker: TKMRXXPacker;
  palettes: TKMResPalettes;
  tick: Cardinal;

const
  RXToPack: array[0..5] of TRXType = (
    rxTrees,
    rxHouses,
    rxUnits,
    rxGui,
    rxGuiMain,
    rxTiles);


function IsConsoleMode: Boolean;
var
  SI: TStartupInfo;
begin
  SI.cb := SizeOf(StartUpInfo);
  GetStartupInfo(SI);
  Result := (SI.dwFlags and STARTF_USESHOWWINDOW) = 0;
  {$IFDEF FPC}
  Result := False
  {$ENDIF}
end;


begin
  forcedConsoleMode :=
  {$IFDEF FPC}
    False //Set this to True to use as console app in lazarus
  {$ELSE}
    False
  {$ENDIF}
    ;
  if forcedConsoleMode or IsConsoleMode then
  begin
    if ParamCount >= 1 then
    begin
      writeln(sLineBreak + 'KaM Remake RXX Packer' + sLineBreak);

      ExeDir := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\');
      lRxxPacker := TKMRXXPacker.Create;
      palettes := TKMResPalettes.Create;
      palettes.LoadPalettes(ExeDir + 'data\gfx\');
      try
        for I := 1 to ParamCount do // Skip 0, as this is the EXE-path
        begin
          if LowerCase(ParamStr(I)) = 'all' then
          begin
            for K := Low(RXToPack) to High(RXToPack) do
            begin
              tick := GetTickCount;
              lRxxPacker.Pack(RXToPack[K], palettes);
              writeln(RXInfo[RXToPack[K]].FileName + '.rxx packed in ' + IntToStr(GetTickCount - tick) + ' ms');
            end;
            Exit;
          end;

          for rxType := Low(TRXType) to High(TRXType) do
            if (LowerCase(ParamStr(I)) = LowerCase(RXInfo[rxType].FileName)) then
            begin
              tick := GetTickCount;
              lRxxPacker.Pack(rxType, palettes);
              writeln(RXInfo[rxType].FileName + '.rxx packed in ' + IntToStr(GetTickCount - tick) + ' ms');
            end;
        end;
      finally
        lRxxPacker.Free;
        palettes.Free;
      end;
    end else
    if ParamCount = 0 then
      begin
        writeln('No rx packages were set');
        writeln('Usage example 1: RxxPacker.exe gui guimain houses trees units tileset');
        writeln('Usage example 2: RxxPacker.exe all');
        Exit;
      end;
  end else
  begin
    FreeConsole; // Used to hide the console
    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    Application.CreateForm(TRXXForm1, RXXForm1);
    Application.Run;
  end;
end.
