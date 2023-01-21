unit RXXPackerProc;
{$I ..\..\KaM_Remake.inc}
interface
uses
  SysUtils, KM_ResTypes, KM_ResPalettes;


type
  TKMRXXPacker = class
  private
    fSpritesSourcePath: string;
    fRXXSavePath: string;

    procedure SetSpritesSourcePath(const aValue: string);
    procedure SetRXXSavePath(const aValue: string);
  public
    PackToRXX: Boolean;
    PackToRXA: Boolean;
    AddVersionHeader: Boolean;

    constructor Create(const aSpritesBaseDir: string);

    property SpritesSourcePath: string read fSpritesSourcePath write SetSpritesSourcePath;
    property RXXSavePath: string read fRXXSavePath write SetRXXSavePath;

    procedure Pack(RT: TRXType; fPalettes: TKMResPalettes);
  end;


const
  SPRITES_RES_DIR = 'SpriteResource';
  SPRITES_INTERP_DIR = 'SpriteInterp' + PathDelim + 'Output';


implementation
uses
  KM_ResHouses, KM_ResUnits, KM_ResSprites, KM_Points, KM_ResSpritesEdit, KM_Defaults, KM_Log;


{ TKMRXXPacker }
constructor TKMRXXPacker.Create(const aSpritesBaseDir: string);
begin
  inherited Create;

  SpritesSourcePath := aSpritesBaseDir;

  PackToRXX := True;
  PackToRXA := False;
  AddVersionHeader := True;
end;


procedure TKMRXXPacker.Pack(RT: TRXType; fPalettes: TKMResPalettes);
var
  deathAnimProcessed: array of Integer;
  deathAnimCount: Integer;

  function DeathAnimAlreadyDone(aID: Integer):Boolean;
  var
    I: Integer;
  begin
    Result := False;
    for I := 0 to deathAnimCount - 1 do
      if deathAnimProcessed[I] = aID then
        Exit(True);
  end;

var
  spritePack: TKMSpritePackEdit;
  step, spriteID: Integer;
  rxName: string;
  resHouses: TKMResHouses;
  resUnits: TKMResUnits;
  UT: TKMUnitType;
  dir: TKMDirection;
begin
  //ruCustom sprite packs do not have a main RXX file so don't need packing
  if RXInfo[RT].Usage = ruCustom then Exit;

  rxName := fSpritesSourcePath + SPRITES_RES_DIR + '\' + RXInfo[RT].FileName + '.rx';

  if (RT <> rxTiles) and not FileExists(rxName) then
    raise Exception.Create('Cannot find ' + rxName + ' file.' + sLineBreak + 'Please copy the file from your KaM\data\gfx\res\ folder.');

  spritePack := TKMSpritePackEdit.Create(RT, fPalettes);
  try
    //Load
    if RT <> rxTiles then
    begin
      spritePack.LoadFromRXFile(rxName);
      spritePack.OverloadRXDataFromFolder(fSpritesSourcePath + SPRITES_RES_DIR + '\', False); // Do not soften shadows, it will be done later on
    end
    else
    if DirectoryExists(fSpritesSourcePath + SPRITES_RES_DIR + '\') then
      spritePack.OverloadRXDataFromFolder(fSpritesSourcePath + SPRITES_RES_DIR + '\');

    //Tiles must stay the same size as they can't use pivots
    if (RT <> rxTiles) and (gLog <> nil) then
      gLog.AddTime('Trimmed ' + IntToStr(spritePack.TrimSprites));

    //Houses need some special treatment to adapt to GL_ALPHA_TEST that we use for construction steps
    if RT = rxHouses then
    begin
      resHouses := TKMResHouses.Create;
      spritePack.AdjoinHouseMasks(resHouses);
      spritePack.GrowHouseMasks(resHouses);
      spritePack.RemoveSnowHouseShadows(resHouses);
      spritePack.RemoveMarketWaresShadows(resHouses);
      resHouses.Free;
    end;

    // Determine objects size only for units (used for hitbox)
    //todo: do we need it for houses too ?
    if RT = rxUnits then
      spritePack.DetermineImagesObjectSize;

    //The idea was to blur the water and make it semitrasparent, but it did not worked out as expected
    //if RT = rxTiles then
    //  SpritePack.SoftWater(nil);

    //Save
    if PackToRXX then
      spritePack.SaveToRXXFile(fRXXSavePath + 'data\Sprites\' + RXInfo[RT].FileName + '.rxx', AddVersionHeader);

    //Generate alpha shadows for the following sprite packs
    if RT in [rxHouses,rxUnits,rxGui,rxTrees] then
    begin
      if RT = rxHouses then
      begin
        spritePack.SoftenShadows(889, 892, False); //Smooth smoke
        spritePack.SoftenShadows(1615, 1638, False); //Smooth flame
      end;

      if RT = rxUnits then
      begin
        spritePack.SoftenShadows(6251, 6322, False); //Smooth thought bubbles
        //Smooth all death animations for all units
        resUnits := TKMResUnits.Create;
        deathAnimCount := 0; //We need to remember which ones we've done because units reuse them
        SetLength(deathAnimProcessed, 1000); //Hopefully more than enough
        for UT := HUMANS_MIN to HUMANS_MAX do
          for dir := dirN to dirNW do
            for step := 1 to 30 do
            begin
              spriteID := resUnits[UT].UnitAnim[uaDie,dir].Step[step]+1; //Sprites in units.dat are 0 indexed
              if (spriteID > 0)
              and not DeathAnimAlreadyDone(spriteID) then
              begin
                spritePack.SoftenShadows(spriteID, False);
                deathAnimProcessed[deathAnimCount] := spriteID;
                Inc(deathAnimCount);
              end;
            end;
        resUnits.Free;
      end;

      if RT = rxGui then
      begin
        spritePack.SoftenShadows(105, 128); //Field plans
        spritePack.SoftenShadows(249, 281); //House tablets only (shadow softening messes up other rxGui sprites)
        spritePack.SoftenShadows(461, 468); //Field fences
        spritePack.SoftenShadows(660, 660); //Woodcutter cutting point sign
      end
      else
        spritePack.SoftenShadows;

      if PackToRXX then
        spritePack.SaveToRXXFile(fRXXSavePath + 'data\Sprites\' + RXInfo[RT].FileName + '_a.rxx', AddVersionHeader);

      if PackToRXA then
      begin
        if DirectoryExists(fSpritesSourcePath + SPRITES_INTERP_DIR + '\' + IntToStr(Ord(RT)+1) + '\') then
          spritePack.OverloadRXDataFromFolder(fSpritesSourcePath + SPRITES_INTERP_DIR + '\' + IntToStr(Ord(RT)+1) + '\', False); // Shadows are already softened for interps

        spritePack.SaveToRXAFile(fRXXSavePath + 'data\Sprites\' + RXInfo[RT].FileName + '.rxa', AddVersionHeader);
      end;
    end;
  finally
    spritePack.Free;
  end;
end;


procedure TKMRXXPacker.SetSpritesSourcePath(const aValue: string);
begin
  fSpritesSourcePath := IncludeTrailingPathDelimiter(aValue);
end;


procedure TKMRXXPacker.SetRXXSavePath(const aValue: string);
begin
  fRXXSavePath := IncludeTrailingPathDelimiter(aValue);
end;


end.
