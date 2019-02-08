unit KM_Supervisor;
{$I KaM_Remake.inc}

//{$I KaM_Remake.inc}
interface
uses
  Classes, KM_CommonClasses, KM_CommonTypes, KM_Defaults,
  KM_Points, KM_UnitGroups, KM_NavMeshDefences, KM_ArmyAttack, KM_ArmyManagement, KM_NavMeshInfluences,
  KM_ResHouses, KM_Sort;

type
  TKMCompFunc = function (const aElem1, aElem2): Integer;
  TKMDefEval = record
    Val: Word;
    Owner: TKMHandIndex;
    DefPos: PDefencePosition;
  end;
  TKMDefEvalArr = array of TKMDefEval;
  TKMMineEval = record
    Val: Word;
    pPoint: ^TKMPoint;
  end;
  TKMMineEvalArr = array of TKMMineEval;

  TKMHandByteArr = array[0..MAX_HANDS-1] of Byte;
  TKMHandIdx2Arr = array of array of TKMHandIndex;

// Supervisor <-> agent relation ... cooperating AI players are just an illusion, agents does not see each other
  TKMSupervisor = class
  private
    fPL2Alli: TKMHandByteArr;
    fAlli2PL: TKMHandIdx2Arr;
    procedure UpdateDefSupport(aTeamIdx: Byte);
    procedure UpdateDefPos(aTeamIdx: Byte);
    procedure UpdateAttack(aTeamIdx: Byte);
    procedure DivideResources();
    function NewAIInTeam(aIdxTeam: Byte): Boolean;
  public
    constructor Create();
    destructor Destroy(); override;
    procedure Save(SaveStream: TKMemoryStream);
    procedure Load(LoadStream: TKMemoryStream);

    property PL2Alli: TKMHandByteArr read fPL2Alli;
    property Alli2PL: TKMHandIdx2Arr read fAlli2PL;

    function FindClosestEnemies(var aPlayers: TKMHandIndexArray; var aEnemyStats: TKMEnemyStatisticsArray): Boolean;

    procedure AfterMissionInit();
    procedure UpdateState(aTick: Cardinal);
    procedure UpdateAlliances();
    procedure Paint(aRect: TKMRect);
  end;


implementation
uses
  Math,
  KM_Game, KM_HandsCollection, KM_Hand, KM_RenderAux,
  KM_AIFields, KM_NavMesh, KM_CommonUtils;

type
  TByteArray = array [Word] of byte;
  PByteArray = ^TByteArray;

{ Procedural functions }
function CompareDef(const aElem1, aElem2): Integer;
var
  val1 : TKMDefEval absolute aElem1;
  val2 : TKMDefEval absolute aElem2;
begin
  if (val1.Val = val2.Val) then      Result := 0
  else if (val1.Val < val2.Val) then Result := -1
  else                               Result := 1;
end;

function CompareMines(const aElem1, aElem2): Integer;
var
  val1 : TKMMineEval absolute aElem1;
  val2 : TKMMineEval absolute aElem2;
begin
  if (val1.Val = val2.Val) then      Result := 0
  else if (val1.Val < val2.Val) then Result := -1
  else                               Result := 1;
end;


{ TKMSupervisor }
constructor TKMSupervisor.Create();
begin

end;

destructor TKMSupervisor.Destroy();
begin
  inherited;
end;


procedure TKMSupervisor.Save(SaveStream: TKMemoryStream);
var
  I: Integer;
begin
  SaveStream.WriteA('Supervisor');
  SaveStream.Write(fPL2Alli, SizeOf(fPL2Alli));
  SaveStream.Write( Integer(Length(fAlli2PL)) );
  for I := Low(fAlli2PL) to High(fAlli2PL) do
  begin
    SaveStream.Write( Integer(Length(fAlli2PL[I])) );
    SaveStream.Write(fAlli2PL[I,0], SizeOf(fAlli2PL[I,0])*Length(fAlli2PL[I]));
  end;
end;

procedure TKMSupervisor.Load(LoadStream: TKMemoryStream);
var
  I,K: Integer;
begin
  LoadStream.ReadAssert('Supervisor');
  LoadStream.Read(fPL2Alli, SizeOf(fPL2Alli));
  LoadStream.Read(K);
  SetLength(fAlli2PL, K);
  for I := Low(fAlli2PL) to High(fAlli2PL) do
  begin
    LoadStream.Read(K);
    SetLength(fAlli2PL[I],K);
    LoadStream.Read(fAlli2PL[I,0], SizeOf(fAlli2PL[I,0])*Length(fAlli2PL[I]));
  end;
end;


procedure TKMSupervisor.AfterMissionInit();
begin
  UpdateAlliances();
  DivideResources();
end;


procedure TKMSupervisor.UpdateState(aTick: Cardinal);
const
  DEFENSIVE_SUPPORT = 10 * MAX_HANDS;
  DEFENCES = 10 * 30; // Every 30 sec recalculate defences of 1 team
  ATTACKS = 10 * 30;
var
  Modulo: Word;
begin
  Modulo := aTick mod DEFENSIVE_SUPPORT;
  if (Modulo < Length(fAlli2PL)) then
    UpdateDefSupport(Modulo);
  Modulo := aTick mod DEFENCES;
  if (Modulo < Length(fAlli2PL)) then
    UpdateDefPos(Modulo);
  Modulo := aTick mod ATTACKS;
  if (Modulo < Length(fAlli2PL)) then
    UpdateAttack(Modulo);
end;


procedure TKMSupervisor.UpdateAlliances();
var
  PL1,PL2: TKMHandIndex;
  AlliCnt, PLCnt: Byte;
begin
  FillChar(fPL2Alli, SizeOf(fPL2Alli), #255); // TKMHandIndex = SmallInt => Byte(255) = -1 = PLAYER_NONE
  SetLength(fAlli2PL, gHands.Count, gHands.Count);
  AlliCnt := 0;
  for PL1 := 0 to gHands.Count - 1 do
    if gHands[PL1].Enabled AND (fPL2Alli[PL1] = 255) then
    begin
      PLCnt := 0;
      for PL2 := 0 to gHands.Count - 1 do
        if gHands[PL2].Enabled AND ((PL1 = PL2) OR (gHands[PL1].Alliances[PL2] = at_Ally)) then
        begin
          fPL2Alli[PL2] := AlliCnt;
          fAlli2PL[AlliCnt,PLCnt] := PL2;
          Inc(PLCnt);
        end;
      SetLength(fAlli2PL[AlliCnt], PLCnt);
      Inc(AlliCnt);
    end;
  SetLength(fAlli2PL, AlliCnt);
end;


procedure TKMSupervisor.UpdateDefSupport(aTeamIdx: Byte);
  // Get new AI players
  function GetNewAIPlayers(var aNewAIPLs: TKMHandIndexArray): Boolean;
  var
    I, Cnt: Integer;
  begin
    Cnt := 0;
    SetLength(aNewAIPLs, Length(fAlli2PL[aTeamIdx]));
    for I := 0 to Length(aNewAIPLs) - 1 do
      with gHands[fAlli2PL[aTeamIdx,I] ] do
        if (HandType = hndComputer) AND AI.Setup.NewAI then
        begin
          aNewAIPLs[Cnt] := fAlli2PL[aTeamIdx,I];
          Inc(Cnt);
        end;
    SetLength(aNewAIPLs, Cnt);
    Result := Cnt > 1; // We dont just need 1 new AI but also ally which will help him
  end;
  // Try find support
  procedure FindAssistance(aPoint: TKMPoint; aOwner: TKMHandIndex; var aNewAIPLs: TKMHandIndexArray);
  var
    Assistance: Boolean;
    I: Integer;
    AssistArr: TBooleanArray;
  begin
    SetLength(AssistArr, Length(aNewAIPLs));
    FillChar(AssistArr[0], SizeOf(AssistArr[0]) * Length(AssistArr), #0);
    // Prefer to defend allies in range of influence
    Assistance := False;
    for I := 0 to Length(aNewAIPLs) - 1 do
      if (aOwner <> aNewAIPLs[I]) AND (gAIFields.Influences.Ownership[ aNewAIPLs[I], aPoint.Y, aPoint.X] > 0) then
      begin
        AssistArr[I] := True;
        Assistance := Assistance
                      OR gHands[ aNewAIPLs[I] ].AI.ArmyManagement.Defence.DefendPoint(aPoint, True);
      end;
    // If there is not ally then try another allies
    if not Assistance then
      for I := 0 to Length(aNewAIPLs) - 1 do
        if (aOwner <> aNewAIPLs[I]) AND not AssistArr[I] then
          gHands[ aNewAIPLs[I] ].AI.ArmyManagement.Defence.DefendPoint(aPoint, False);
  end;
var
  I,K: Integer;
  NewAIPLs: TKMHandIndexArray;
begin
  if (Length(fAlli2PL) > 1) AND GetNewAIPlayers(NewAIPLs) then
    for I := 0 to Length(NewAIPLs) - 1 do
      with gHands[ NewAIPLs[I] ].AI.ArmyManagement.DefendRequest do
        for K := 0 to PointsCnt - 1 do
          FindAssistance(Points[K], NewAIPLs[I], NewAIPLs);
end;


procedure TKMSupervisor.UpdateDefPos(aTeamIdx: Byte);
type
  TKMDistDefPos = array[0..MAX_HANDS-1] of record
    Count: Word;
    DefPos: array of PDefencePosition;
  end;

  procedure DivideDefences(var aOwners: TKMHandIndexArray; var aDefPosReq: TKMWordArray; var aTeamDefPos: TKMTeamDefPos);
  const
    FRONT_LINE_PRICE = 40;
  var
    Line: Byte;
    I, K, PolyIdx, IdxPL, Cnt: Integer;
    DistributedPos: TKMDistDefPos;
    DefEval: TKMDefEvalArr;
  begin
    // Set Length
    Cnt := 0;
    for I := 0 to Length(aTeamDefPos) - 1 do
      Inc(Cnt, Length(aTeamDefPos[I].DefPosArr)*Length(aTeamDefPos[I].Owners));
    SetLength(DefEval,Cnt);
    // Evaluate defences (price of each defence depends on potential owner)
    Cnt := 0;
    for I := 0 to Length(aTeamDefPos) - 1 do
      with aTeamDefPos[I] do
        for K := 0 to Length(DefPosArr) - 1 do
        begin
          PolyIdx := DefPosArr[K].Polygon;
          Line := DefPosArr[K].Line;
          DefPosArr[K].Weight := 0; // Mark defence as available
          for IdxPL := 0 to Length(Owners) - 1 do
          begin
            DefEval[Cnt].Owner := Owners[IdxPL];
            DefEval[Cnt].Val := + 64000 // Base price
                                + gAIFields.Influences.OwnPoly[Owners[IdxPL], PolyIdx] // Max + 255
                                - Line * FRONT_LINE_PRICE;
            DefEval[Cnt].DefPos := @DefPosArr[K];
            Inc(Cnt);
          end;
        end;
    if (Length(DefEval) > 0) then
    begin
      // Sort by evaluation
      Sort(DefEval[0], Low(DefEval), Cnt-1, sizeof(DefEval[0]), CompareDef);
      // Prepare output array
      for I := 0 to Length(aOwners) - 1 do
        with DistributedPos[ aOwners[I] ] do
        begin
          Count := 0;
          SetLength(DefPos, aDefPosReq[I]);
        end;
      // Split defences between players
      for I := Length(DefEval) - 1 downto 0 do
        if (DefEval[I].DefPos^.Weight = 0) then
          with DistributedPos[ DefEval[I].Owner ] do
            if (Count < Length(DefPos)) then
            begin
              DefEval[I].DefPos^.Weight := DefEval[I].Val; // Copy price for defence
              DefPos[ Count ] := DefEval[I].DefPos;
              Inc(Count);
            end;
      // Send defences to owner
      for I := 0 to Length(aOwners) - 1 do
        with gHands[ aOwners[I] ] do
          if (HandType = hndComputer) AND AI.Setup.NewAI then
            AI.ArmyManagement.Defence.UpdateDefences(DistributedPos[ aOwners[I] ].Count, DistributedPos[ aOwners[I] ].DefPos);
    end;
  end;

const
  RESERVE_DEF_POS = 5;
var
  IdxPL,Troops: Integer;
  DefPosReq: TKMWordArray;
  TeamDefPos: TKMTeamDefPos;
begin
  if NewAIInTeam(aTeamIdx) AND (Length(fAlli2PL) > 1) then
  begin
    SetLength(DefPosReq, Length( fAlli2PL[aTeamIdx] ) );
    for IdxPL := 0 to Length(DefPosReq) - 1 do
      with gHands[ fAlli2PL[aTeamIdx, IdxPL] ] do
      begin
        Troops := Byte(HandType = hndComputer) * (Stats.GetUnitQty(ut_Recruit) + Stats.GetArmyCount); // Consider also recruits so after peace time the AI already have prepared defences
        DefPosReq[IdxPL] := Round(Troops / 9) + RESERVE_DEF_POS; // Each group have 9 troops so we need max (Troops / 9) positions + reserves
      end;
    SetLength(TeamDefPos,0);
    gAIFields.NavMesh.Defences.FindTeamDefences(fAlli2PL[aTeamIdx], DefPosReq, TeamDefPos);
    DivideDefences(fAlli2PL[aTeamIdx], DefPosReq, TeamDefPos);
  end;
end;


function TKMSupervisor.FindClosestEnemies(var aPlayers: TKMHandIndexArray; var aEnemyStats: TKMEnemyStatisticsArray): Boolean;
  function GetInitPoints(): TKMPointArray;
  var
    IdxPL: Integer;
    Player: TKMHandIndex;
    Group: TKMUnitGroup;
    CenterPoints: TKMPointArray;
  begin
    SetLength(Result,0);
    // Find center points of cities / armies (where we should start scan - init point / center screen is useless for this)
    for IdxPL := 0 to Length(aPlayers) - 1 do
    begin
      Player := aPlayers[IdxPL];
      gAIFields.Eye.OwnerUpdate(Player);
      CenterPoints := gAIFields.Eye.GetCityCenterPoints(True);
      if (Length(CenterPoints) = 0) then // No important houses were found -> try find soldier
      begin
        if (gHands[Player].UnitGroups.Count = 0) then
          continue;
        Group := gHands[Player].UnitGroups.Groups[ KaMRandom(gHands[Player].UnitGroups.Count) ];
        if (Group <> nil) AND not Group.IsDead AND not KMSamePoint(KMPOINT_ZERO,Group.Position) then
        begin
          SetLength(CenterPoints, 1);
          CenterPoints[0] := Group.Position;
        end
        else
          continue;
      end;
      SetLength(Result, Length(Result) + Length(CenterPoints));
      Move(CenterPoints[0], Result[ Length(Result) - Length(CenterPoints) ], SizeOf(CenterPoints[0]) * Length(CenterPoints));
    end;
  end;
var
  InitPoints: TKMPointArray;
begin
  // Get init points
  InitPoints := GetInitPoints();
  // Try find enemies by influence area
  Result := (Length(InitPoints) <> 0)
            AND ( gAIFields.Influences.InfluenceSearch.FindClosestEnemies(aPlayers[0], InitPoints, aEnemyStats, True)
               OR gAIFields.Influences.InfluenceSearch.FindClosestEnemies(aPlayers[0], InitPoints, aEnemyStats, False) );
end;


// Find best target -> to secure that AI will be as universal as possible find only point in map and company will destroy everything around automatically
procedure TKMSupervisor.UpdateAttack(aTeamIdx: Byte);

  function GetBestComparison(aPlayer: TKMHandIndex; var aBestCmp, aWorstCmp: Single; var aEnemyStats: TKMEnemyStatisticsArray): Integer;
  const
    DISTANCE_COEF = 0.4; // Decrease chance to attack enemy in distance
    MIN_ADVANTAGE = 0.15; // 15% advantage for attacker
  var
    I, MinDist, MaxDist: Integer;
    Comparison, invDistInterval: Single;
  begin
    Result := -1;
    aBestCmp := -1;
    aWorstCmp := 1;
    if (Length(aEnemyStats) > 0) then
    begin
      // Find closest enemy
      MinDist := High(Integer);
      MaxDist := 0;
      for I := 0 to Length(aEnemyStats) - 1 do
      begin
          MinDist := Min(MinDist, aEnemyStats[I].Distance);
          MaxDist := Max(MaxDist, aEnemyStats[I].Distance);
      end;
      invDistInterval := 1 / Max(1,MaxDist - MinDist);

      for I := 0 to Length(aEnemyStats) - 1 do
      begin
        Comparison := + gAIFields.Eye.ArmyEvaluation.CompareAllianceStrength(aPlayer, aEnemyStats[I].Player)
                      - (aEnemyStats[I].Distance - MinDist) * invDistInterval * DISTANCE_COEF;
        if (Comparison > aBestCmp) then
        begin
          aBestCmp := Comparison;
          Result := I;
        end;
        if (Comparison < aWorstCmp) then
          aWorstCmp := Comparison;
      end;
    end;
    if (aBestCmp < MIN_ADVANTAGE) then
      Result := -1;
  end;
const
  MIN_DEF_RATIO = 1.2;
var
  BestCmpIdx, IdxPL, EnemyTeamIdx: Integer;
  DefRatio, BestCmp, WorstCmp: Single;
  EnemyStats: TKMEnemyStatisticsArray;
begin
  if not NewAIInTeam(aTeamIdx) OR (Length(fAlli2PL) < 2) then // I sometimes use my loc as a spectator (alliance with everyone) so make sure that search for enemy will use AI loc
    Exit;
  // Check if alliance can attack (have available soldiers)
  DefRatio := 0;
  for IdxPL := 0 to Length( fAlli2PL[aTeamIdx] ) - 1 do
    with gHands[ fAlli2PL[aTeamIdx, IdxPL] ] do
      if (HandType = hndComputer) AND AI.Setup.NewAI then
      begin
        DefRatio := Max(DefRatio, AI.ArmyManagement.Defence.DefenceStatus);
        KMSwapInt(fAlli2PL[aTeamIdx, 0], fAlli2PL[aTeamIdx, IdxPL]); // Make sure that player in first index is new AI
      end;
  // AI does not have enought soldiers
  if (DefRatio < MIN_DEF_RATIO) then
    Exit;
  // Try find enemies by influence area
  if FindClosestEnemies(fAlli2PL[aTeamIdx], EnemyStats) then
  begin
    // Calculate strength of alliance, find best comparison - value in interval <-1,1>, positive value = advantage, negative = disadvantage
    BestCmpIdx := GetBestComparison(fAlli2PL[aTeamIdx, 0], BestCmp, WorstCmp, EnemyStats);
    if (BestCmpIdx >= 0) then
    begin
      EnemyTeamIdx := fPL2Alli[ EnemyStats[BestCmpIdx].Player ];
      for IdxPL := 0 to Length( fAlli2PL[aTeamIdx] ) - 1 do
        with gHands[ fAlli2PL[aTeamIdx, IdxPL] ].AI.ArmyManagement.AttackRequest do
        begin
          Active := True;
          BestAllianceCmp := BestCmp;
          WorstAllianceCmp := WorstCmp;
          BestEnemy := EnemyStats[BestCmpIdx].Player;
          BestPoint := EnemyStats[BestCmpIdx].ClosestPoint;
          SetLength(Enemies, Length(fAlli2PL[EnemyTeamIdx]) );
          Move(fAlli2PL[EnemyTeamIdx,0], Enemies[0], SizeOf(Enemies[0])*Length(Enemies));
        end;
    end;
  end;
end;



procedure TKMSupervisor.DivideResources();
  function FindAndDivideMines(var aPlayers: TKMHandIndexArray; var aMines: TKMPointArray): TKMWordArray;
  const
    MAX_INFLUENCE = 256;
  var
    I, IdxPL, IdxPL2, Cnt, PLCnt, BestPrice: Integer;
    PL: TKMHandIndex;
    PLMines,PLPossibleMines: TKMWordArray;
    Mines: TKMMineEvalArr;
  begin
    SetLength(Result, 0);
    // Init
    SetLength(PLMines, Length(aPlayers));
    SetLength(PLPossibleMines, Length(aPlayers));
    FillChar(PLMines[0], SizeOf(PLMines[0]) * Length(PLMines), #0);
    FillChar(PLPossibleMines[0], SizeOf(PLPossibleMines[0]) * Length(PLPossibleMines), #0);
    // Get only mines in influence of alliance
    Cnt := 0;
    SetLength(Mines, Length(aMines));
    for I := Length(aMines) - 1 downto 0 do
    begin
      // Evaluate point if there can be mine (in dependence on influence)
      PL := gAIFields.Influences.GetBestOwner(aMines[I].X,aMines[I].Y);
      for IdxPL := 0 to Length(aPlayers) - 1 do
        if (PL = aPlayers[IdxPL]) then
        begin
          PLCnt := 0;
          for IdxPL2 := 0 to Length(aPlayers) - 1 do // Mark players which can place mine here (by influence)
            if (gAIFields.Influences.Ownership[aPlayers[IdxPL2], aMines[I].Y,aMines[I].X] > 0) then
            begin
              Inc(PLPossibleMines[IdxPL2]);
              Inc(PLCnt);
            end;
          Mines[Cnt].Val := PLCnt * MAX_INFLUENCE + gAIFields.Influences.Ownership[PL, aMines[I].Y,aMines[I].X];
          Mines[Cnt].pPoint := @aMines[I];
          Inc(Cnt);
        end;
    end;
    if (Cnt > 0) then
    begin
      // Sort mines by evaluation
      Sort(Mines[0], Low(Mines), Cnt-1, sizeof(Mines[0]), CompareMines);
      // Distribute mines by evaluation and possible mine cnt per a player
      for I := 0 to Cnt - 1 do // Lower index = less players can own this mine
      begin
        IdxPL2 := 0;
        BestPrice := High(Word);
        for IdxPL := 0 to Length(aPlayers) - 1 do
          if (gAIFields.Influences.Ownership[aPlayers[IdxPL], Mines[I].pPoint^.Y, Mines[I].pPoint^.X] > 0)
            AND (PLPossibleMines[IdxPL] + PLMines[IdxPL] < BestPrice) then
          begin
            BestPrice := PLPossibleMines[IdxPL] + PLMines[IdxPL];
            IdxPL2 := IdxPL;
          end;
        if (BestPrice <> High(Word)) then
        begin
          Inc(PLMines[IdxPL2]);
          // Decrease possible mine cnt
          for IdxPL2 := 0 to Length(aPlayers) - 1 do
            if (gAIFields.Influences.Ownership[aPlayers[IdxPL2], Mines[I].pPoint^.Y, Mines[I].pPoint^.X] > 0) then
              Dec(PLPossibleMines[IdxPL2]);
        end;
      end;
    end;
    Result := PLMines;
  end;
var
  Alli, IdxPL: Integer;
  MineCnt: TKMWordArray;
  GoldMines, IronMines: TKMPointArray;
begin
  IronMines := gAIFields.Eye.FindSeparateMineLocs(True, htIronMine);
  GoldMines := gAIFields.Eye.FindSeparateMineLocs(True, htGoldMine);
  for Alli := 0 to Length(fAlli2PL) - 1 do
  begin
    MineCnt := FindAndDivideMines(fAlli2PL[Alli], IronMines);
    if (Length(MineCnt) > 0) then
      for IdxPL := 0 to Length(fAlli2PL[Alli]) - 1 do
        gHands[ fAlli2PL[Alli,IdxPL] ].AI.CityManagement.Predictor.IronMineCnt := MineCnt[IdxPL];
    MineCnt := FindAndDivideMines(fAlli2PL[Alli], GoldMines);
    if (Length(MineCnt) > 0) then
      for IdxPL := 0 to Length(fAlli2PL[Alli]) - 1 do
        gHands[ fAlli2PL[Alli,IdxPL] ].AI.CityManagement.Predictor.GoldMineCnt := MineCnt[IdxPL];
  end;
end;


function TKMSupervisor.NewAIInTeam(aIdxTeam: Byte): Boolean;
var
  IdxPL: Integer;
begin
  Result := False;
  for IdxPL := 0 to Length( fAlli2PL[aIdxTeam] ) - 1 do
    with gHands[ fAlli2PL[aIdxTeam, IdxPL] ] do
      if (HandType = hndComputer) AND AI.Setup.NewAI then
      begin
        //Result := fAlli2PL[aIdxTeam, IdxPL];
        Result := True;
        Exit;
      end;
end;


procedure TKMSupervisor.Paint(aRect: TKMRect);
const
  COLOR_WHITE = $FFFFFF;
  COLOR_BLACK = $000000;
  COLOR_GREEN = $00FF00;
  COLOR_RED = $0000FF;
  COLOR_YELLOW = $00FFFF;
  COLOR_BLUE = $FF0000;
begin

end;

end.
