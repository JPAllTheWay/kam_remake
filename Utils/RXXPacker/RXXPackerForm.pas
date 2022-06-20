unit RXXPackerForm;
{$I ..\..\KaM_Remake.inc}
interface
uses
  Classes, Controls, Dialogs,
  ExtCtrls, Forms, Graphics, Spin, StdCtrls, SysUtils, TypInfo,
  {$IFDEF MSWindows} Windows, {$ENDIF}
  {$IFDEF FPC} LResources, LCLIntf, {$ENDIF}
  RXXPackerProc, KM_Defaults, KM_Log, KM_Pics, KM_ResPalettes, KM_ResSprites;


type
  TRXXPackData = record
    Name: String;
    Id: Integer;
  end;

  TRXXForm1 = class(TForm)
    btnPackRXX: TButton;
    ListBox1: TListBox;
    Label1: TLabel;
    btnUpdateList: TButton;
    edSpritesLoadDir: TEdit;
    Label2: TLabel;
    chkPackToRXA: TCheckBox;
    chkAddRXXHeader: TCheckBox;
    chkPackToRXX: TCheckBox;
    Label3: TLabel;
    edSpritesSaveDir: TEdit;
    procedure btnPackRXXClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnUpdateListClick(Sender: TObject);
    procedure chkPackToRXXClick(Sender: TObject);
    procedure chkPackToRXAClick(Sender: TObject);
    procedure edSpritesLoadDirChange(Sender: TObject);
  private
    fPalettes: TKMResPalettes;
    fRxxPacker: TKMRXXPacker;
    fPacksData: array of TRXXPackData;
    fPacksCnt: Integer;
    fSettingsPath: string;
    fUpdating: Boolean;

    procedure UpdateUI;
    function AddPackData(aName: String; aId: Integer): TRXXPackData;

    procedure UpdateList;

    procedure LoadSettings;
    procedure SaveSettings;
  end;


var
  RXXForm1: TRXXForm1;


implementation
uses
  INIFiles,
  KM_ResHouses, KM_ResUnits, KM_ResTypes,
  KM_Points;

{$R *.dfm}

function TRXXForm1.AddPackData(aName: String; aId: Integer): TRXXPackData;
begin
  Result.Name := aName;
  Result.Id := aId;
  Inc(fPacksCnt);
  SetLength(fPacksData, fPacksCnt);
  fPacksData[fPacksCnt - 1] := Result;
end;


procedure TRXXForm1.UpdateList;
var
  RT: TRXType;
  packData: TRXXPackData;
begin
  fRXXPacker.SpritesLoadDir := edSpritesLoadDir.Text;

  ListBox1.Items.Clear;
  fPacksCnt := 0;
  SetLength(fPacksData, fPacksCnt);
  for RT := Low(TRXType) to High(TRXType) do
    if (RT = rxTiles) //Tiles are always in the list
    or FileExists(fRXXPacker.SpritesLoadDir + 'SpriteResource\' + RXInfo[RT].FileName + '.rx') then
    begin
      packData := AddPackData(GetEnumName(TypeInfo(TRXType), Integer(RT)), Integer(RT));
      ListBox1.Items.Add(packData.Name);
    end;

  if ListBox1.Items.Count = 0 then
  begin
    ShowMessage('No .RX file was found in' + #10 + ExeDir + 'SpriteResource\');
    btnPackRXX.Enabled := False;
  end
  else
  begin
    btnPackRXX.Enabled := True;
    ListBox1.ItemIndex := 0;
    ListBox1.SelectAll;
  end;
end;


procedure TRXXForm1.btnUpdateListClick(Sender: TObject);
begin
  btnUpdateList.Enabled := false;

  UpdateList;

  btnUpdateList.Enabled := true;
end;


procedure TRXXForm1.UpdateUI;
begin
  btnPackRXX.Enabled := chkPackToRXX.Checked or chkPackToRXA.Checked;
end;


procedure TRXXForm1.chkPackToRXAClick(Sender: TObject);
begin
  UpdateUI;
end;


procedure TRXXForm1.chkPackToRXXClick(Sender: TObject);
begin
  UpdateUI;
end;


procedure TRXXForm1.edSpritesLoadDirChange(Sender: TObject);
begin
  if fUpdating then Exit;

  SaveSettings;
end;


procedure TRXXForm1.FormCreate(Sender: TObject);
begin
  ExeDir := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\');

  Caption := 'RXX Packer (' + GAME_REVISION + ')';

  //Although we don't need them in this tool, these are required to load sprites
  gLog := TKMLog.Create(ExeDir + 'RXXPacker.log');

  fUpdating := True;
  edSpritesLoadDir.Text := ExeDir;
  fUpdating := False;

  fRXXPacker := TKMRXXPacker.Create(ExeDir);
  fPalettes := TKMResPalettes.Create;
  fPalettes.LoadPalettes(ExeDir + 'data\gfx\');

  fSettingsPath := ExtractFilePath(ParamStr(0)) + 'RXXPacker.ini';
  LoadSettings;

  fPacksCnt := 0;
  SetLength(fPacksData, 0);

  UpdateList;
end;


procedure TRXXForm1.FormDestroy(Sender: TObject);
begin
  FreeAndNil(fPalettes);
  FreeAndNil(gLog);
  FreeAndNil(fRXXPacker);
end;


procedure TRXXForm1.LoadSettings;
var
  ini: TINIFile;
begin
  fUpdating := True;

  ini := TINIFile.Create(fSettingsPath);

  edSpritesLoadDir.Text := ini.ReadString('SETTINGS',  'SpritesLoadDir', ExeDir);
  edSpritesSaveDir.Text := ini.ReadString('SETTINGS',  'SpritesSaveDir', ExeDir);

  FreeAndNil(ini);

  fUpdating := False;

  if not FileExists(fSettingsPath) then
    SaveSettings;
end;


procedure TRXXForm1.SaveSettings;
var
  ini: TINIFile;
begin
  ini := TINIFile.Create(fSettingsPath);

  ini.WriteString('SETTINGS',  'SpritesLoadDir', edSpritesLoadDir.Text);
  ini.WriteString('SETTINGS',  'SpritesSaveDir', edSpritesSaveDir.Text);

  FreeAndNil(ini);
end;


procedure TRXXForm1.btnPackRXXClick(Sender: TObject);
var
  RT: TRXType;
  I: Integer;
  tick: Cardinal;
begin
  btnPackRXX.Enabled := False;
  chkPackToRXX.Enabled := False;
  chkPackToRXA.Enabled := False;
  chkAddRXXHeader.Enabled := False;
  tick := GetTickCount;

  fRXXPacker.SpritesLoadDir := edSpritesLoadDir.Text;
  fRXXPacker.SpritesSaveDir := edSpritesSaveDir.Text;
  fRxxPacker.PackToRXX      := chkPackToRXX.Checked;
  fRxxPacker.PackToRXA      := chkPackToRXA.Checked;
  fRxxPacker.AddRXXHeader   := chkAddRXXHeader.Checked;

  Assert(DirectoryExists(fRXXPacker.SpritesLoadDir + SPRITES_RES_DIR + '\'),
         'Cannot find ' + fRXXPacker.SpritesLoadDir + SPRITES_RES_DIR + '\ folder.' + #10#13 +
         'Please make sure this folder exists.');

  for I := 0 to ListBox1.Items.Count - 1 do
    if ListBox1.Selected[I] then
    begin
      RT := TRXType(fPacksData[I].Id);

      fRxxPacker.Pack(RT, fPalettes);

      ListBox1.Selected[I] := False;
      ListBox1.Refresh;
    end;

  Label1.Caption := 'Elapsed: ' + IntToStr(GetTickCount - tick) + ' ms';

  btnPackRXX.Enabled := True;
  chkPackToRXX.Enabled := True;
  chkPackToRXA.Enabled := True;
  chkAddRXXHeader.Enabled := True;
end;


{$IFDEF FPC}
initialization
  {$i RXXPackerForm.lrs}
{$ENDIF}


end.