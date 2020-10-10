unit unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, StdCtrls,
  CastleControl, CastleCameras, CastleApplicationProperties, CastleKeysMouse,
  CastleSceneCore, CastleVectors, CastleScene, CastleViewport,
  CastleTimeUtils, CastleURIUtils, X3DNodes, CastleLCLUtils;

type

  { Tform1 }

  Tform1 = class(TForm)
    CastleControlBase1: TCastleControlBase;
    Memo1: TMemo;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    procedure CastleControlBase1BeforeRender(Sender: TObject);
    procedure CastleControlBase1Press(Sender: TObject;
      const Event: TInputPressRelease);
    procedure CastleControlBase1Release(Sender: TObject;
      const Event: TInputPressRelease);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    Viewport: TCastleViewport;
    Scene: TCastleScene;
    RequestChangeTexture: Boolean;
    RequestRotateModel: Boolean;
    TextureList: TStringList;
    SavedTheta: Double;
  public
    procedure ChangeTexture(const Model: TCastleScene; const TextureUrl: String);
    procedure LoadScene(filename: String);
  end;

var
  form1: Tform1;

const
  // How many seconds to take to rotate the scene
  SecsPerRot = 4;

function RecursiveFileList(const Uri: String; FileList: TStringList = nil; const Recurse: Boolean = False): TStringList;

implementation

function RecursiveFileList(const Uri: String; FileList: TStringList = nil; const Recurse: Boolean = False): TStringList;
const
{$IFDEF WINDOWS}
  SearchMask = '*.*';
{$ELSE}
  SearchMask = '*';
{$ENDIF}
var
  Info: TRawbyteSearchRec;
  SearchPath: String;
begin
  SearchPath := URIToFilenameSafe(Uri);
  if FileList = nil then
    begin
      FileList := TStringList.Create;
      FileList.OwnsObjects := True;
    end;

  if FindFirst (SearchPath + DirectorySeparator + SearchMask,faAnyFile,Info)=0 then
    begin
      repeat
      with Info do
        begin
          if (Attr and faDirectory) = faDirectory then
            begin
              if ((Name <> '.') and (Name <> '..')) then
                begin
                  if Recurse then
                    FileList.AddObject(SearchPath + DirectorySeparator + Name, RecursiveFileList(SearchPath + DirectorySeparator + Name, nil));
                end;
            end
          else
            begin
              FileList.AddObject(SearchPath + DirectorySeparator + Name, nil);
            end;
        end;
      until FindNext(Info)<>0;
    FindClose(Info);
    end;

  Result := FileList;
end;

{ Tform1 }

{$R *.lfm}

procedure Tform1.ChangeTexture(const Model: TCastleScene; const TextureUrl: String);
var
  TextureNode: TImageTextureNode;
begin
  // Find the texture node in the model
  TextureNode := Model.Node('objectTexture') as TImageTextureNode;
  // Change the texture
  TextureNode.SetUrl(TextureUrl);
end;

procedure Tform1.CastleControlBase1BeforeRender(Sender: TObject);
var
  idx: Integer;
  theta: Single;
begin
  // If the user has requested the model rotates
  if RequestRotateModel then
    begin
      // Set angle (theta) to revolve completely once every SecsPerRot
      theta := (((CastleGetTickCount64 mod
                 (SecsPerRot * 1000)) /
                 (SecsPerRot * 1000)) * (Pi * 2)) + SavedTheta;

      // Rotate the scene in Y
      // Change to Vector4(1, 0, 0, theta); to rotate in X
      Scene.Rotation := Vector4(0, 1, 0, theta);
    end;

  // If the user has requested a texture change
  if RequestChangeTexture then
    begin
      // Pick a random texturem chage to it and reset the change texture request flag
      idx := Random(TextureList.Count);
      ChangeTexture(Scene, TextureList[idx]);
      RequestChangeTexture := False;
    end;

end;

procedure Tform1.CastleControlBase1Press(Sender: TObject;
  const Event: TInputPressRelease);
var
  CurrentTheta: Single;
begin
  // If user presses the space bar
  if Event.IsKey(keySpace) then
    begin
  // Request a texture change
      RequestChangeTexture := True;
    end;

  // If user presses the R key
  if Event.IsKey(keyR) then
    begin
      // Toggle the model rotation
      RequestRotateModel := not(RequestRotateModel);

      if RequestRotateModel then
        begin
          CurrentTheta := ((CastleGetTickCount64 mod
                           (SecsPerRot * 1000)) /
                           (SecsPerRot * 1000)) * (Pi * 2);
          SavedTheta := SavedTheta - CurrentTheta;
        end
      else
        begin
          SavedTheta := Scene.Rotation.W; // W is the angle of a Vector4
        end;
    end;
end;

procedure Tform1.CastleControlBase1Release(Sender: TObject;
  const Event: TInputPressRelease);
begin
end;

procedure Tform1.LoadScene(filename: String);
begin
  // Set up the main viewport
  Viewport := TCastleViewport.Create(Application);
  // Use all the viewport
  Viewport.FullSize := true;
  // Automatically position the camera
  Viewport.AutoCamera := true;
  // Use default navigation keys
  Viewport.AutoNavigation := true;

  // Add the viewport to the CGE control
  CastleControlBase1.Controls.InsertFront(Viewport);

  // Create a scene
  Scene := TCastleScene.Create(Application);
  // Load a model into the scene
  Scene.load(filename);
  // Add the scene to the viewport
  Viewport.Items.Add(Scene);

  // Tell the control this is the main scene so it gets some lighting
  Viewport.Items.MainScene := Scene;
end;

procedure Tform1.FormCreate(Sender: TObject);
var
  idx: Integer;
begin
  // Initialize stuff
  RequestChangeTexture := False;
  RequestRotateModel := False;
  SavedTheta := 0;

  // Load and list the texture filenames
  TextureList := RecursiveFileList('castle-data:/textures');
  Memo1.Clear;
  Memo1.Lines.Add('Textures');
  for idx := 0 to TextureList.Count - 1 do
    Memo1.Lines.Add(TextureList[idx]);

  // By default deisplay the viewport
  PageControl1.ActivePage := TabSheet1;

  // If PageControl1 is a Tabstop then biewport misses keypresses (hack)
  PageControl1.TabStop := False;

  // Load model
  LoadScene('castle-data:/models/male.x3dv');
end;

procedure Tform1.FormDestroy(Sender: TObject);
begin
  FreeAndNil(TextureList);
end;

end.

