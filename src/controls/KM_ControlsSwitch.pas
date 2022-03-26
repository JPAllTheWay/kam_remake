﻿unit KM_ControlsSwitch;
{$I KaM_Remake.inc}
interface
uses
  Classes, Controls,
  KromOGLUtils,
  KM_Controls,
  KM_ResFonts;


type
  TKMRadioGroupItem = record
    Text: UnicodeString;
    Hint: UnicodeString;
    Enabled: Boolean;
    Visible: Boolean;
  end;


  { TKMRadioGroup }
  TKMRadioGroup = class(TKMControl)
  private
    fItemIndex: Integer;
    fCount: Integer;
    fItems: array of TKMRadioGroupItem;
    fFont: TKMFont;
    fMouseOverItem: SmallInt;
    fOnChange: TNotifyEvent;
    procedure UpdateMouseOverPositions(X,Y: Integer);
    function GetItem(aIndex: Integer): TKMRadioGroupItem;
    function GetItemIndexByRow(aRowIndex: Integer): Integer;
    function GetVisibleCount: Integer;
    function GetLineHeight: Single;
    function GetIsSelected: Boolean;
  protected
    function GetHint: UnicodeString; override;
  public
    AllowUncheck: Boolean; //Do we allow to uncheck selected element ? Usually not, but its possible
    DrawChkboxOutline: Boolean;
    LineColor: TColor4; //color of outline
    LineWidth: Byte;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont);

    procedure Add(const aText: String; aEnabled: Boolean = True); overload;
    procedure Add(const aText: String; aEnabled, aVisible: Boolean); overload;
    procedure Add(const aText, aHint: String; aEnabled: Boolean = True; aVisible: Boolean = True); overload;
    procedure Clear;
    property Count: Integer read fCount;
    property IsSelected: Boolean read GetIsSelected;
    property VisibleCount: Integer read GetVisibleCount;
    property ItemIndex: Integer read fItemIndex write fItemIndex;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;
    property Item[aIndex: Integer]: TKMRadioGroupItem read GetItem;
    procedure SetItemEnabled(aIndex: Integer; aEnabled: Boolean; aUncheckDisabled: Boolean = True);
    procedure SetItemVisible(aIndex: Integer; aEnabled: Boolean);
    procedure CheckFirstCheckable;
    property LineHeight: Single read GetLineHeight;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure Paint; override;
  end;


implementation
uses
  SysUtils, Math,
  KM_RenderUI,
  KM_Resource,
  KM_Defaults;


{ TKMRadioGroup }
constructor TKMRadioGroup.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fFont := aFont;
  fItemIndex := -1;
  LineWidth := 1;
  LineColor := clChkboxOutline;
  AllowUncheck := False;
end;


procedure TKMRadioGroup.Add(const aText: String; aEnabled: Boolean);
begin
  Add(aText, '', aEnabled);
end;


procedure TKMRadioGroup.Add(const aText: String; aEnabled, aVisible: Boolean);
begin
  Add(aText, '', aEnabled, aVisible);
end;


procedure TKMRadioGroup.Add(const aText, aHint: String; aEnabled: Boolean = True; aVisible: Boolean = True);
begin
  if fCount >= Length(fItems) then
    SetLength(fItems, fCount + 8);

  fItems[fCount].Text := aText;
  fItems[fCount].Hint := aHint;
  fItems[fCount].Enabled := aEnabled;
  fItems[fCount].Visible := aVisible;

  Inc(fCount);
end;


procedure TKMRadioGroup.Clear;
begin
  fCount := 0;
end;


procedure TKMRadioGroup.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  changed: Boolean;
begin
  if (csDown in State) and (Button = mbLeft) then
  begin
    UpdateMouseOverPositions(X,Y);
    if (fMouseOverItem <> -1) and fItems[fMouseOverItem].Enabled then
    begin
      changed := False;
      if (fMouseOverItem = fItemIndex) then
      begin
        if AllowUncheck then
        begin
          fItemIndex := -1; //Uncheck
          changed := True;
        end;
      end else begin
        fItemIndex := fMouseOverItem;
        changed := True;
      end;

      if changed and Assigned(fOnChange) then
      begin
        fOnChange(Self);
        Exit; //Don't generate OnClick after OnChanged event (esp. when reloading Game on local change)
      end;
    end;
  end;

  inherited; //There are OnMouseUp and OnClick events there
end;


procedure TKMRadioGroup.MouseMove(X,Y: Integer; Shift: TShiftState);
begin
  inherited;
  UpdateMouseOverPositions(X,Y);
end;


procedure TKMRadioGroup.UpdateMouseOverPositions(X,Y: Integer);
var
  mouseOverRow, itemIndex: Integer;
begin
  fMouseOverItem := -1;

  if InRange(Y, AbsTop, AbsTop + Height) and (LineHeight > 0) then
  begin
    mouseOverRow := EnsureRange((Y - AbsTop) div Round(LineHeight), 0, VisibleCount - 1);
    itemIndex := GetItemIndexByRow(mouseOverRow);
    if (itemIndex <> -1) and InRange(X, AbsLeft, AbsLeft + LineHeight + gRes.Fonts[fFont].GetTextSize(fItems[itemIndex].Text).X) then
      fMouseOverItem := itemIndex;
  end;
end;


function TKMRadioGroup.GetItem(aIndex: Integer): TKMRadioGroupItem;
begin
  Assert(aIndex < fCount, 'Can''t get radio group item for index ' + IntToStr(aIndex));
  Result := fItems[aIndex];
end;


function TKMRadioGroup.GetItemIndexByRow(aRowIndex: Integer): Integer;
var
  I, K: Integer;
begin
  Assert(aRowIndex < VisibleCount, 'GetItemByRow: aRowIndex >= VisibleCount');
  K := 0;
  Result := -1;
  for I := 0 to fCount - 1 do
  begin
    if not fItems[I].Visible then Continue;
    if aRowIndex = K then
    begin
      Result := I;
      Exit;
    end;
    Inc(K);
  end;
end;


function TKMRadioGroup.GetVisibleCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to fCount - 1 do
    if fItems[I].Visible then
      Inc(Result);
end;


function TKMRadioGroup.GetLineHeight: Single;
begin
  Result := IfThen(VisibleCount > 0, Height / VisibleCount, Height);
end;


function TKMRadioGroup.GetIsSelected: Boolean;
begin
  Result := fItemIndex <> -1;
end;


procedure TKMRadioGroup.SetItemEnabled(aIndex: Integer; aEnabled: Boolean; aUncheckDisabled: Boolean = True);
begin
  Assert(aIndex < fCount, 'Can''t SetItemEnabled for index ' + IntToStr(aIndex));
  fItems[aIndex].Enabled := aEnabled;

  // Reset item index, if this item was selected
  if aUncheckDisabled and not aEnabled and (fItemIndex = aIndex) then
    fItemIndex := -1;
end;


procedure TKMRadioGroup.SetItemVisible(aIndex: Integer; aEnabled: Boolean);
begin
  Assert(aIndex < fCount, 'Can''t SetItemVisible for index ' + IntToStr(aIndex));
  fItems[aIndex].Visible := aEnabled;
end;


procedure TKMRadioGroup.CheckFirstCheckable;
var
  I: Integer;
begin
  if fItemIndex <> -1 then Exit;

  for I := 0 to fCount - 1 do
    if fItems[I].Enabled and fItems[I].Visible then
    begin
      fItemIndex := I;
      Exit;
    end;
end;


function TKMRadioGroup.GetHint: UnicodeString;
begin
  Result := inherited GetHint;
  if Result = '' then
  begin
    if fMouseOverItem <> -1 then
      Result := fItems[fMouseOverItem].Hint;
  end;
end;


//We can replace it with something better later on. For now [x] fits just fine
//Might need additional graphics to be added to gui.rx
//Some kind of box with an outline, darkened background and shadow maybe, similar to other controls.
procedure TKMRadioGroup.Paint;
const
  FONT_COL: array [Boolean] of TColor4 = ($FF888888, $FFFFFFFF);
var
  CheckSize: Integer;
  I, VisibleI: Integer;
begin
  inherited;
  if (Count = 0) or (VisibleCount = 0) then Exit; //Avoid dividing by zero

  CheckSize := gRes.Fonts[fFont].GetTextSize('x').Y + 1;

  VisibleI := 0;
  for I := 0 to Count - 1 do
  begin
    if not fItems[I].Visible then
      Continue;

    TKMRenderUI.WriteBevel(AbsLeft, AbsTop + Round(VisibleI * LineHeight), CheckSize-4, CheckSize-4, 1, 0.3);
    if DrawChkboxOutline then
      TKMRenderUI.WriteOutline(AbsLeft, AbsTop + Round(VisibleI * LineHeight), CheckSize-4, CheckSize-4, LineWidth, LineColor);

    if fItemIndex = I then
      TKMRenderUI.WriteText(AbsLeft + (CheckSize - 4) div 2, AbsTop + Round(VisibleI * LineHeight) - 1, 0,
                            'x', fFont, taCenter, FONT_COL[Enabled and fItems[I].Enabled]);

    // Caption
    TKMRenderUI.WriteText(AbsLeft + CheckSize, AbsTop + Round(VisibleI * LineHeight), Width - Round(LineHeight),
                          fItems[I].Text, fFont, taLeft, FONT_COL[Enabled and fItems[I].Enabled]);
    Inc(VisibleI);
  end;
end;


end.

