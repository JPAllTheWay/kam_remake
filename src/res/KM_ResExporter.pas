unit KM_ResExporter;
{$I KaM_Remake.inc}
interface
uses
  SysUtils, Classes,
  Generics.Collections,
  KM_ResSprites, KM_ResTypes,
  KM_WorkerThread,
  KM_Defaults;


type
  TKMAnimKind = (akNormal, akInterpolated);

  TKMPrepGFXDataID = record
    AtlasType: TKMSpriteAtlasType;
    AtlasID: Integer;
    SpriteNum: Integer; // In the atlas
    constructor New(aAtlasType: TKMSpriteAtlasType; aAtlasID, aSpriteNum: Integer);
  end;

  // Resource exporter class
  TKMResExporter = class
  private
    fExportWorkerHolder: TKMWorkerThreadHolder;

    fGFXPrepDataBySpriteID: TDictionary<Integer, TKMPrepGFXDataID>;
    fGFXPrepMaskDataBySpriteID: TDictionary<Integer, TKMPrepGFXDataID>;

    procedure PrepareGFXPrepData(aSpritePack: TKMSpritePack);

    function GetOrCreateExportWorker: TKMWorkerThread;

    procedure ExportImageFromGFXData(aSpritePack: TKMSpritePack; aSpriteID: Integer; const aFilePath: string; const aFileMaskPath: string = '');
    procedure ExportFullImageDataFromGFXData(aSpritePack: TKMSpritePack; aSpriteID: Integer; const aFolder: string; aTempList: TStringList = nil);
  public
    constructor Create;
    destructor Destroy; override;

    procedure ExportHDTreeAnim(aOnDone: TProc<String> = nil);
    procedure ExportTreeAnim(aOnDone: TProc<String> = nil);
    procedure ExportHDHouseAnim(aOnDone: TProc<String> = nil);
    procedure ExportHouseAnim(aOnDone: TProc<String> = nil);
    procedure ExportHDUnitAnim(aUnitFrom, aUnitTo: TKMUnitType; aExportThoughts, aExportUnused: Boolean; aOnDone: TProc<String> = nil);
    procedure ExportUnitAnim(aUnitFrom, aUnitTo: TKMUnitType; aExportUnused: Boolean = False; aOnDone: TProc<String> = nil);
    procedure ExportSpritesFromRXXToPNG(aRT: TRXType; aOnDone: TProc<String> = nil);
    procedure ExportSpritesFromRXAToPNG(aRT: TRXType; aOnDone: TProc<String> = nil);
  end;

var
  gResExporter: TKMResExporter;


implementation
uses
  TypInfo,
  KromUtils,
  KM_Resource, KM_ResUnits, KM_ResHouses, KM_ResMapElements, KM_ResWares, KM_ResTexts, KM_ResInterpolation,
  KM_IoPNG,
  KM_Points, KM_CommonTypes, KM_Log;



{ TKMResExporter }
constructor TKMResExporter.Create;
begin
  inherited;

  fGFXPrepDataBySpriteID := TDictionary<Integer, TKMPrepGFXDataID>.Create;
  fGFXPrepMaskDataBySpriteID := TDictionary<Integer, TKMPrepGFXDataID>.Create;
end;


destructor TKMResExporter.Destroy;
begin
  if fExportWorkerHolder <> nil then
    //This will ensure all queued work is completed before destruction
    FreeAndNil(fExportWorkerHolder);

  fGFXPrepDataBySpriteID.Free;
  fGFXPrepMaskDataBySpriteID.Free;

  inherited;
end;


function TKMResExporter.GetOrCreateExportWorker: TKMWorkerThread;
begin
  if fExportWorkerHolder = nil then
    fExportWorkerHolder := TKMWorkerThreadHolder.Create('ExportWorker');

  Result := fExportWorkerHolder.Worker;
end;


procedure TKMResExporter.PrepareGFXPrepData(aSpritePack: TKMSpritePack);
var
  I, K: Integer;
  SAT: TKMSpriteAtlasType;
begin
  fGFXPrepDataBySpriteID.Clear;
  fGFXPrepMaskDataBySpriteID.Clear;

  // Map spriteID to loaded from RXA GFXPrepData
  for SAT := Low(TKMSpriteAtlasType) to High(TKMSpriteAtlasType) do
    for I := Low(aSpritePack.GFXPrepData[SAT]) to High(aSpritePack.GFXPrepData[SAT]) do
      with aSpritePack.GFXPrepData[SAT, I] do
        for K := 0 to High(SpriteInfo.Sprites) do
          case SAT of
            saBase: fGFXPrepDataBySpriteID.Add(SpriteInfo.Sprites[K].SpriteID, TKMPrepGFXDataID.New(SAT, I, K));
            saMask: fGFXPrepMaskDataBySpriteID.Add(SpriteInfo.Sprites[K].SpriteID, TKMPrepGFXDataID.New(SAT, I, K));
          end;
end;


procedure TKMResExporter.ExportSpritesFromRXXToPNG(aRT: TRXType; aOnDone: TProc<String> = nil);
begin
  // Make sure we loaded all of the resources (to avoid collisions with async res loader
  gRes.LoadGameResources(True);
  GetOrCreateExportWorker.QueueWork(procedure
    var
      sprites: TKMResSprites;
    begin
      sprites := TKMResSprites.Create(nil, nil, True);
      try
        if sprites.LoadSprites(aRT, False) then
          sprites[aRT].ExportAllSpritesFromRXData(ExeDir + 'Export' + PathDelim + RXInfo[aRT].FileName + '.rxx' + PathDelim);
      finally
        sprites.ClearTemp;
        sprites.Free;
      end;
    end, aOnDone, 'Export ' + GetEnumName(TypeInfo(TRXType), Integer(aRT)) + 'from ' + RXInfo[aRT].FileName + '.rxx');
end;


procedure TKMResExporter.ExportSpritesFromRXAToPNG(aRT: TRXType; aOnDone: TProc<String> = nil);
begin
  // Make sure we loaded all of the resources (to avoid collisions with async res loader
  gRes.LoadGameResources(True);
  GetOrCreateExportWorker.QueueWork(procedure
    var
      I: Integer;
      folderPath: string;
      sprites: TKMResSprites;
      spritePack: TKMSpritePack;
      SL: TStringList;
    begin
      sprites := TKMResSprites.Create(nil, nil, True);
      SL := TStringList.Create;
      try
        if sprites.LoadRXASprites(aRT) then
        begin
          spritePack := sprites[aRT];

          PrepareGFXPrepData(spritePack);
          
          folderPath := ExeDir + 'Export' + PathDelim + RXInfo[aRT].FileName + '.rxa' + PathDelim;
          ForceDirectories(folderPath);
          for I := 1 to spritePack.RXData.Count do
            ExportFullImageDataFromGFXData(spritePack, I, folderPath, SL);
        end;
      finally
        sprites.ClearTemp;
        sprites.Free;
        SL.Free;
      end;
    end, aOnDone, 'Export ' + GetEnumName(TypeInfo(TRXType), Integer(aRT)) + 'from ' + RXInfo[aRT].FileName + '.rxa');
end;


procedure TKMResExporter.ExportHDUnitAnim(aUnitFrom, aUnitTo: TKMUnitType; aExportThoughts, aExportUnused: Boolean; aOnDone: TProc<String> = nil);
begin
  // Make sure we loaded all of the resources (to avoid collisions with async res loader
  gRes.LoadGameResources(True);

  // Asynchroniously export data
  GetOrCreateExportWorker.QueueWork(procedure
    var
      fullFolderPath, folderPath: string;
      UT: TKMUnitType;
      ACT: TKMUnitActionType;
      anim: TKMAnimLoop;
      DIR: TKMDirection;
      WT: TKMWareType;
      TH: TKMUnitThought;
      LVL, STEP, origSpriteID, spriteID: Integer;
      used: array of Boolean;
      spritePack: TKMSpritePack;
      sList: TStringList;
      folderCreated: Boolean;
      sprites: TKMResSprites;
      units: TKMResUnits;
      resTexts: TKMTextLibraryMulti;
    begin

      sprites := TKMResSprites.Create(nil, nil, True);
      sprites.LoadRXASprites(rxUnits);
      spritePack := sprites[rxUnits];

      PrepareGFXPrepData(spritePack);

      units := TKMResUnits.Create;
      resTexts := TKMTextLibraryMulti.Create;
      resTexts.LoadLocale(ExeDir + 'data' + PathDelim + 'text' + PathDelim + 'text.%s.libx');
      resTexts.ForceDefaultLocale := True;

      folderPath := ExeDir + 'Export' + PathDelim + 'UnitAnimHD' + PathDelim;
      ForceDirectories(folderPath);

      sList := TStringList.Create;
      try
        for UT := aUnitFrom to aUnitTo do
          for ACT := Low(TKMUnitActionType) to High(TKMUnitActionType) do
          begin
            folderCreated := False;
            for DIR := dirN to dirNW do
              if units[UT].UnitAnim[ACT,DIR].Step[1] <> -1 then
                for STEP := 0 to units[UT].UnitAnim[ACT, DIR].Count - 1 do
                begin
                  origSpriteID := units[UT].UnitAnim[ACT,DIR].Step[STEP+1] + 1;
                  if origSpriteID = 0 then Continue;

                  if not folderCreated then
                  begin
                    //Use default locale for Unit GUIName, as translation could be not good for file system
                    fullFolderPath := folderPath + resTexts.DefaultTexts[units[UT].GUITextID] + PathDelim + UNIT_ACT_STR[ACT] + PathDelim;
                    ForceDirectories(fullFolderPath);
                    folderCreated := True;
                  end;

                  for LVL := 0 to INTERP_LEVEL - 1 do
                  begin
                    spriteID := gRes.Interpolation.UnitAction(UT, ACT, DIR, STEP, LVL / INTERP_LEVEL);
                    ExportFullImageDataFromGFXData(spritePack, spriteID, fullFolderPath, SList);

                    // Stop export if async thread is terminated by application
                    if TThread.CheckTerminated then Exit;
                  end;
                end;
          end;

        SetLength(used, Length(spritePack.RXData.Size));

        //Exclude actions
        for UT := Low(TKMUnitType) to High(TKMUnitType) do
          for ACT := Low(TKMUnitActionType) to High(TKMUnitActionType) do
            for DIR := dirN to dirNW do
              if units[UT].UnitAnim[ACT,DIR].Step[1] <> -1 then
                for STEP := 0 to units[UT].UnitAnim[ACT,DIR].Count - 1 do
                  for LVL := 0 to INTERP_LEVEL - 1 do
                  begin
                    spriteID := gRes.Interpolation.UnitAction(UT, ACT, DIR, STEP, LVL / INTERP_LEVEL);
                    used[spriteID] := spriteID <> 0;
                  end;

        if utSerf in [aUnitFrom..aUnitTo] then
          //serfs carrying stuff
          for WT := WARE_MIN to WARE_MAX do
          begin
            folderCreated := False;
            for DIR := dirN to dirNW do
            begin
              anim := units.SerfCarry[WT, DIR];
              for STEP := 0 to anim.Count - 1 do
              begin
                origSpriteID := anim.Step[STEP+1]+1;
                if origSpriteID = 0 then Continue;
              
                if utSerf in [aUnitFrom..aUnitTo] then
                begin
                  if not folderCreated then
                  begin
                    //Use default locale for Unit GUIName, as translation could be not good for file system
                    fullFolderPath := folderPath + resTexts.DefaultTexts[units[utSerf].GUITextID] + PathDelim + 'Delivery' + PathDelim
                                    + GetEnumName(TypeInfo(TKMWareType), Integer(WT)) + PathDelim;
                    ForceDirectories(fullFolderPath);
                    folderCreated := True;
                  end;
                
                  for LVL := 0 to INTERP_LEVEL - 1 do
                  begin
                    spriteID := gRes.Interpolation.SerfCarry(WT, DIR, STEP, LVL / INTERP_LEVEL);
                    ExportFullImageDataFromGFXData(spritePack, spriteID, fullFolderPath, SList);

                    used[spriteID] := True;

                    // Stop export if async thread is terminated by application
                    if TThread.CheckTerminated then Exit;
                  end;
                end;
              end;
            end;
          end;

        if aExportThoughts then
        begin
          for TH := thEat to High(TKMUnitThought) do
          begin
            fullFolderPath := folderPath + 'Thoughts' + PathDelim + GetEnumName(TypeInfo(TKMUnitThought), Integer(TH)) + PathDelim;
            ForceDirectories(fullFolderPath);

            for STEP := THOUGHT_BOUNDS[TH,1] to  THOUGHT_BOUNDS[TH,2] do
              for LVL := 0 to INTERP_LEVEL - 1 do
              begin
                spriteID := gRes.Interpolation.UnitThought(TH, STEP, LVL / INTERP_LEVEL);
                ExportFullImageDataFromGFXData(spritePack, spriteID, fullFolderPath, SList);
                used[spriteID] := True;
              end;
          end;
        end;

        if not aExportUnused then Exit;

        fullFolderPath := folderPath + '_Unused' + PathDelim;
        ForceDirectories(fullFolderPath);

        for spriteID := 1 to Length(used)-1 do
          if not used[spriteID] then
          begin
            ExportFullImageDataFromGFXData(spritePack, spriteID, fullFolderPath, SList);
            // Stop export if async thread is terminated by application
            if TThread.CheckTerminated then Exit;
          end;
      finally
        sprites.ClearTemp;
        sprites.Free;
        units.Free;
        resTexts.Free;
        sList.Free;
      end;
    end, aOnDone, 'Export HD units anim');
end;


//Export Units graphics categorized by Unit and Action
procedure TKMResExporter.ExportUnitAnim(aUnitFrom, aUnitTo: TKMUnitType; aExportUnused: Boolean = False; aOnDone: TProc<String> = nil);
begin
  // Make sure we loaded all of the resources (to avoid collisions with async res loader
  gRes.LoadGameResources(True);
  // Asynchroniously export data
  GetOrCreateExportWorker.QueueWork(procedure
    var
      fullFolderPath, folderPath: string;
      UT: TKMUnitType;
      ACT: TKMUnitActionType;
      anim: TKMAnimLoop;
      DIR: TKMDirection;
      R: TKMWareType;
      T: TKMUnitThought;
      STEP, spriteID:integer;
      used: array of Boolean;
      rxData: TRXData;
      spritePack: TKMSpritePack;
      sList: TStringList;
      folderCreated: Boolean;
      sprites: TKMResSprites;
      units: TKMResUnits;
      resTexts: TKMTextLibraryMulti;
    begin

    sprites := TKMResSprites.Create(nil, nil, True);
    sprites.LoadSprites(rxUnits, False); //BMP can't show alpha shadows anyways
    spritePack := sprites[rxUnits];
    rxData := spritePack.RXData;

    units := TKMResUnits.Create;
    resTexts := TKMTextLibraryMulti.Create;
    resTexts.LoadLocale(ExeDir + 'data' + PathDelim + 'text' + PathDelim + 'text.%s.libx');
    resTexts.ForceDefaultLocale := True;

    folderPath := ExeDir + 'Export' + PathDelim + 'UnitAnim' + PathDelim;
    ForceDirectories(folderPath);

    sList := TStringList.Create;
    try
      for UT := aUnitFrom to aUnitTo do
        for ACT := Low(TKMUnitActionType) to High(TKMUnitActionType) do
        begin
          folderCreated := False;
          for DIR := dirN to dirNW do
            if units[UT].UnitAnim[ACT,DIR].Step[1] <> -1 then
              for STEP := 1 to units[UT].UnitAnim[ACT, DIR].Count do
              begin
                spriteID := units[UT].UnitAnim[ACT,DIR].Step[STEP] + 1;
                if spriteID = 0 then Continue;

                if not folderCreated then
                begin
                  //Use default locale for Unit GUIName, as translation could be not good for file system
                  fullFolderPath := folderPath + resTexts.DefaultTexts[units[UT].GUITextID] + PathDelim + UNIT_ACT_STR[ACT] + PathDelim;
                  ForceDirectories(fullFolderPath);
                  folderCreated := True;
                end;
                spritePack.ExportFullImageData(fullFolderPath, spriteID, sList);
                // Stop export if async thread is terminated by application
                if TThread.CheckTerminated then Exit;
              end;
        end;

      SetLength(used, Length(rxData.Size));

      //Exclude actions
      for UT := Low(TKMUnitType) to High(TKMUnitType) do
        for ACT := Low(TKMUnitActionType) to High(TKMUnitActionType) do
          for DIR := dirN to dirNW do
            if units[UT].UnitAnim[ACT,DIR].Step[1] <> -1 then
              for STEP := 1 to units[UT].UnitAnim[ACT,DIR].Count do
              begin
                spriteID := units[UT].UnitAnim[ACT,DIR].Step[STEP]+1;
                used[spriteID] := spriteID <> 0;
              end;

      if utSerf in [aUnitFrom..aUnitTo] then
        //serfs carrying stuff
        for R := WARE_MIN to WARE_MAX do
        begin
          folderCreated := False;
          for DIR := dirN to dirNW do
          begin
            anim := units.SerfCarry[R, DIR];
            for STEP := 1 to anim.Count do
            begin
              spriteID := anim.Step[STEP]+1;
              if spriteID <> 0 then
              begin
                used[spriteID] := True;
                if utSerf in [aUnitFrom..aUnitTo] then
                begin
                  if not folderCreated then
                  begin
                    //Use default locale for Unit GUIName, as translation could be not good for file system (like russian '����������/�������' with slash in it)
                    fullFolderPath := folderPath + resTexts.DefaultTexts[units[utSerf].GUITextID] + PathDelim + 'Delivery' + PathDelim
                                    + GetEnumName(TypeInfo(TKMWareType), Integer(R)) + PathDelim;
                    ForceDirectories(fullFolderPath);
                    folderCreated := True;
                  end;
                  spritePack.ExportFullImageData(fullFolderPath, spriteID, sList);
                  // Stop export if async thread is terminated by application
                  if TThread.CheckTerminated then Exit;
                end;
              end;
            end;
          end;
        end;

      fullFolderPath := folderPath + 'Thoughts' + PathDelim;
      ForceDirectories(fullFolderPath);
      for T := thEat to High(TKMUnitThought) do
        for STEP := THOUGHT_BOUNDS[T,1] to  THOUGHT_BOUNDS[T,2] do
        begin
          spritePack.ExportFullImageData(fullFolderPath, STEP+1, sList);
          used[STEP+1] := True;
        end;

      if not aExportUnused then Exit;

      fullFolderPath := folderPath + '_Unused' + PathDelim;
      ForceDirectories(fullFolderPath);

      for spriteID := 1 to Length(used)-1 do
        if not used[spriteID] then
        begin
          spritePack.ExportFullImageData(fullFolderPath, spriteID, sList);
          // Stop export if async thread is terminated by application
          if TThread.CheckTerminated then Exit;
        end;
    finally
      sprites.ClearTemp;
      sprites.Free;
      units.Free;
      resTexts.Free;
      sList.Free;
    end;
  end, aOnDone, 'Export units anim');
end;


procedure TKMResExporter.ExportHDHouseAnim(aOnDone: TProc<String> = nil);
begin
  // Make sure we loaded all of the resources (to avoid collisions with async res loader
  gRes.LoadGameResources(True);
  // Asynchroniously export data
  GetOrCreateExportWorker.QueueWork(procedure
    var
      fullFolderPath, folderPath: string;
      I, LVL, STEP, Q, spriteID: Integer;
      beast, origSpriteID: Integer;
      HT: TKMHouseType;
      ACT: TKMHouseActionType;
      sprites: TKMResSprites;
      spritePack: TKMSpritePack;
      sList: TStringList;
      houses: TKMResHouses;
      resTexts: TKMTextLibraryMulti;
    begin
      sprites := TKMResSprites.Create(nil, nil, True);
      sprites.LoadRXASprites(rxHouses);
      spritePack := sprites[rxHouses];

      folderPath := ExeDir + 'Export' + PathDelim + 'HouseAnimHD' + PathDelim;
      ForceDirectories(folderPath);

      sList := TStringList.Create;
      houses := TKMResHouses.Create;

      resTexts := TKMTextLibraryMulti.Create;
      resTexts.LoadLocale(ExeDir + 'data' + PathDelim + 'text' + PathDelim + 'text.%s.libx');
      resTexts.ForceDefaultLocale := True;

      PrepareGFXPrepData(spritePack);

      try
        for HT := HOUSE_MIN to HOUSE_MAX do
          for ACT := haWork1 to haFlag3 do
          begin
            if houses[HT].Anim[ACT].Count = 0 then Continue;

            fullFolderPath := folderPath + resTexts.DefaultTexts[houses[HT].HouseNameTextID] + PathDelim +
                                HOUSE_ACTION_STR[ACT] + PathDelim;
            ForceDirectories(fullFolderPath);                      
            
            for STEP := 0 to houses[HT].Anim[ACT].Count - 1 do
            begin                
              origSpriteID := houses[HT].Anim[ACT].Step[STEP+1] + 1;
              if origSpriteID = 0 then Continue;
              for LVL := 0 to INTERP_LEVEL - 1 do
              begin
                spriteID := gRes.Interpolation.House(HT, ACT, STEP, LVL / INTERP_LEVEL);
                ExportFullImageDataFromGFXData(spritePack, spriteID, fullFolderPath, SList);
                
                // Stop export if async thread is terminated by application
                if TThread.CheckTerminated then Exit;
              end;
            end;
          end;

        for Q := 1 to 2 do
        begin
          if Q = 1 then
            HT := htSwine
          else
            HT := htStables;
            
          for beast := 1 to 5 do
            for I := 1 to 3 do
            begin
              if houses.BeastAnim[HT,beast,I].Count = 0 then Continue;

              fullFolderPath := folderPath + resTexts.DefaultTexts[houses[HT].HouseNameTextID] + PathDelim + 'Beast' + PathDelim + 
                                int2fix(beast,2) + PathDelim;
              ForceDirectories(fullFolderPath);
              
              for STEP := 0 to houses.BeastAnim[HT,beast,I].Count - 1 do
              begin
                origSpriteID := houses.BeastAnim[HT,beast,I].Step[STEP+1]+1;
                if origSpriteID = 0 then Continue;
                for LVL := 0 to INTERP_LEVEL - 1 do
                begin
                  spriteID := gRes.Interpolation.Beast(HT, beast, I, STEP, LVL / INTERP_LEVEL);
                  ExportFullImageDataFromGFXData(spritePack, spriteID, fullFolderPath, SList);

                  // Stop export if async thread is terminated by application
                  if TThread.CheckTerminated then Exit;
                end;
              end;
            end;
        end;
      finally
        resTexts.Free;
        houses.Free;
        sprites.ClearTemp;
        sprites.Free;
        sList.Free;
      end;
    end, aOnDone, 'Export HD House animation');
end;


//Export Houses graphics categorized by House and Action
procedure TKMResExporter.ExportHouseAnim(aOnDone: TProc<String> = nil);
begin
  // Make sure we loaded all of the resources (to avoid collisions with async res loader
  gRes.LoadGameResources(True);
  // Asynchroniously export data
  GetOrCreateExportWorker.QueueWork(procedure
  var
    fullFolderPath, folderPath: string;
    houses: TKMResHouses;
    HT: TKMHouseType;
    ACT: TKMHouseActionType;
    Q, beast, I, K, origSpriteID: Integer;
    spritePack: TKMSpritePack;
    SList: TStringList;

    sprites: TKMResSprites;
    resTexts: TKMTextLibraryMulti;
  begin
    sprites := TKMResSprites.Create(nil, nil, True);
    sprites.LoadSprites(rxHouses, False); //BMP can't show alpha shadows anyways
    spritePack := sprites[rxHouses];

    folderPath := ExeDir + 'Export' + PathDelim + 'HouseAnim' + PathDelim;
    ForceDirectories(folderPath);

    SList := TStringList.Create;
    houses := TKMResHouses.Create;

    resTexts := TKMTextLibraryMulti.Create;
    resTexts.LoadLocale(ExeDir + 'data' + PathDelim + 'text' + PathDelim + 'text.%s.libx');
    resTexts.ForceDefaultLocale := True;
    try
      for HT := HOUSE_MIN to HOUSE_MAX do
        for ACT := haWork1 to haFlag3 do
        begin
          if houses[HT].Anim[ACT].Count = 0 then Continue;
          
          fullFolderPath := folderPath + resTexts.DefaultTexts[houses[HT].HouseNameTextID] + PathDelim + HOUSE_ACTION_STR[ACT] + PathDelim;
          ForceDirectories(fullFolderPath);
          for K := 1 to houses[HT].Anim[ACT].Count do
          begin                                      
            origSpriteID := houses[HT].Anim[ACT].Step[K] + 1;
            if origSpriteID <> 0 then
              spritePack.ExportFullImageData(fullFolderPath, origSpriteID, SList);
            // Stop export if async thread is terminated by application
            if TThread.CheckTerminated then Exit;
          end;
        end;

      for Q := 1 to 2 do
      begin
        if Q = 1 then
          HT := htSwine
        else
          HT := htStables;
          
        for beast := 1 to 5 do
          for I := 1 to 3 do
          begin
            if houses.BeastAnim[HT,beast,I].Count = 0 then Continue;

            fullFolderPath := folderPath + resTexts.DefaultTexts[houses[HT].HouseNameTextID] + PathDelim + 'Beast' + PathDelim + int2fix(beast,2) + PathDelim;
            ForceDirectories(fullFolderPath);
            
            for K := 1 to houses.BeastAnim[HT,beast,I].Count do
            begin
              origSpriteID := houses.BeastAnim[HT,beast,I].Step[K]+1;
              if origSpriteID <> 0 then
                spritePack.ExportFullImageData(fullFolderPath, origSpriteID, SList);
              // Stop export if async thread is terminated by application
              if TThread.CheckTerminated then Exit;
            end;
          end;
      end;
    finally
      resTexts.Free;
      houses.Free;
      SList.Free;
      sprites.ClearTemp;
      sprites.Free;
    end;
  end, aOnDone, 'Export house anim');
end;


procedure TKMResExporter.ExportImageFromGFXData(aSpritePack: TKMSpritePack; aSpriteID: Integer; const aFilePath: string; const aFileMaskPath: string = '');
var
  P, Q, dataX, dataY: Integer;
  pngWidth, pngHeight: Word;
  pngData: TKMCardinalArray;
  prepGFXDataID: TKMPrepGFXDataID;
begin
  pngWidth := aSpritePack.RXData.Size[aSpriteID].X;//fGFXData[aSpritePack.RT, aSpriteID].PxWidth;
  pngHeight := aSpritePack.RXData.Size[aSpriteID].Y;//fGFXData[aSpritePack.RT, aSpriteID].PxHeight;

  SetLength(pngData, pngWidth * pngHeight);

  //Export RGB values
  if fGFXPrepDataBySpriteID.TryGetValue(aSpriteID, prepGFXDataID) then
    with aSpritePack.GFXPrepData[prepGFXDataID.AtlasType, prepGFXDataID.AtlasID] do
    begin
      for P := 0 to pngHeight - 1 do
        for Q := 0 to pngWidth - 1 do
        begin
          dataX := SpriteInfo.Sprites[prepGFXDataID.SpriteNum].PosX + Q;
          dataY := SpriteInfo.Sprites[prepGFXDataID.SpriteNum].PosY + P;

          pngData[P*pngWidth + Q] := Data[dataY*SpriteInfo.Width + dataX] and $FFFFFF;
          pngData[P*pngWidth + Q] := pngData[P*pngWidth + Q] or (Data[dataY*SpriteInfo.Width + dataX] and $FF000000);
        end;

      SaveToPng(pngWidth, pngHeight, pngData, aFilePath);
    end;

  if (aFileMaskPath <> '') and fGFXPrepMaskDataBySpriteID.TryGetValue(aSpriteID, prepGFXDataID) then
    with aSpritePack.GFXPrepData[prepGFXDataID.AtlasType, prepGFXDataID.AtlasID] do
    begin
      for P := 0 to pngHeight - 1 do
        for Q := 0 to pngWidth - 1 do
        begin
          dataX := SpriteInfo.Sprites[prepGFXDataID.SpriteNum].PosX + Q;
          dataY := SpriteInfo.Sprites[prepGFXDataID.SpriteNum].PosY + P;

          pngData[P*pngWidth + Q] := Data[dataY*SpriteInfo.Width + dataX] and $FFFFFF;
          pngData[P*pngWidth + Q] := pngData[P*pngWidth + Q] or (Data[dataY*SpriteInfo.Width + dataX] and $FF000000);
        end;

      SaveToPng(pngWidth, pngHeight, pngData, aFileMaskPath);
    end;
end;


procedure TKMResExporter.ExportFullImageDataFromGFXData(aSpritePack: TKMSpritePack; aSpriteID: Integer; const aFolder: string; aTempList: TStringList = nil);
var
  listCreated: Boolean;
begin
  listCreated := False;
  if aTempList = nil then
  begin
    aTempList := TStringList.Create;
    listCreated := True;
  end;

  if aSpritePack.RXData.Flag[aSpriteID] = 1 then
  begin
    ExportImageFromGFXData(aSpritePack, aSpriteID, aFolder + Format('%d_%.4d.png', [Byte(aSpritePack.RT)+1, aSpriteID]),
                                                   aFolder + Format('%d_%.4da.png', [Byte(aSpritePack.RT)+1, aSpriteID]));

//    if aSpritePack.RXData.HasMask[aIndex] then
//      ExportMask(aFolder + Format('%d_%.4da.png', [Byte(fRT)+1, aIndex]), aIndex);

    //Export pivot
    aTempList.Clear;
    aTempList.Append(IntToStr(aSpritePack.RXData.Pivot[aSpriteID].x));
    aTempList.Append(IntToStr(aSpritePack.RXData.Pivot[aSpriteID].y));
    //SizeNoShadow is used only for Units
    if aSpritePack.RT = rxUnits then
    begin
      aTempList.Append(IntToStr(aSpritePack.RXData.SizeNoShadow[aSpriteID].left));
      aTempList.Append(IntToStr(aSpritePack.RXData.SizeNoShadow[aSpriteID].top));
      aTempList.Append(IntToStr(aSpritePack.RXData.SizeNoShadow[aSpriteID].right));
      aTempList.Append(IntToStr(aSpritePack.RXData.SizeNoShadow[aSpriteID].bottom));
    end;
    aTempList.SaveToFile(aFolder + Format('%d_%.4d.txt', [Byte(aSpritePack.RT)+1, aSpriteID]));
  end;

  if listCreated then
    aTempList.Free;
end;


procedure TKMResExporter.ExportHDTreeAnim(aOnDone: TProc<String> = nil);
begin
  // Make sure we loaded all of the resources (to avoid collisions with async res loader
  gRes.LoadGameResources(True);
  // Asynchroniously export data
  GetOrCreateExportWorker.QueueWork(procedure
    var
      fullFolderPath, folderPath: string;
      I, J, K, spriteID: Integer;
      sprites: TKMResSprites;
      spritePack: TKMSpritePack;
      sList: TStringList;
    begin
      sprites := TKMResSprites.Create(nil, nil, True);
      sprites.LoadRXASprites(rxTrees);
      spritePack := sprites[rxTrees];

      folderPath := ExeDir + 'Export' + PathDelim + 'TreeAnimHD' + PathDelim;
      ForceDirectories(folderPath);

      sList := TStringList.Create;

      PrepareGFXPrepData(spritePack);

      try
        for I := 0 to gRes.MapElements.Count - 1 do
          if (gMapElements[I].Anim.Count > 0) and (gMapElements[I].Anim.Step[1] > 0) then
            for J := 0 to gMapElements[I].Anim.Count - 1 do
              for K := 0 to INTERP_LEVEL - 1 do
              begin
                spriteID := gRes.Interpolation.Tree(I, J, K / INTERP_LEVEL, True);
                if spriteID <> 0 then
                begin
                  if gMapElements[I].Anim.Count > 1 then
                  begin
                    fullFolderPath := folderPath + IntToStr(I) + PathDelim + IntToStr(J) + PathDelim;
                    ForceDirectories(fullFolderPath);
                  end else
                    fullFolderPath := folderPath;

                  ExportFullImageDataFromGFXData(spritePack, spriteID, fullFolderPath, sList);
                end;

                // Stop export if async thread is terminated by application
                if TThread.CheckTerminated then Exit;
              end;
      finally
        sprites.ClearTemp;
        sprites.Free;
        sList.Free;
      end;
    end, aOnDone, 'Export HD Tree animation');
end;


//Export Trees graphics categorized by ID
procedure TKMResExporter.ExportTreeAnim(aOnDone: TProc<String> = nil);
begin
  // Make sure we loaded all of the resources (to avoid collisions with async res loader
  gRes.LoadGameResources(True);
  // Asynchroniously export data
  GetOrCreateExportWorker.QueueWork(procedure
    var
      fullFolderPath, folderPath: string;
      I, K, spriteID: Integer;
      sprites: TKMResSprites;
      spritePack: TKMSpritePack;
      sList: TStringList;
    begin
      sprites := TKMResSprites.Create(nil, nil, True);
      sprites.LoadSprites(rxTrees, False);
      spritePack := sprites[rxTrees];

      folderPath := ExeDir + 'Export' + PathDelim + 'TreeAnim' + PathDelim;
      ForceDirectories(folderPath);

      sList := TStringList.Create;

      try
        for I := 0 to gRes.MapElements.Count - 1 do
        if (gMapElements[I].Anim.Count > 0) and (gMapElements[I].Anim.Step[1] > 0) then
        begin
          for K := 1 to gMapElements[I].Anim.Count do
          begin
            spriteID := gMapElements[I].Anim.Step[K] + 1;
            if spriteID <> 0 then
            begin
              if gMapElements[I].Anim.Count > 1 then
              begin
                fullFolderPath := folderPath + IntToStr(I) + PathDelim;
                ForceDirectories(fullFolderPath);
              end else
                fullFolderPath := folderPath;
                
              spritePack.ExportFullImageData(fullFolderPath, spriteID, sList);
              // Stop export if async thread is terminated by application
              if TThread.CheckTerminated then Exit;
            end;
          end;
        end;
      finally
        sprites.ClearTemp;
        sprites.Free;
        sList.Free;
      end;
    end, aOnDone, 'Export tree anim');
end;

{ TKMPrepDataID }
constructor TKMPrepGFXDataID.New(aAtlasType: TKMSpriteAtlasType; aAtlasID, aSpriteNum: Integer);
begin
  AtlasType := aAtlasType;
  AtlasID := aAtlasID;
  SpriteNum := aSpriteNum;
end;


end.
