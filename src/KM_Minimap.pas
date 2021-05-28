unit KM_Minimap;
{$I KaM_Remake.inc}
interface
uses
  KromOGLUtils,
  KM_Terrain, KM_Alerts,
  KM_MissionScript_Preview,
  KM_CommonClasses, KM_CommonTypes, KM_Defaults, KM_Points;


type
  //Intermediary class between TTerrain/Players and UI
  TKMMinimap = class
  private
    fPaintVirtualGroups: Boolean; //Paint missing army memmbers
    fSepia: Boolean; //Less saturated display for menu
    fParser: TKMMissionParserPreview;
    fAlerts: TKMAlerts;

    //We need to store map properties locally since Minimaps come from various
    //sources which do not have Terrain in them (TMissionParserPreview, Stream)
    fMapY: Word;
    fMapX: Word;
    fBase: TKMCardinalArray; //Base terrain layer
    fMapTex: TTexture;
    fWidthPOT: Word;
    fHeightPOT: Word;
    procedure ApplySepia;
    procedure Resize(aX, aY: Word);
    procedure UpdateMinimapFromGame;
    procedure UpdateMinimapFromParser(aRevealAll:Boolean);
    procedure UpdateTexture;
  public
    HandColors: array [0..MAX_HANDS-1] of Cardinal;
    HandLocs: array [0..MAX_HANDS-1] of TKMPoint;
    HandShow: array [0..MAX_HANDS-1] of Boolean;
    HandTeam: array [0..MAX_HANDS-1] of ShortInt;
    constructor Create(aFromParser: Boolean; aSepia: Boolean);
    destructor Destroy; override;

    property Alerts: TKMAlerts read fAlerts write fAlerts;
    property MapX: Word read fMapX;
    property MapY: Word read fMapY;
    property MapTex: TTexture read fMapTex;
    property PaintVirtualGroups: Boolean read fPaintVirtualGroups write fPaintVirtualGroups;

    procedure LoadFromMission(const aMissionPath: string; const aRevealFor: array of TKMHandID);
    procedure LoadFromTerrain;
    procedure LoadFromStream(LoadStream: TKMemoryStream);
    procedure SaveToStream(SaveStream: TKMemoryStream);

    procedure Update(aRevealAll: Boolean = False);
  end;


implementation
uses
  SysUtils, KromUtils, Math,
  KM_Game, KM_GameParams, KM_Render, KM_RenderTypes,
  KM_Units, KM_UnitGroup,
  KM_Hand, KM_HandsCollection, KM_HandTypes,
  KM_Resource, KM_ResUnits, KM_CommonUtils,
  KM_DevPerfLog, KM_DevPerfLogTypes, KM_TerrainTypes;


{ TKMMinimap }
constructor TKMMinimap.Create(aFromParser: Boolean; aSepia: Boolean);
begin
  inherited Create;

  fSepia := aSepia;
  fMapTex.Tex := TRender.GenerateTextureCommon(ftNearest, ftNearest);

  //We don't need terrain on main menu, just a parser
  //Otherwise access synced Game terrain
  if aFromParser then
    fParser := TKMMissionParserPreview.Create;
end;


destructor TKMMinimap.Destroy;
begin
  FreeAndNil(fParser);
  inherited;
end;


// Load map in a direct way, should be used only when in Menu
// aMissionPath - path to .dat file
procedure TKMMinimap.LoadFromMission(const aMissionPath: string; const aRevealFor: array of TKMHandID);
var
  I: Integer;
begin
  fParser.LoadMission(aMissionPath, aRevealFor);

  Resize(fParser.MapX - 1, fParser.MapY - 1);

  for I := 0 to MAX_HANDS - 1 do
  begin
    HandColors[I] := fParser.PlayerPreview[I].Color;
    HandLocs[I] := fParser.PlayerPreview[I].StartingLoc;
    HandShow[I] := fParser.PlayerPreview[I].CanHuman;
  end;
end;


procedure TKMMinimap.LoadFromTerrain;
var
  I: Integer;
begin
  Resize(gTerrain.MapX - 1, gTerrain.MapY - 1);

  for I := 0 to MAX_HANDS - 1 do
  begin
    HandColors[I] := $00000000;
    HandLocs[I] := KMPOINT_ZERO;
    HandShow[I] := False;
  end;
end;


procedure TKMMinimap.Resize(aX, aY: Word);
begin
  fMapX := aX;
  fMapY := aY;
  SetLength(fBase, fMapX * fMapY);
  fWidthPOT := MakePOT(fMapX);
  fHeightPOT := MakePOT(fMapY);
  fMapTex.U := fMapX / fWidthPOT;
  fMapTex.V := fMapY / fHeightPOT;
end;


procedure TKMMinimap.UpdateMinimapFromParser(aRevealAll: Boolean);
var
  I, K, N: Integer;
  light: SmallInt;
  x0,y2: Word;
begin
  for I := 1 to fMapY do
  for K := 1 to fMapX do
    with fParser.MapPreview[K,I] do
    begin
      N := (I-1) * fMapX + (K-1);
      if not aRevealAll and not Revealed then
        fBase[N] := $E0000000
      else
        if TileOwner <> HAND_NONE then
          fBase[N] := HandColors[TileOwner]
        else
        begin
          //Formula for lighting is the same as in TTerrain.RebuildLighting
          x0 := Max(K-1, 1);
          y2 := Min(I+1, fMapY);
          light := Round(EnsureRange((TileHeight - (fParser.MapPreview[K,y2].TileHeight + fParser.MapPreview[x0,I].TileHeight)/2)/22, -1, 1)*64);
          fBase[N] := Byte(EnsureRange(gRes.Tileset.TileColor[TileID].R+light, 0, 255)) +
                      Byte(EnsureRange(gRes.Tileset.TileColor[TileID].G+light, 0, 255)) shl 8 +
                      Byte(EnsureRange(gRes.Tileset.TileColor[TileID].B+light, 0, 255)) shl 16 or $FF000000;
        end;
    end;
end;


//Sepia method taken from:
//http://www.techrepublic.com/blog/howdoi/how-do-i-convert-images-to-grayscale-and-sepia-tone-using-c/120
procedure TKMMinimap.ApplySepia;
const
  SEPIA_VAL = 0.4;
var
  I: Integer;
  R, G, B, R2, G2, B2: Byte;
begin
  for I := 0 to fMapX * fMapY - 1 do
  begin
    //We split color to RGB values
    R := fBase[I] and $FF;
    G := fBase[I] shr 8 and $FF;
    B := fBase[I] shr 16 and $FF;

    //Apply sepia coefficients and merge back with SEPIA_VAL factor
    R2 := Min(Round(0.393 * R + 0.769 * G + 0.189 * B), 255);
    R2 := Mix(R2, R, SEPIA_VAL);

    G2 := Min(Round(0.349 * R + 0.686 * G + 0.168 * B), 255);
    G2 := Mix(G2, G, SEPIA_VAL);

    B2 := Min(Round(0.272 * R + 0.534 * G + 0.131 * B), 255);
    B2 := Mix(B2, B, SEPIA_VAL);

    fBase[I] := (R2 + G2 shl 8 + B2 shl 16) or $FF000000;
  end;
end;


//MapEditor stores only commanders instead of all groups members
procedure TKMMinimap.UpdateMinimapFromGame;
var
  I, J, K, MX, MY: Integer;
  fow: Byte;
  ID: Word;
  U: TKMUnit;
  P: TKMPoint;
  doesFit: Boolean;
  light: Smallint;
  group: TKMUnitGroup;
  tileOwner: TKMHandID;
  landPtr: ^TKMTerrainTile;
  RGB: TRGB;
begin
  {$IFDEF PERFLOG}
  gPerfLogs.SectionEnter(psMinimap);
  {$ENDIF}
  //if OVERLAY_OWNERSHIP then
  //begin
  //  for I := 0 to fMapY - 1 do
  //    for K := 0 to fMapX - 1 do
  //    begin
  //      Owner := gAIFields.Influences.GetBestOwner(K,I);
  //      if Owner <> PLAYER_NONE then
  //        fBase[I*fMapX + K] := ReduceBrightness(gHands[Owner].FlagColor, Byte(Max(gAIFields.Influences.Ownership[Owner,I,K],0)))
  //      else
  //        fBase[I*fMapX + K] := $FF000000;
  //    end;
  //  Exit;
  //end;

  for I := 0 to fMapY - 1 do
    for K := 0 to fMapX - 1 do
    begin
      MX := K+1;
      MY := I+1;
      fow := gMySpectator.FogOfWar.CheckTileRevelation(MX,MY);

      if fow = 0 then
        fBase[I*fMapX + K] := $FF000000
      else begin
        landPtr := @gTerrain.Land^[MY,MX];
        tileOwner := -1;
        if landPtr.TileOwner <> -1 then
        begin
          if gTerrain.TileHasRoad(MX, MY)
            and (landPtr.IsUnit <> nil)
            and InRange(TKMUnit(landPtr.IsUnit).Owner, 0, MAX_HANDS) then
            tileOwner := TKMUnit(landPtr.IsUnit).Owner
          else
            tileOwner := landPtr.TileOwner;
        end;

        if (tileOwner <> -1)
          and not gTerrain.TileIsCornField(KMPoint(MX, MY)) //Do not show corn and wine on minimap
          and not gTerrain.TileIsWineField(KMPoint(MX, MY)) then
          fBase[I*fMapX + K] := gHands[tileOwner].GameFlagColor
        else
        begin
          U := landPtr.IsUnit;
          if U <> nil then
            if U.Owner <> HAND_ANIMAL then
              fBase[I*fMapX + K] := gHands[U.Owner].GameFlagColor
            else
              fBase[I*fMapX + K] := gRes.Units[U.UnitType].MinimapColor
          else
          begin
            ID := landPtr.BaseLayer.Terrain;
            // Do not use gTerrain.Land^[].Light for borders of the map, because it is set to -1 for fading effect
            // So assume gTerrain.Land^[].Light as medium value in this case
            if (I = 0) or (I = fMapY - 1) or (K = 0) or (K = fMapX - 1) then
              light := 255-fow
            else
              light := Round(landPtr.RenderLight*64)-(255-fow); //it's -255..255 range now
            RGB := gRes.Tileset.TileColor[ID];
            fBase[I*fMapX + K] := Byte(EnsureRange(RGB.R+light,0,255)) or
                                  Byte(EnsureRange(RGB.G+light,0,255)) shl 8 or
                                  Byte(EnsureRange(RGB.B+light,0,255)) shl 16 or $FF000000;
          end;
        end;
      end;
    end;

  //Scan all players units and paint all virtual group members in MapEd
  if fPaintVirtualGroups then
    for I := 0 to gHands.Count - 1 do
      for K := 0 to gHands[I].UnitGroups.Count - 1 do
      begin
        group := gHands[I].UnitGroups[K];
        for J := 1 to group.MapEdCount - 1 do
        begin
          //GetPositionInGroup2 operates with 1..N terrain, while Minimap uses 0..N-1, hence the +1 -1 fixes
          P := GetPositionInGroup2(group.Position.X, group.Position.Y, group.Direction, J, group.UnitsPerRow, fMapX+1, fMapY+1, doesFit);
          if not doesFit then Continue; //Don't render units that are off the map in the map editor
          fBase[(P.Y - 1) * fMapX + P.X - 1] := gHands[I].FlagColor;
        end;
      end;

  //Draw 'Resize map' feature on minimap
  if (gGame <> nil) and gGameParams.IsMapEditor
    and (melMapResize in gGame.MapEditor.VisibleLayers)
    and not KMSameRect(gGame.MapEditor.ResizeMapRect, KMRECT_ZERO) then
    for I := 0 to fMapY - 1 do
      for K := 0 to fMapX - 1 do
      begin
        if not KMInRect(KMPoint(K+1,I+1), gGame.MapEditor.ResizeMapRect) then
          fBase[I*fMapX + K] := ApplyColorCoef(fBase[I*fMapX + K], 1, 2, 1, 1); // make red margins where current map is cut
      end;

  {$IFDEF PERFLOG}
  gPerfLogs.SectionLeave(psMinimap);
  {$ENDIF}
end;


procedure TKMMinimap.Update(aRevealAll: Boolean = False);
begin
  if SKIP_RENDER then Exit;

  // No need to update if we did not initialize map sizes yet
  // F.e. when Cinematic starts in OnMissionStart script procedure in the replay
  if fMapX*fMapY = 0 then Exit;

  if fParser <> nil then
    UpdateMinimapFromParser(aRevealAll)
  else
    UpdateMinimapFromGame;

  if fSepia then ApplySepia;

  UpdateTexture;
end;


procedure TKMMinimap.UpdateTexture;
var
  wData: Pointer;
  I: Word;
begin
  GetMem(wData, fWidthPOT * fHeightPOT * 4);

  if fMapY > 0 then //if MapY = 0 then loop will overflow to MaxWord
  for I := 0 to fMapY - 1 do
    Move(Pointer(NativeUint(fBase) + I * fMapX * 4)^,
         Pointer(NativeUint(wData) + I * fWidthPOT * 4)^, fMapX * 4);

  TRender.UpdateTexture(fMapTex.Tex, fWidthPOT, fHeightPOT, tfRGBA8, wData);
  FreeMem(wData);
end;


procedure TKMMinimap.SaveToStream(SaveStream: TKMemoryStream);
var
  L: Cardinal;
  I: Integer;
begin
  SaveStream.PlaceMarker('Minimap');

  SaveStream.Write(fMapX);
  SaveStream.Write(fMapY);
  L := Length(fBase);
  SaveStream.Write(L);
  if L > 0 then
    SaveStream.Write(fBase[0], L * SizeOf(Cardinal));
  for I := 0 to MAX_HANDS - 1 do
  begin
    SaveStream.Write(HandColors[I]);
    SaveStream.Write(HandLocs[I]);
    SaveStream.Write(HandShow[I]);
  end;
end;


procedure TKMMinimap.LoadFromStream(LoadStream: TKMemoryStream);
var
  L: Cardinal;
  I: Integer;
begin
  LoadStream.CheckMarker('Minimap');

  LoadStream.Read(fMapX);
  LoadStream.Read(fMapY);
  LoadStream.Read(L);
  SetLength(fBase, L);
  if L > 0 then
    LoadStream.Read(fBase[0], L * SizeOf(Cardinal));
  for I := 0 to MAX_HANDS - 1 do
  begin
    LoadStream.Read(HandColors[I]);
    LoadStream.Read(HandLocs[I]);
    LoadStream.Read(HandShow[I]);
  end;

  //Resize will update UV bounds. Resizing fBase is ok since the size does not changes
  Resize(fMapX, fMapY);

  if fMapX * fMapY = 0 then Exit;

  if fSepia then ApplySepia;
  UpdateTexture;
end;


end.
