unit KM_ResInterpolation;
{$I KaM_Remake.inc}
interface
uses
  Classes, SysUtils, Math,
  KM_Defaults, KM_Points, KM_ResTypes, KM_ResWares, KM_ResMapElements, KM_ResHouses;

const
  INTERP_LEVEL = 8;

type
  TKMInterpolation = array[1..30, 0..INTERP_LEVEL-1] of Integer;
  TKMUnitActionInterp = array[UNIT_MIN..UNIT_MAX, UNIT_ACT_MIN..UNIT_ACT_MAX, dirN..dirNW] of TKMInterpolation;
  TKMSerfCarryInterp = array[WARE_MIN..WARE_MAX, dirN..dirNW] of TKMInterpolation;
  TKMUnitThoughtInterp = array[TKMUnitThought] of TKMInterpolation;
  TKMTreeInterp = array[0..OBJECTS_CNT] of TKMInterpolation;
  TKMHouseInterp = array[HOUSE_MIN..HOUSE_MAX, TKMHouseActionType] of TKMInterpolation;
  TKMBeastInterp = array[1..3,1..5,1..3] of TKMInterpolation;

  TKMResInterpolation = class
  private
    fUnitActions: TKMUnitActionInterp;
    fSerfCarry: TKMSerfCarryInterp;
    fUnitThoughts: TKMUnitThoughtInterp;
    fTrees: TKMTreeInterp;
    fHouses: TKMHouseInterp;
    fBeasts: TKMBeastInterp;
  public
    procedure LoadFromFile(const FileName: string);

    function UnitAction(aUnit: TKMUnitType; aAct: TKMUnitActionType; aDir: TKMDirection; aStep: Integer; aStepFrac: Single): Integer;
    function UnitActionByPercent(aUnit: TKMUnitType; aAct: TKMUnitActionType; aDir: TKMDirection; aPercent: Single): Integer;
    function SerfCarry(aWare: TKMWareType; aDir: TKMDirection; aStep: Integer; aStepFrac: Single): Integer;
    function UnitThought(aTh: TKMUnitThought; aStep: Integer; aStepFrac: Single): Integer;
    function Tree(aObject: Integer; aStep: Integer; aStepFrac: Single; aLoop: Boolean): Integer;
    function House(aHT: TKMHouseType; aAct: TKMHouseActionType; aStep: Integer; aStepFrac: Single): Integer;
    function Beast(aHT: TKMHouseType; BeastId, BeastAge, aStep: Integer; aStepFrac: Single): Integer;
  end;


implementation
uses
  KM_CommonClasses, KM_Resource, KM_CommonTypes, KM_Pics, KM_ResUnits, KM_GameSettings;


{ TKMResInterpolation }

procedure TKMResInterpolation.LoadFromFile(const FileName: string);
var
  S: TKMemoryStreamBinary;
begin
  if not FileExists(FileName) then Exit;

  S := TKMemoryStreamBinary.Create;
  try
    S.LoadFromFile(FileName);

    S.CheckMarker('UnitAction');
    S.Read(fUnitActions, SizeOf(fUnitActions));

    S.CheckMarker('SerfCarry ');
    S.Read(fSerfCarry, SizeOf(fSerfCarry));

    S.CheckMarker('UnitThoughts  ');
    S.Read(fUnitThoughts, SizeOf(fUnitThoughts));

    S.CheckMarker('Trees ');
    S.Read(fTrees, SizeOf(fTrees));

    S.CheckMarker('Houses');
    S.Read(fHouses, SizeOf(fHouses));

    S.CheckMarker('Beasts');
    S.Read(fBeasts, SizeOf(fBeasts));

  finally
    S.Free;
  end;
end;


function TKMResInterpolation.UnitAction(aUnit: TKMUnitType;
  aAct: TKMUnitActionType; aDir: TKMDirection; aStep: Integer;
  aStepFrac: Single): Integer;
var
  A: TKMAnimLoop;
  Step, SubStep: Integer;
begin
  A := gRes.Units[aUnit].UnitAnim[aAct, aDir];

  Step := aStep mod Byte(A.Count) + 1;
  SubStep := EnsureRange(Floor(INTERP_LEVEL*aStepFrac), 0, INTERP_LEVEL-1);

  Result := fUnitActions[aUnit, aAct, aDir, Step, SubStep];

  //While in development disable interpolation if the sprite is missing
  if not gGameSettings.InterpolatedAnimations
  or (Result <= 0) or (Result > gRes.Sprites[rxUnits].RXData.Count)
  or (gRes.Sprites[rxUnits].RXData.Size[Result].X = 0) then
    Result := A.Step[Step] + 1;
end;


function TKMResInterpolation.UnitActionByPercent(aUnit: TKMUnitType;
  aAct: TKMUnitActionType; aDir: TKMDirection; aPercent: Single): Integer;
var
  count: Integer;
  fracStep: Single;
begin
  count := gRes.Units[aUnit].UnitAnim[aAct, aDir].Count;
  fracStep := Min(aPercent, 1.0) * (count-1);
  Result := UnitAction(aUnit, aAct, aDir, Trunc(fracStep), Frac(fracStep));
end;


function TKMResInterpolation.UnitThought(aTh: TKMUnitThought; aStep: Integer; aStepFrac: Single): Integer;
var
  AnimCount, Step, SubStep: Integer;
begin
  AnimCount := THOUGHT_BOUNDS[aTh, 2] - THOUGHT_BOUNDS[aTh, 1];
  Step := aStep mod Byte(AnimCount) + 1;
  SubStep := EnsureRange(Floor(INTERP_LEVEL*aStepFrac), 0, INTERP_LEVEL-1);

  Result := fUnitThoughts[aTh, Step, SubStep];

  //While in development disable interpolation if the sprite is missing
  if not gGameSettings.InterpolatedAnimations
  or (Result <= 0) or (Result > gRes.Sprites[rxUnits].RXData.Count)
  or (gRes.Sprites[rxUnits].RXData.Size[Result].X = 0) then
  begin
    // Non-interpolated thought bubbles are animated in reverse
    Result := THOUGHT_BOUNDS[aTh, 2] + 1 - Step;
  end;
end;


function TKMResInterpolation.SerfCarry(aWare: TKMWareType; aDir: TKMDirection;
  aStep: Integer; aStepFrac: Single): Integer;
var
  A: TKMAnimLoop;
  Step, SubStep: Integer;
begin
  A := gRes.Units.SerfCarry[aWare, aDir];

  Step := aStep mod Byte(A.Count) + 1;
  SubStep := EnsureRange(Floor(INTERP_LEVEL*aStepFrac), 0, INTERP_LEVEL-1);

  Result := fSerfCarry[aWare, aDir, Step, SubStep];

  //While in development disable interpolation if the sprite is missing
  if not gGameSettings.InterpolatedAnimations
  or (Result <= 0) or (Result > gRes.Sprites[rxUnits].RXData.Count)
  or (gRes.Sprites[rxUnits].RXData.Size[Result].X = 0) then
    Result := A.Step[Step] + 1;
end;


function TKMResInterpolation.Tree(aObject, aStep: Integer; aStepFrac: Single; aLoop: Boolean): Integer;
var
  A: TKMAnimLoop;
  Step, SubStep: Integer;
begin
  A := gMapElements[aObject].Anim;

  Step := aStep mod Byte(A.Count) + 1;

  if aLoop or (Step < A.Count) then
    SubStep := EnsureRange(Floor(INTERP_LEVEL*aStepFrac), 0, INTERP_LEVEL-1)
  else
    SubStep := 0;

  Result := fTrees[aObject, Step, SubStep];

  //While in development disable interpolation if the sprite is missing
  if not gGameSettings.InterpolatedAnimations
  or (Result <= 0) or (Result > gRes.Sprites[rxTrees].RXData.Count)
  or (gRes.Sprites[rxTrees].RXData.Size[Result].X = 0) then
    Result := A.Step[Step] + 1;
end;


function TKMResInterpolation.House(aHT: TKMHouseType; aAct: TKMHouseActionType;
  aStep: Integer; aStepFrac: Single): Integer;
var
  A: TKMAnimLoop;
  Step, SubStep: Integer;
begin
  A := gRes.Houses[aHT].Anim[aAct];

  Step := aStep mod Byte(A.Count) + 1;
  SubStep := EnsureRange(Floor(INTERP_LEVEL*aStepFrac), 0, INTERP_LEVEL-1);

  Result := fHouses[aHT, aAct, Step, SubStep];

  //While in development disable interpolation if the sprite is missing
  if not gGameSettings.InterpolatedAnimations
  or (Result <= 0) or (Result > gRes.Sprites[rxHouses].RXData.Count)
  or (gRes.Sprites[rxHouses].RXData.Size[Result].X = 0) then
    Result := A.Step[Step] + 1;
end;


function TKMResInterpolation.Beast(aHT: TKMHouseType; BeastId, BeastAge,
  aStep: Integer; aStepFrac: Single): Integer;
var
  A: TKMAnimLoop;
  Step, SubStep: Integer;
begin
  A := gRes.Houses.BeastAnim[aHT, BeastId, BeastAge];

  Step := aStep mod Byte(A.Count) + 1;
  SubStep := EnsureRange(Floor(INTERP_LEVEL*aStepFrac), 0, INTERP_LEVEL-1);

  case aHT of
    htSwine:       Result := fBeasts[1, BeastId, BeastAge, Step, SubStep];
    htStables:     Result := fBeasts[2, BeastId, BeastAge, Step, SubStep];
    htMarketplace: Result := fBeasts[3, BeastId, 1,        Step, SubStep];
    else           Result := -1;
  end;

  //While in development disable interpolation if the sprite is missing
  if not gGameSettings.InterpolatedAnimations
  or (Result <= 0) or (Result > gRes.Sprites[rxHouses].RXData.Count)
  or (gRes.Sprites[rxHouses].RXData.Size[Result].X = 0) then
    Result := A.Step[Step] + 1;
end;


end.
