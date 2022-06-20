object RXXForm1: TRXXForm1
  Left = 72
  Top = 90
  BorderIcons = [biSystemMenu, biMinimize]
  Caption = 'RXX Packer'
  ClientHeight = 400
  ClientWidth = 289
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    289
    400)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 16
    Top = 176
    Width = 3
    Height = 13
  end
  object Label2: TLabel
    Left = 16
    Top = 220
    Width = 89
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'Sprites load dir'
    ExplicitTop = 264
  end
  object Label3: TLabel
    Left = 16
    Top = 271
    Width = 110
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'Packed sprites save dir'
    ExplicitTop = 315
  end
  object btnPackRXX: TButton
    Left = 16
    Top = 357
    Width = 257
    Height = 25
    Anchors = [akLeft, akRight, akBottom]
    Caption = 'Pack'
    TabOrder = 0
    OnClick = btnPackRXXClick
    ExplicitTop = 354
  end
  object ListBox1: TListBox
    Left = 16
    Top = 16
    Width = 257
    Height = 153
    Anchors = [akLeft, akTop, akRight]
    ItemHeight = 13
    MultiSelect = True
    TabOrder = 1
  end
  object btnUpdateList: TButton
    Left = 16
    Top = 326
    Width = 257
    Height = 25
    Anchors = [akLeft, akRight, akBottom]
    Caption = 'Update List'
    TabOrder = 2
    OnClick = btnUpdateListClick
    ExplicitTop = 323
  end
  object edSpritesLoadDir: TEdit
    Left = 16
    Top = 240
    Width = 257
    Height = 21
    Anchors = [akLeft, akRight, akBottom]
    TabOrder = 3
    OnChange = edSpritesLoadDirChange
    ExplicitTop = 284
  end
  object chkPackToRXA: TCheckBox
    Left = 160
    Top = 195
    Width = 89
    Height = 17
    Caption = 'Pack to RXA'
    TabOrder = 4
    OnClick = chkPackToRXAClick
  end
  object chkAddRXXHeader: TCheckBox
    Left = 160
    Top = 215
    Width = 113
    Height = 17
    Caption = 'Add Version header'
    Checked = True
    State = cbChecked
    TabOrder = 5
  end
  object chkPackToRXX: TCheckBox
    Left = 160
    Top = 175
    Width = 89
    Height = 17
    Caption = 'Pack to RXX'
    Checked = True
    State = cbChecked
    TabOrder = 6
    OnClick = chkPackToRXXClick
  end
  object edSpritesSaveDir: TEdit
    Left = 16
    Top = 291
    Width = 257
    Height = 21
    Anchors = [akLeft, akRight, akBottom]
    TabOrder = 7
    OnChange = edSpritesLoadDirChange
    ExplicitTop = 335
  end
end
