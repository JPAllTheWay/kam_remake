unit KM_ResExporter;
{$I KaM_Remake.inc}
interface
uses
  SysUtils,
  KM_ResTypes,
  KM_WorkerThread,
  KM_Defaults;


type
  // Resource exporter class
  TKMResExporter = class
  private
    fExportWorker: TKMWorkerThread;

    function GetOrCreateExportWorker: TKMWorkerThread;
  public
    destructor Destroy; override;

    procedure ExportTreeAnim(aOnDone: TProc<String> = nil);
    procedure ExportHouseAnim(aOnDone: TProc<String> = nil);
    procedure ExportUnitAnim(aUnitFrom, aUnitTo: TKMUnitType; aExportUnused: Boolean = False; aOnDone: TProc<String> = nil);
    procedure ExportSpritesToPNG(aRT: TRXType; aOnDone: TProc<String> = nil);
  end;

var
  gResExporter: TKMResExporter;


implementation
uses
  Classes, TypInfo,
  KromUtils,
  KM_Resource, KM_ResSprites, KM_ResUnits, KM_ResHouses, KM_ResMapElements, KM_ResWares, KM_ResTexts,
  KM_Points, KM_CommonTypes;


{ TKMResExporter }
destructor TKMResExporter.Destroy;
begin
  if fExportWorker <> nil then
    //This will ensure all queued work is completed before destruction
    FreeAndNil(fExportWorker);

  inherited;
end;


function TKMResExporter.GetOrCreateExportWorker: TKMWorkerThread;
begin
  if fExportWorker = nil then
    fExportWorker := TKMWorkerThread.Create('ExportWorker');

  Result := fExportWorker;
end;


procedure TKMResExporter.ExportSpritesToPNG(aRT: TRXType; aOnDone: TProc<String> = nil);
begin
  GetOrCreateExportWorker.QueueWork(procedure
  var
    sprites: TKMResSprites;
  begin
    sprites := TKMResSprites.Create(nil, nil, True);
    try
      if sprites.LoadSprites(aRT, False) then
      begin
        sprites[aRT].ExportAll(ExeDir + 'Export' + PathDelim + RXInfo[aRT].FileName + '.rx' + PathDelim);
        sprites.ClearTemp;
      end;
    finally
      sprites.Free;
    end;
  end, aOnDone, 'Export ' + GetEnumName(TypeInfo(TRXType), Integer(aRT)));
end;


//Export Units graphics categorized by Unit and Action
procedure TKMResExporter.ExportUnitAnim(aUnitFrom, aUnitTo: TKMUnitType; aExportUnused: Boolean = False; aOnDone: TProc<String> = nil);
begin

  // Asynchroniously export data
  GetOrCreateExportWorker.QueueWork(procedure
    var
      fullFolderPath, folderPath: string;
      U: TKMUnitType;
      A: TKMUnitActionType;
      anim: TKMAnimLoop;
      D: TKMDirection;
      R: TKMWareType;
      T: TKMUnitThought;
      I, K:integer;
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
      for U := aUnitFrom to aUnitTo do
        for A := Low(TKMUnitActionType) to High(TKMUnitActionType) do
        begin
          folderCreated := False;
          for D := dirN to dirNW do
            if units[U].UnitAnim[A,D].Step[1] <> -1 then
              for I := 1 to units[U].UnitAnim[A, D].Count do
              begin
                K := units[U].UnitAnim[A,D].Step[I] + 1;
                if K <> 0 then
                begin
                  if not folderCreated then
                  begin
                    //Use default locale for Unit GUIName, as translation could be not good for file system
                    fullFolderPath := folderPath + resTexts.DefaultTexts[units[U].GUITextID] + PathDelim + UNIT_ACT_STR[A] + PathDelim;
                    ForceDirectories(fullFolderPath);
                    folderCreated := True;
                  end;
                  spritePack.ExportFullImageData(fullFolderPath, K, sList);
                  // Stop export if async thread is terminated by application
                  if TThread.CheckTerminated then
                    Exit;
                end;
              end;
        end;

      SetLength(used, Length(rxData.Size));

      //Exclude actions
      for U := Low(TKMUnitType) to High(TKMUnitType) do
        for A := Low(TKMUnitActionType) to High(TKMUnitActionType) do
          for D := dirN to dirNW do
            if units[U].UnitAnim[A,D].Step[1] <> -1 then
              for I := 1 to units[U].UnitAnim[A,D].Count do
              begin
                K := units[U].UnitAnim[A,D].Step[I]+1;
                used[K] := K <> 0;
              end;

      if utSerf in [aUnitFrom..aUnitTo] then
        //serfs carrying stuff
        for R := WARE_MIN to WARE_MAX do
        begin
          folderCreated := False;
          for D := dirN to dirNW do
          begin
            anim := units.SerfCarry[R, D];
            for I := 1 to anim.Count do
            begin
              K := anim.Step[I]+1;
              if K <> 0 then
              begin
                used[K] := True;
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
                  spritePack.ExportFullImageData(fullFolderPath, K, sList);
                  // Stop export if async thread is terminated by application
                  if TThread.CheckTerminated then
                    Exit;
                end;
              end;
            end;
          end;
        end;

      fullFolderPath := folderPath + 'Thoughts' + PathDelim;
      ForceDirectories(fullFolderPath);
      for T := thEat to High(TKMUnitThought) do
        for I := THOUGHT_BOUNDS[T,1] to  THOUGHT_BOUNDS[T,2] do
        begin
          spritePack.ExportFullImageData(fullFolderPath, I+1, sList);
          used[I+1] := True;
        end;

      if not aExportUnused then Exit;

      fullFolderPath := folderPath + '_Unused' + PathDelim;
      ForceDirectories(fullFolderPath);

      for K := 1 to Length(used)-1 do
        if not used[K] then
        begin
          spritePack.ExportFullImageData(fullFolderPath, K, sList);
          // Stop export if async thread is terminated by application
          if TThread.CheckTerminated then
            Exit;
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


//Export Houses graphics categorized by House and Action
procedure TKMResExporter.ExportHouseAnim(aOnDone: TProc<String> = nil);
begin

  // Asynchroniously export data
  GetOrCreateExportWorker.QueueWork(procedure
  var
    fullFolderPath, folderPath: string;
    houses: TKMResHouses;
    id: TKMHouseType;
    acType: TKMHouseActionType;
    Q, beast, I, K, ci: Integer;
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
      for id := HOUSE_MIN to HOUSE_MAX do
        for acType := haWork1 to haFlag3 do
          for K := 1 to houses[id].Anim[acType].Count do
          begin                                      //HouseNameTextID    resTexts.DefaultTexts
            fullFolderPath := folderPath + resTexts.DefaultTexts[houses[id].HouseNameTextID] + PathDelim + HOUSE_ACTION_STR[acType] + PathDelim;
            ForceDirectories(fullFolderPath);
            ci := houses[id].Anim[acType].Step[K] + 1;
            if ci <> 0 then
              spritePack.ExportFullImageData(fullFolderPath, ci, SList);
            // Stop export if async thread is terminated by application
            if TThread.CheckTerminated then
              Exit;
          end;

      for Q := 1 to 2 do
      begin
        if Q = 1 then
          id := htSwine
        else
          id := htStables;
        ForceDirectories(folderPath + '_' + resTexts.DefaultTexts[houses[id].HouseNameTextID] + PathDelim);
        for beast := 1 to 5 do
          for I := 1 to 3 do
            for K := 1 to houses.BeastAnim[id,beast,I].Count do
            begin
              fullFolderPath := folderPath + resTexts.DefaultTexts[houses[id].HouseNameTextID] + PathDelim + 'Beast' + PathDelim + int2fix(beast,2) + PathDelim;
              ForceDirectories(fullFolderPath);
              ci := houses.BeastAnim[id,beast,I].Step[K]+1;
              if ci <> 0 then
                spritePack.ExportFullImageData(fullFolderPath, ci, SList);
              // Stop export if async thread is terminated by application
              if TThread.CheckTerminated then
                Exit;
            end;
      end;
    finally
      houses.Free;
      SList.Free;
      sprites.ClearTemp;
      sprites.Free;
    end;
  end, aOnDone, 'Export house anim');
end;


//Export Trees graphics categorized by ID
procedure TKMResExporter.ExportTreeAnim(aOnDone: TProc<String> = nil);
begin
  // Asynchroniously export data
  GetOrCreateExportWorker.QueueWork(procedure
  var
    fullFolderPath, folderPath: string;
    I, K: Integer;

    sprites: TKMResSprites;
    spriteID: Integer;
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
            if TThread.CheckTerminated then
              Exit;
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

end.
