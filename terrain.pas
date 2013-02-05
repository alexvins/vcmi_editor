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
unit terrain;

{$I compilersetup.inc}

interface

uses
  Classes, SysUtils,
  gvector,
  editor_types, def, fpjson, vcmi_json,
  filesystem_base, editor_classes;

type

  TTerrainGroup = (
    NORMAL,
    DIRT,
    SAND,
    WATER,
    ROCK);

type

  { TWeightedRule }

  TWeightedRule = object
    name : string;
    points: Integer;
    constructor Create();
    function IsStandartRule: boolean;
  end;

  TRules = specialize TVector<TWeightedRule>;

  TMapping = record
    Lower, Upper: Integer;
  end;

  TMappings = specialize TVector<TMapping>;

  {$push}
  {$m+}

  { TPattern }

  TPattern = class (TCollectionItem)
  private
    FData: array[0..8] of TRules;
    FMappings: TMappings;
  private
    FFlipMode: string;
    FStrData: TStringList;
    FID: string;
    FMapping: string;
    FMinPoints: integer;
    function GetData: TStrings;
    procedure SetFlipMode(AValue: string);
    procedure SetID(AValue: string);
    procedure SetMapping(AValue: string);
    procedure SetMinPoints(AValue: integer);
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;

    procedure Loaded;
  published
    property Data: TStrings read GetData;
    property Mapping: string read FMapping write SetMapping;
    property ID:string read FID write SetID;
    property MinPoints: integer read FMinPoints write SetMinPoints;
    property FlipMode:string read FFlipMode write SetFlipMode;
  end;

  { TPatterns }

  TPatterns = class(TArrayCollection)
  public
    constructor Create;
    procedure Loaded;
  end;

  { TTerrainPatternConfig }

  TTerrainPatternConfig = class
  private
    FDirt: TPatterns;
    FNormal: TPatterns;
    FRock: TPatterns;
    FSand: TPatterns;
    FWater: TPatterns;

  public
    constructor Create;
    destructor Destroy; override;

    procedure ConvertConfig;

    function GetGroupConfig(AGroup: TTerrainGroup):TPatterns;

    function GetTerrainConfig(ATerrain: TTerrainType):TPatterns;

    function GetConfigById(AGroup: TTerrainGroup; AId:string): TPattern;
  published
    property Dirt: TPatterns read FDirt;
    property Normal: TPatterns read FNormal;
    property Sand: TPatterns read FSand;
    property Water: TPatterns read FWater;
    property Rock: TPatterns read FRock;
  end;


  {$pop}

  { TTerrainManager }

  TTerrainManager = class (TGraphicsCosnumer)
  private
    FTerrainDefs: array [TTerrainType] of TDef;

    FRiverDefs: array [TRiverType.clearRiver..TRiverType.lavaRiver] of TDef;

    FRoadDefs: array [TRoadType.dirtRoad..TRoadType.cobblestoneRoad] of TDef;

    FPatternConfig: TTerrainPatternConfig;
    FDestreamer: TVCMIJSONDestreamer;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure LoadConfig;

    procedure LoadTerrainGraphics;

    procedure Render(const tt: TTerrainType; sbt: UInt8; X, Y: Integer; Flags: UInt8);

    procedure RenderRoad(const rdt: TRoadType; const Dir: UInt8; X, Y: Integer;  Flags: UInt8);

    procedure RenderRiver(const rt: TRiverType; const Dir: UInt8; X, Y: Integer; Flags: UInt8 );

    function GetDefaultTerrain(const Level: Integer): TTerrainType;
    function GetRandomNormalSubtype(const tt: TTerrainType): UInt8;

  end;

implementation

uses
  strutils,RegExpr;

const
  FLIP_MODE_SAME_IMAGE = 'sameImage';
  FLIP_MODE_DIFF_IMAGES = 'diffImages';

  RULE_DIRT = 'D';
  RULE_SAND = 'S';
  RULE_TRANSITION = 'T';
  RULE_NATIVE = 'N';
  RULE_ANY = '?';


  FLIP_PATTERN_HORIZONTAL = 1;
  FLIP_PATTERN_VERTICAL = 2;
  FLIP_PATTERN_BOTH = 3;

type
  TTerrainViewInterval = record
    min, max: uint8;
  end;

const

  TERRAIN_DEF_FILES: array[TTerrainType] of string = (
    'DIRTTL',
    'SANDTL',
    'GRASTL',
    'SNOWTL',
    'SWMPTL',
    'ROUGTL',
    'SUBBTL',
    'LAVATL',
    'WATRTL',
    'ROCKTL'
    );

  RIVER_DEF_FILES: array[TRiverType.clearRiver..TRiverType.lavaRiver] of string =
  (
    'CLRRVR','ICYRVR','MUDRVR','LAVRVR'
  );

  ROAD_DEF_FILES: array[TRoadType.dirtRoad..TRoadType.cobblestoneRoad] of string =
  (
     'DIRTRD','GRAVRD','COBBRD'
  );


  TERRAIN_CONFIG_FILE = 'config/terrainViewPatterns.json';

procedure SetView(out V: TTerrainViewInterval; min,max: uint8);
begin
  v.max:=max;
  v.min:=min;
end;

{ TWeightedRule }

constructor TWeightedRule.Create;
begin
  points := 0;
  name := '';
end;

function TWeightedRule.IsStandartRule: boolean;
begin
  Result := (name = RULE_ANY)
    or (name = RULE_DIRT)
    or (name = RULE_NATIVE)
    or (name = RULE_SAND)
    or (name = RULE_TRANSITION);
end;

{ TTerrainPatternConfig }

procedure TTerrainPatternConfig.ConvertConfig;
begin
  FDirt.Loaded;
  FNormal.Loaded;
  FRock.Loaded;
  FSand.Loaded;
  FWater.Loaded;
end;

constructor TTerrainPatternConfig.Create;
begin
  FDirt := TPatterns.Create;
  FNormal := TPatterns.Create;
  FRock := TPatterns.Create;
  FSand := TPatterns.Create;
  FWater := TPatterns.Create;
end;

destructor TTerrainPatternConfig.Destroy;
begin
  FDirt.Free;
  FNormal.Free;
  FRock.Free;
  FSand.Free;
  FWater.Free;

  inherited Destroy;
end;

function TTerrainPatternConfig.GetConfigById(AGroup: TTerrainGroup; AId: string
  ): TPattern;
var
  g_config: TPatterns;
  t: TCollectionItem;
begin
  g_config := GetGroupConfig(AGroup);

  for t in g_config do
  begin
    if TPattern(t).ID = AId then Exit(TPattern(t));
  end;
  Result := nil;

  raise Exception.Create('Terrain config error. Pattern '+AId+' not found');
end;

function TTerrainPatternConfig.GetGroupConfig(AGroup: TTerrainGroup
  ): TPatterns;
begin
  case AGroup of
    TTerrainGroup.DIRT: Result := FDirt;
    TTerrainGroup.NORMAL: Result := FNormal;
    TTerrainGroup.ROCK: Result := FRock;
    TTerrainGroup.SAND: Result := FSand;
    TTerrainGroup.WATER: Result := FWater;
  end;
end;

function TTerrainPatternConfig.GetTerrainConfig(ATerrain: TTerrainType
  ): TPatterns;
const
  TERRAIN_GROUPS: array[TTerrainType] of TTerrainGroup =
    (TTerrainGroup.DIRT,
    TTerrainGroup.SAND,
    TTerrainGroup.NORMAL,
    TTerrainGroup.NORMAL,
    TTerrainGroup.NORMAL,
    TTerrainGroup.NORMAL,
    TTerrainGroup.NORMAL,
    TTerrainGroup.NORMAL,
    TTerrainGroup.WATER,
    TTerrainGroup.ROCK);
begin
  Result := GetGroupConfig(TERRAIN_GROUPS[ATerrain]);
end;

{ TPatterns }

constructor TPatterns.Create;
begin
  inherited Create(TPattern);
end;

procedure TPatterns.Loaded;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
  begin
    TPattern(Items[i]).Loaded;
  end;
end;

{ TPattern }

constructor TPattern.Create(ACollection: TCollection);
var
  i: Integer;
begin
  inherited Create(ACollection);
  FStrData := TStringList.Create;

  for i := Low(FData) to High(FData) do
  begin
    FData[i] := TRules.Create;
  end;

  FMappings := TMappings.Create;

  FlipMode := FLIP_MODE_SAME_IMAGE;
end;

destructor TPattern.Destroy;
var
  i: Integer;
begin
  FMappings.Free;
  for i := Low(FData) to High(FData) do
  begin
    FData[i].Free;
  end;
  FStrData.Free;
  inherited Destroy;
end;

function TPattern.GetData: TStrings;
begin
  Result := FStrData;
end;

procedure TPattern.Loaded;
var
  i: Integer;
  cell: String;

  tmp:TStringList;

  rule: TWeightedRule;
  m: TMapping;
  j: Integer;
  p: SizeInt;
begin
  if not FStrData.Count = 9 then raise Exception.Create('terrain config invalid');

  tmp := TStringList.Create;

  for I := Low(FData) to High(FData) do
  begin
    tmp.Clear;

    rule.Create();
    cell := FStrData[i];
    cell := ReplaceStr(cell,#20,'');

    SplitRegExpr(',',cell,tmp);

    for j := 0 to tmp.Count - 1 do
    begin
      p := Pos('-',tmp[j]);

      if p <> 0 then
      begin
        rule.name := Copy(tmp[j],1,p-1);

        rule.points := StrToInt(Copy(tmp[j],p,MaxInt));
      end
      else
      begin
        rule.name := tmp[j];
      end;

      FData[i].PushBack(rule);
    end;

    tmp.Clear;

    FMapping := ReplaceStr(FMapping,#20,'');
    SplitRegExpr(',',FMapping,tmp);

    for j := 0 to tmp.Count - 1 do
    begin
      p := Pos('-',tmp[j]);

      if p <> 0 then
      begin
        m.Lower := StrToInt(Copy(tmp[j],1,p-1));
        m.Upper := StrToInt(Copy(tmp[j],p,MaxInt));
      end
      else
      begin
        m.Lower := StrToIntDef(tmp[j],0);
        m.Upper := StrToIntDef(tmp[j],0);
      end;
      FMappings.PushBack(m);
    end

  end;

  tmp.Free;
end;

procedure TPattern.SetFlipMode(AValue: string);
begin
  if FFlipMode = AValue then Exit;
  FFlipMode := AValue;
end;

procedure TPattern.SetID(AValue: string);
begin
  if FID = AValue then Exit;
  FID := AValue;
end;

procedure TPattern.SetMapping(AValue: string);
begin
  if FMapping = AValue then Exit;
  FMapping := AValue;
end;

procedure TPattern.SetMinPoints(AValue: integer);
begin
  if FMinPoints = AValue then Exit;
  FMinPoints := AValue;
end;

{ TTerrainManager }

constructor TTerrainManager.Create(AOwner: TComponent);
var
  tt: TTerrainType;
begin
  inherited Create(AOwner);

  FPatternConfig := TTerrainPatternConfig.Create;
  FDestreamer := TVCMIJSONDestreamer.Create(Self);
end;

destructor TTerrainManager.Destroy;
var
  tt: TTerrainType;
begin
  FPatternConfig.Free;
  inherited Destroy;
end;

function TTerrainManager.GetDefaultTerrain(const Level: Integer): TTerrainType;
begin
  if Level <=0 then
  begin
    Result := TTerrainType.water;
  end
  else begin
    Result := TTerrainType.rock;
  end;
end;

function TTerrainManager.GetRandomNormalSubtype(const tt: TTerrainType): UInt8;
var
  vews: TTerrainViewInterval;
begin
  Result :=0;
  case tt of
    TTerrainType.dirt:SetView(vews,21,44);
    TTerrainType.sand:SetView(vews,0,23);
    TTerrainType.grass,
    TTerrainType.snow,
    TTerrainType.swamp,
    TTerrainType.rough,
    TTerrainType.sub,
    TTerrainType.lava:SetView(vews,49,63); //SetView(vews,49,72);
    TTerrainType.water:SetView(vews,20,32);
    TTerrainType.rock: SetView(vews,0,0);
  else
    raise Exception.Create('Unknown terrain: '+IntToStr(Ord(tt)));
  end;

  { TODO : Handle decorative tiles }
  Result := Random(vews.max-vews.min)+vews.min;

end;

procedure TTerrainManager.LoadConfig;
var
  stm: TMemoryStream;

begin
  stm := TMemoryStream.Create;
  try
    ResourceLoader.LoadToStream(stm,TResourceType.Json,TERRAIN_CONFIG_FILE);
    stm.Seek(0,soBeginning);
    FDestreamer.JSONStreamToObject(stm,FPatternConfig,'');
  finally
    stm.Free;
  end;
  FPatternConfig.ConvertConfig;
end;

procedure TTerrainManager.LoadTerrainGraphics;
var
  tt: TTerrainType;
  rt: TRiverType;
  rdt: TRoadType;
begin
  for tt := Low(TTerrainType) to High(TTerrainType) do
  begin
    FTerrainDefs[tt] := GraphicsManager.GetGraphics(TERRAIN_DEF_FILES[tt])
  end;

  for rt in [TRiverType.clearRiver..TRiverType.lavaRiver] do
  begin
    FRiverDefs[rt] := GraphicsManager.GetGraphics(RIVER_DEF_FILES[rt]);
  end;

  for rdt in [TRoadType.dirtRoad..TRoadType.cobblestoneRoad] do
  begin
    FRoadDefs[rdt] := GraphicsManager.GetGraphics(ROAD_DEF_FILES[rdt]);
  end;

end;

procedure TTerrainManager.Render(const tt: TTerrainType; sbt: UInt8; X,
  Y: Integer; Flags: UInt8);
begin
  FTerrainDefs[tt].RenderF(sbt, x*TILE_SIZE, y*TILE_SIZE,Flags);
end;

procedure TTerrainManager.RenderRiver(const rt: TRiverType; const Dir: UInt8;
  X, Y: Integer; Flags: UInt8);
begin
  if rt <> TRiverType.noRiver then
  begin
    FRiverDefs[rt].RenderF(dir,x*TILE_SIZE, y*TILE_SIZE, Flags shr 2);
  end;
end;

procedure TTerrainManager.RenderRoad(const rdt: TRoadType; const Dir: UInt8; X,
  Y: Integer; Flags: UInt8);
begin
  if rdt <> TRoadType.noRoad then
  begin
    FRoadDefs[rdt].RenderF(dir,x*TILE_SIZE, y*TILE_SIZE, Flags shr 4);
  end;
end;


end.






