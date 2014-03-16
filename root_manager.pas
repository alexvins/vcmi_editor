{ This file is a part of Map editor for VCMI project

  Copyright (C) 2013 Alexander Shishkin alexvins@users.sourceforge.net

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or (at your option)
  any later version.

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
  MA 02111-1307, USA.
}
unit root_manager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LazLogger,
  Forms, Controls,
  progress_form, filesystem_base,
  filesystem, terrain, objects, editor_graphics, lists_manager, OpenGLContext, editor_gl, GLext;

type

  { TRootManager }

  TRootManager = class(TDataModule)
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
    FProgressForm:    TProgressForm;
    FHiddenForm:      TForm;
    FResourceManager: TFSManager;

    FTerrianManager:  TTerrainManager;
    FObjManager:      TObjectsManager;
    FGraphicsManager: TGraphicsManager;
    FListsManager:    TListsManager;

    FGLContext: TOpenGLControl;

    //FShaderContext: TShaderContext;

    function GetResourceManager: IResourceLoader;
  public
    procedure InitComplete;

    property ProgressForm: TProgressForm read FProgressForm;
    property ResourceManager: IResourceLoader read GetResourceManager;

    property GraphicsManger: TGraphicsManager read FGraphicsManager;
    property ObjectsManager: TObjectsManager read FObjManager;
    property TerrainManager: TTerrainManager read FTerrianManager;
    property SharedContext: TOpenGLControl read FGLContext;
    property ListsManager: TListsManager read FListsManager;
  end;

var
  RootManager: TRootManager;

implementation

uses
  Math, editor_types;

{$R *.lfm}

{ TRootManager }

procedure TRootManager.DataModuleCreate(Sender: TObject);
var
  log_name: string;
begin
  log_name := ExtractFilePath(ParamStr(0)) + 'editor.log';

  if FileExistsUTF8(log_name) then
  begin
    DeleteFileUTF8(log_name);
  end;

  FHiddenForm := TForm.CreateNew(Self);

  DebugLogger.LogName := log_name;
  DebugLogger.CloseLogFileBetweenWrites := True;


  FGLContext := TOpenGLControl.Create(Self);
  FGLContext.Parent := FHiddenForm;

  if not FGLContext.MakeCurrent() then
  begin
    Application.Terminate;
    raise Exception.Create('Unable to switch GL context');
  end;

  if not Load_GL_VERSION_2_1() then
  begin
    Application.Terminate;
    raise Exception.Create('Error loading OpenGL 2.1');
  end;

  if not Load_GL_EXT_texture_rectangle() then
  begin
    Application.Terminate;
    raise Exception.Create('Error loading required extension EXT_texture_rectangle');
  end;

  FProgressForm := TProgressForm.Create(Self);
  FProgressForm.Visible := True;
  ProgressForm.StageCount := ifthen(Paramcount > 0, 5, 4);

  Application.ProcessMessages;

  ShaderContext := TShaderContext.Create;
  ShaderContext.Init;

  //stage 1
  ProgressForm.NextStage('Scanning filesystem.');

  FResourceManager := TFSManager.Create(self);
  FResourceManager.Load(FProgressForm);

  FGraphicsManager := TGraphicsManager.Create(FResourceManager);

  FListsManager := TListsManager.Create(FResourceManager);
  FListsManager.Load;

  FListsManager.LoadFactions(FResourceManager.GameConfig.Factions);


  //stage 2
  ProgressForm.NextStage('Loading terrain graphics.');
  FTerrianManager := TTerrainManager.Create(FGraphicsManager);

  FTerrianManager.LoadConfig;
  FTerrianManager.LoadTerrainGraphics;

  //stage 3
  ProgressForm.NextStage('Loading objects.');

  FObjManager := TObjectsManager.Create(FGraphicsManager);
  FObjManager.LoadObjects(RootManager.ProgressForm);

end;

procedure TRootManager.DataModuleDestroy(Sender: TObject);
begin
  ShaderContext.Free;
  ShaderContext := nil;
end;

function TRootManager.GetResourceManager: IResourceLoader;
begin
  Result := FResourceManager;
end;

procedure TRootManager.InitComplete;
begin
  if FProgressForm.Visible then
  begin
    FProgressForm.Close;
  end;

end;

end.

