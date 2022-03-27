unit KM_GUIMapEdTownHouses;
{$I KaM_Remake.inc}
interface
uses
   Classes, Math, SysUtils,
   KM_InterfaceDefaults,
   KM_Controls, KM_ControlsBase,
   KM_Defaults, KM_InterfaceGame;

type
  TKMMapEdTownHouses = class(TKMMapEdSubMenuPage)
  private
    procedure UpdateField(Sender: TObject; aIncrement: Integer);

    procedure Town_FieldShiftClick(Sender: TObject; Shift: TShiftState);
    procedure Town_FieldMWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean);
    procedure Town_BuildChange(Sender: TObject);
    procedure Town_BuildRefresh;
  protected
    Panel_Build: TKMPanel;
      Button_BuildRoad: TKMButtonFlat;
      Button_BuildField: TKMButtonFlat;
      Button_BuildWine: TKMButtonFlat;
      Button_BuildCancel: TKMButtonFlat;
      Button_Build: array [1..GUI_HOUSE_COUNT] of TKMButtonFlat;
      Image_HouseConstructionWood, Image_HouseConstructionStone: TKMImage;
      Label_HouseConstructionWood, Label_HouseConstructionStone: TKMLabel;
  public
    constructor Create(aParent: TKMPanel);

    procedure BuildRoad;
    procedure BuildField;
    procedure BuildWine;
    procedure BuildCancel;

    procedure Show;
    procedure Hide;
    function Visible: Boolean; override;
    procedure UpdateHotkeys;
    procedure UpdateState;
    procedure UpdateStateIdle;
  end;


implementation
uses
  KM_ResTexts, KM_Cursor, KM_Resource, KM_ResHouses, KM_ResFonts,
  KM_RenderUI, KM_Terrain, KM_Points, KM_Utils,
  KM_ResTypes, KM_ResMapElements;


{ TKMMapEdTownHouses }
constructor TKMMapEdTownHouses.Create(aParent: TKMPanel);
var
  I, top: Integer;
begin
  inherited Create;

  Panel_Build := TKMPanel.Create(aParent, 9, 28, aParent.Width - 9, 400);

  with TKMLabel.Create(Panel_Build,0,PAGE_TITLE_Y,Panel_Build.Width,0,gResTexts[TX_MAPED_ROAD_TITLE],fntOutline,taCenter) do
    Anchors := [anLeft, anTop, anRight];
  Button_BuildRoad   := TKMButtonFlat.Create(Panel_Build,  9,28,33,33,335);
  Button_BuildField  := TKMButtonFlat.Create(Panel_Build, 46,28,33,33,337);
  Button_BuildWine   := TKMButtonFlat.Create(Panel_Build, 83,28,33,33,336);
  Button_BuildCancel := TKMButtonFlat.Create(Panel_Build,157,28,33,33,340);

  Button_BuildField.CapColor := clMapEdBtnField;
  Button_BuildWine.CapColor := clMapEdBtnWine;

  Button_BuildField.Caption := IntToStr(gCursor.MapEdFieldAge + 1);
  Button_BuildWine.Caption  := IntToStr(gCursor.MapEdWineFieldAge + 1);

  Button_BuildField.CapOffsetY := -10;
  Button_BuildField.TexOffsetY := 6;

  Button_BuildWine.CapOffsetY := -10;
  Button_BuildWine.TexOffsetY := 6;

  Button_BuildField.OnClickShift := Town_FieldShiftClick;
  Button_BuildWine.OnClickShift  := Town_FieldShiftClick;
  Button_BuildField.OnMouseWheel := Town_FieldMWheel;
  Button_BuildWine.OnMouseWheel := Town_FieldMWheel;

  Button_BuildRoad.OnClick  := Town_BuildChange;
  Button_BuildCancel.OnClick:= Town_BuildChange;

  with TKMLabel.Create(Panel_Build,0,65,Panel_Build.Width,0,gResTexts[TX_MAPED_HOUSES_TITLE],fntOutline,taCenter) do
    Anchors := [anLeft, anTop, anRight];
  for I := 1 to GUI_HOUSE_COUNT do
    if GUIHouseOrder[I] <> htNone then
    begin
      Button_Build[I] := TKMButtonFlat.Create(Panel_Build, 9 + ((I-1) mod 5)*37,83+((I-1) div 5)*37,33,33,gResHouses[GUIHouseOrder[I]].GUIIcon);
      Button_Build[I].OnClick := Town_BuildChange;
    end;

  top := Button_Build[GUI_HOUSE_COUNT].Bottom + 3;

  Image_HouseConstructionWood := TKMImage.Create(Panel_Build, 9, top, 32, 32, 353);
  Image_HouseConstructionWood.ImageCenter;
  Image_HouseConstructionStone := TKMImage.Create(Panel_Build, 9 + 55, top, 32, 32, 352);
  Image_HouseConstructionStone.ImageCenter;
  Label_HouseConstructionWood  := TKMLabel.Create(Panel_Build,  39, top + 10, 20, 20, '', fntOutline, taLeft);
  Label_HouseConstructionStone := TKMLabel.Create(Panel_Build, 39 + 55, top + 10, 20, 20, '', fntOutline, taLeft);

  for I := 0 to High(fSubMenuActionsEvents) do
    fSubMenuActionsEvents[I] := Town_BuildChange;

  fSubMenuActionsCtrls[0,0] := Button_BuildRoad;
  fSubMenuActionsCtrls[1,0] := Button_BuildField;
  fSubMenuActionsCtrls[2,0] := Button_BuildWine;
  fSubMenuActionsCtrls[3,0] := Button_BuildCancel;

  for I := 4 to High(fSubMenuActionsCtrls) do
    fSubMenuActionsCtrls[I, 0] := Button_Build[I-3];
end;


procedure TKMMapEdTownHouses.BuildRoad;
begin
  Button_BuildRoad.Down := True;
  Town_BuildChange(Button_BuildRoad);
end;


procedure TKMMapEdTownHouses.BuildField;
begin
  Button_BuildField.Down := True;
  Town_BuildChange(Button_BuildField);
end;


procedure TKMMapEdTownHouses.BuildWine;
begin
  Button_BuildWine.Down := True;
  Town_BuildChange(Button_BuildWine);
end;


procedure TKMMapEdTownHouses.BuildCancel;
begin
  Button_BuildCancel.Down := True;
  Town_BuildChange(Button_BuildCancel);
end;


procedure TKMMapEdTownHouses.UpdateField(Sender: TObject; aIncrement: Integer);
begin
  if Sender = Button_BuildField then
  begin
    if gCursor.Mode = cmField then
      gCursor.MapEdFieldAge := (gCursor.MapEdFieldAge + aIncrement + CORN_STAGES_COUNT) mod CORN_STAGES_COUNT;
    gCursor.Mode := cmField;
    Button_BuildField.Caption := IntToStr(gCursor.MapEdFieldAge + 1);
  end
  else
  if Sender = Button_BuildWine then
  begin
    if gCursor.Mode = cmWine then
      gCursor.MapEdWineFieldAge :=  (gCursor.MapEdWineFieldAge + aIncrement + WINE_STAGES_COUNT) mod WINE_STAGES_COUNT;
    gCursor.Mode := cmWine;
    Button_BuildWine.Caption := IntToStr(gCursor.MapEdWineFieldAge + 1);
  end;
end;


procedure TKMMapEdTownHouses.Town_FieldShiftClick(Sender: TObject; Shift: TShiftState);
var
  stageInc: Integer;
begin
  if ssRight in Shift then
    stageInc := -1
  else
    stageInc := 1;

  UpdateField(Sender, stageInc);
end;


procedure TKMMapEdTownHouses.Town_FieldMWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean);
begin
  UpdateField(Sender, WheelSteps);
  aHandled := True;
end;


procedure TKMMapEdTownHouses.Town_BuildChange(Sender: TObject);
var
  I: Integer;
begin
  //Reset cursor and see if it needs to be changed
  gCursor.Mode := cmNone;

  if Sender = Button_BuildCancel then
    gCursor.Mode := cmErase
  else
  if Sender = Button_BuildRoad then
    gCursor.Mode := cmRoad
  else
  if Sender = Button_BuildField then
    Town_FieldShiftClick(Sender, [])
  else
  if Sender = Button_BuildWine then
    Town_FieldShiftClick(Sender, [])
  else

  for I := 1 to GUI_HOUSE_COUNT do
    if GUIHouseOrder[I] <> htNone then
      if Sender = Button_Build[I] then
      begin
        gCursor.Mode := cmHouses;
        gCursor.Tag1 := Byte(GUIHouseOrder[I]);
      end;

  Town_BuildRefresh;
end;


procedure TKMMapEdTownHouses.Town_BuildRefresh;
var
  I: Integer;
begin
  Button_BuildCancel.Down := (gCursor.Mode = cmErase);
  Button_BuildRoad.Down   := (gCursor.Mode = cmRoad);
  Button_BuildField.Down  := (gCursor.Mode = cmField);
  Button_BuildWine.Down   := (gCursor.Mode = cmWine);

  Label_HouseConstructionWood.Caption := '-';
  Label_HouseConstructionStone.Caption := '-';

  for I := 1 to GUI_HOUSE_COUNT do
    if GUIHouseOrder[I] <> htNone then
    begin
      Button_Build[I].Down := (gCursor.Mode = cmHouses) and (gCursor.Tag1 = Byte(GUIHouseOrder[I]));
      if Button_Build[I].Down then
      begin
        Label_HouseConstructionWood.Caption  := IntToStr(gResHouses[GUIHouseOrder[I]].WoodCost);
        Label_HouseConstructionStone.Caption := IntToStr(gResHouses[GUIHouseOrder[I]].StoneCost);
      end;
    end;

  if Button_BuildRoad.Down then
  begin
    Label_HouseConstructionWood.Caption  := '-';
    Label_HouseConstructionStone.Caption := '1';
  end else if Button_BuildField.Down then
  begin
    Label_HouseConstructionWood.Caption  := '-';
    Label_HouseConstructionStone.Caption := '-';
  end else if Button_BuildWine.Down then
  begin
    Label_HouseConstructionWood.Caption  := '1';
    Label_HouseConstructionStone.Caption := '-';
  end;
end;


procedure TKMMapEdTownHouses.Hide;
begin
  Panel_Build.Hide;
end;


procedure TKMMapEdTownHouses.Show;
begin
  Town_BuildRefresh;
  Panel_Build.Show;
end;


function TKMMapEdTownHouses.Visible: Boolean;
begin
  Result := Panel_Build.Visible;
end;


procedure TKMMapEdTownHouses.UpdateHotkeys;
var
  I: Integer;
begin
  Button_BuildRoad.Hint     := GetHintWHotkey(TX_BUILD_ROAD_HINT, kfMapedSubMenuAction1);
  Button_BuildField.Hint    := GetHintWHotkey(TX_BUILD_FIELD_HINT, kfMapedSubMenuAction2);
  Button_BuildWine.Hint     := GetHintWHotkey(TX_BUILD_WINE_HINT, kfMapedSubMenuAction3);
  Button_BuildCancel.Hint   := GetHintWHotkey(TX_BUILD_CANCEL_HINT, kfMapedSubMenuAction4);

  for I := 1 to GUI_HOUSE_COUNT do
    if GUIHouseOrder[I] <> htNone then
    begin
      if InRange(I-1, 0, High(fSubMenuActionsCtrls) - 4) then
        Button_Build[I].Hint := GetHintWHotkey(gResHouses[GUIHouseOrder[I]].HouseName, MAPED_SUBMENU_ACTIONS_HOTKEYS[I+3])
      else
        Button_Build[I].Hint := gResHouses[GUIHouseOrder[I]].HouseName;
    end;
end;


procedure TKMMapEdTownHouses.UpdateState;
begin
  Town_BuildRefresh;
end;


procedure TKMMapEdTownHouses.UpdateStateIdle;
begin
  // Not used atm...
end;


end.
