{ This file is a part of Map editor for VCMI project

  Copyright (C) 2013-2017 Alexander Shishkin alexvins@users.sourceforge.net

  This source is free software; you can redistribute it and/or modify it under the terms of the GNU General Public
  License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later
  version.

  This code is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
  warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web at
  <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing to the Free Software Foundation, Inc., 59
  Temple Place - Suite 330, Boston, MA 02111-1307, USA.
}

unit editor_classes;

{$I compilersetup.inc}
{$INTERFACES CORBA}

interface

uses
  Classes, SysUtils, fgl, editor_types, fpjson, contnrs;

type

  { IProgressCallback }

  IProgressCallback = interface
      function GetMax: Integer;
      procedure SetMax(AValue: Integer);
    property Max: Integer read GetMax write SetMax;
    procedure Advance(ADelta: integer);
    procedure NextStage(const AStageLabel:string);
    procedure AddError(const ADescription: string);
  end;


  { IEmbeddedValue
    May contain only one published property serialized directly (w/o object node) }

  IEmbeddedValue = interface ['IEmbbeddedValue']
  end;

  { INamedCollection
    Stored as object in JSON
    uses TNamedCollectionItem.Identifier as a name of field }

  INamedCollection = interface ['INamedCollection']
  end;

  { IArrayCollection
    Stored as array in JSON  }

  IArrayCollection = interface ['IArrayCollection']
  end;

  { IEmbeddedCollection }

  IEmbeddedCollection = interface ['{F3D6E58A-CA30-4030-B98B-5E75A5AB796A}']
    function GetCollection: TCollection;
  end;

  { ISerializeNotify }

  ISerializeNotify = interface ['ISerializeNotify']
     procedure BeforeSerialize(Sender:TObject);
     procedure AfterSerialize(Sender:TObject; AData: TJSONData);

     procedure BeforeDeSerialize(Sender:TObject; AData: TJSONData);
     procedure AfterDeSerialize(Sender:TObject; AData: TJSONData);
  end;

  IReferenceNotify = interface
     procedure NotifyReferenced(AOldIdentifier, ANewIdentifier: AnsiString);
  end;

  { TNamedCollectionItem }

  TNamedCollectionItem = class(TCollectionItem)
  private
    FIdentifier: AnsiString;
    FMeta: AnsiString;
    procedure SetMeta(AValue: AnsiString);
  protected
    procedure SetIdentifier(AValue: AnsiString); virtual;

    procedure AssignTo(Dest: TPersistent); override;
    function GetDisplayName: string; override;
    procedure SetDisplayName(const Value: string); override;

    procedure PushResolveRequest(AMetaClass: TMetaclass; const AProperty: ShortString);
  public
    property Identifier: AnsiString read FIdentifier write SetIdentifier;
    property Meta: AnsiString read FMeta write SetMeta;

    class function UseMeta: boolean; virtual;
  end;

  TNamedCollectionItemClass = class of TNamedCollectionItem;

  { THashedCollection }

  THashedCollection = class(TCollection)
  private
    FHash: TFPHashObjectList;

  protected
    procedure ItemIdentifierChanged(Item: TCollectionItem; AOldName: String; ANewName: String); virtual;
    procedure ItemAdded(Item: TCollectionItem); virtual;
    procedure ItemRemoved(Item: TCollectionItem); virtual;
    procedure Notify(Item: TCollectionItem; Action: TCollectionNotification);
      override;

    procedure PushResolveRequest(AObject: TNamedCollectionItem; AMetaClass: TMetaclass; const AProperty: ShortString); virtual;
  public
    constructor Create(AItemClass: TNamedCollectionItemClass);
    destructor Destroy; override;

    function IndexOfName(const AName: String): Integer;

    procedure Remove(AIdentifier: String);

    function FindItem(const AName: String): TNamedCollectionItem;

    procedure SortByDisplayName;
  end;


  { TGArrayCollection }

  generic TGArrayCollection <TItem : TCollectionItem> = class (TCollection, IArrayCollection)
  public
    type
      TItemType = TItem;
  private
    function GetItems(const Idx: Integer): TItemType;
    procedure SetItems(const Idx: Integer; AValue: TItemType);
  public
    constructor Create;
    function Add: TItemType;

    property Items[const Idx: Integer]: TItemType read GetItems write SetItems; default;
  end;

  { TGNamedCollection }

  generic TGNamedCollection <TItem : TNamedCollectionItem> = class (THashedCollection, INamedCollection)
  public
  type
      TItemType = TItem;
  private
    function GetItems(const Idx: Integer): TItemType;
    procedure SetItems(const Idx: Integer; AValue: TItemType);
  public
    constructor Create;

    function Add: TItemType;
    property Items[const Idx: Integer]: TItemType read GetItems write SetItems; default;

    function FindItem(const AName: String): TItemType;
    function EnsureItem(const AName: String): TItemType;
  end;

  { TObjectMap }

  generic TObjectMap <TKey; TValue : TObject> = class (specialize TFPGMap<TKey, TValue>)
  protected
    procedure Deref(Item: Pointer); override;
  end;

  { TPrimarySkills }

  TPrimarySkills = class(TPersistent)
  protected
    function GetAttack: Integer; virtual; abstract;
    function GetDefence: Integer; virtual; abstract;
    function GetKnowledge: Integer; virtual; abstract;
    function GetSpellpower: Integer; virtual; abstract;
    procedure SetAttack(AValue: Integer); virtual; abstract;
    procedure SetDefence(AValue: Integer); virtual; abstract;
    procedure SetKnowledge(AValue: Integer); virtual; abstract;
    procedure SetSpellpower(AValue: Integer); virtual; abstract;

    procedure AssignTo(Dest: TPersistent); override;
  public
    constructor Create;
    function IsDefault: Boolean; virtual; abstract;
    procedure Clear; virtual; abstract;
    procedure SetZero;

    property Attack: Integer read GetAttack write SetAttack ;
    property Defence: Integer read GetDefence write SetDefence;
    property Spellpower: Integer read GetSpellpower write SetSpellpower;
    property Knowledge: Integer read GetKnowledge write SetKnowledge;
  end;

  { THeroPrimarySkills }

  THeroPrimarySkills = class(TPrimarySkills)
  private
    FAttack: Integer;
    FDefence: Integer;
    FKnowledge: Integer;
    FSpellpower: Integer;
  protected
    function GetAttack: Integer; override;
    function GetDefence: Integer; override;
    function GetKnowledge: Integer; override;
    function GetSpellpower: Integer; override;
    procedure SetAttack(AValue: Integer); override;
    procedure SetDefence(AValue: Integer); override;
    procedure SetKnowledge(AValue: Integer); override;
    procedure SetSpellpower(AValue: Integer); override;
  public
    constructor Create;
    function IsDefault: Boolean; override;
    procedure Clear; override;
  published
    property Attack default -1;
    property Defence default -1;
    property Spellpower default -1;
    property Knowledge default -1;
  end;

  { THeroSecondarySkill }

  THeroSecondarySkill = class(TNamedCollectionItem, IEmbeddedValue)
  private
    FLevel: TSkillLevel;
  protected
    procedure AssignTo(Dest: TPersistent); override;
  published
    property Level: TSkillLevel read FLevel write FLevel nodefault;
  end;

  { THeroSecondarySkills }

  THeroSecondarySkills = class(specialize TGNamedCollection<THeroSecondarySkill>)
  end;

  IHeroInfo = interface
    function GetHeroIdentifier: AnsiString;

    function GetBiography: TLocalizedString;
    function GetExperience: UInt64;
    function GetName: TLocalizedString;
    function GetPortrait: Int32;
    function GetPrimarySkills: THeroPrimarySkills;
    function GetSex: THeroSex;
    function GetSecondarySkills: THeroSecondarySkills;
  end;

  IEditableHeroInfo = interface(IHeroInfo)
    procedure SetBiography(const AValue: TLocalizedString);
    procedure SetExperience(const AValue: UInt64);
    procedure SetName(const AValue: TLocalizedString);
    procedure SetSex(const AValue: THeroSex);

    procedure SetPortrait(const AValue: Int32);
  end;

  { TBaseIdentifierList }

  TBaseIdentifierList = class abstract (TStringList)
  private
    FOwner: IReferenceNotify;
    procedure DoOwnerNotify(AOldIdentifier, ANewIdentifier: AnsiString);
  protected
    procedure InsertItem(Index: Integer; const S: string; O: TObject); override;
    procedure Put(Index: Integer; const S: string); override;
  public
    constructor Create(AOwner: IReferenceNotify); virtual;
    procedure Delete(Index: Integer); override;
    procedure Clear; override;
  end;

  { TIdentifierList }

  TIdentifierList = class(TBaseIdentifierList)
  public
    constructor Create(AOwner: IReferenceNotify); override;
  end;

  { TIdentifierSet }

  TIdentifierSet = class(TBaseIdentifierList)
  public
    constructor Create(AOwner: IReferenceNotify); override;
  end;

implementation

{ THeroPrimarySkills }

function THeroPrimarySkills.GetAttack: Integer;
begin
  Result := FAttack;
end;

function THeroPrimarySkills.GetDefence: Integer;
begin
  Result := FDefence;
end;

function THeroPrimarySkills.GetKnowledge: Integer;
begin
  Result := FKnowledge;
end;

function THeroPrimarySkills.GetSpellpower: Integer;
begin
  Result := FSpellpower;
end;

procedure THeroPrimarySkills.SetAttack(AValue: Integer);
begin
  FAttack := AValue;
end;

procedure THeroPrimarySkills.SetDefence(AValue: Integer);
begin
  FDefence := AValue;
end;

procedure THeroPrimarySkills.SetKnowledge(AValue: Integer);
begin
  FKnowledge := AValue;
end;

procedure THeroPrimarySkills.SetSpellpower(AValue: Integer);
begin
  FSpellpower := AValue;
end;

constructor THeroPrimarySkills.Create;
begin
  Inherited;
  Clear;
end;

function THeroPrimarySkills.IsDefault: Boolean;
begin
  Result := (Attack = -1) and (Defence = -1) and (Spellpower = -1) and (Knowledge = -1);
end;

procedure THeroPrimarySkills.Clear;
begin
  Attack :=-1;
  Defence:=-1;
  Spellpower:=-1;
  Knowledge:=-1;
end;

{ TIdentifierSet }

constructor TIdentifierSet.Create(AOwner: IReferenceNotify);
begin
  inherited Create(AOwner);
  Sorted:=true;
  Duplicates:=dupIgnore;
end;

{ TIdentifierList }

constructor TIdentifierList.Create(AOwner: IReferenceNotify);
begin
  inherited Create(AOwner);
  Sorted:=false;
  Duplicates:=dupAccept;
end;

{ TBaseIdentifierList }

procedure TBaseIdentifierList.DoOwnerNotify(AOldIdentifier, ANewIdentifier: AnsiString);
begin
  if Assigned(FOwner) then
  begin
    FOwner.NotifyReferenced(AOldIdentifier, ANewIdentifier);
  end;
end;

procedure TBaseIdentifierList.InsertItem(Index: Integer; const S: string; O: TObject
  );
begin
  DoOwnerNotify('', s);
  inherited InsertItem(Index, S, O);
end;

procedure TBaseIdentifierList.Put(Index: Integer; const S: string);
begin
  DoOwnerNotify(Strings[Index], s);
  inherited Put(Index, S);
end;

constructor TBaseIdentifierList.Create(AOwner: IReferenceNotify);
begin
  inherited Create;
  FOwner :=  AOwner;
end;

procedure TBaseIdentifierList.Delete(Index: Integer);
begin
  DoOwnerNotify(Strings[Index], '');
  inherited Delete(Index);
end;

procedure TBaseIdentifierList.Clear;
var
  s: String;
begin
  for s in self do
    DoOwnerNotify(s, '');

  inherited Clear;
end;

{ TGNamedCollection }

function TGNamedCollection.GetItems(const Idx: Integer): TItemType;
begin
  Result := TItemType( inherited Items[Idx]);
end;

procedure TGNamedCollection.SetItems(const Idx: Integer; AValue: TItemType);
begin
  inherited Items[Idx] := AValue;
end;

constructor TGNamedCollection.Create;
begin
  inherited Create(TItemType);
end;

function TGNamedCollection.Add: TItemType;
begin
   Result := TItemType(inherited Add);
end;

function TGNamedCollection.FindItem(const AName: String): TItemType;
begin
  if AName = '' then
    Result := nil
  else
    Result := TItemType(inherited FindItem(AName));
end;

function TGNamedCollection.EnsureItem(const AName: String): TItemType;
begin
  Result := FindItem(AName);
  if Result = nil then
  begin
    Result := Add;
    Result.Identifier := AName;
  end;
end;

{ THashedCollection }

procedure THashedCollection.ItemAdded(Item: TCollectionItem);
begin
  ItemIdentifierChanged( Item, '', TNamedCollectionItem(Item).Identifier);
end;

procedure THashedCollection.ItemRemoved(Item: TCollectionItem);
begin
  FHash.Remove(Item);
end;

procedure THashedCollection.ItemIdentifierChanged(Item: TCollectionItem;
  AOldName: String; ANewName: String);
begin
  if(AOldName <> '') and (ANewName <> '') then
  begin
    FHash.Rename(AOldName,ANewName);
  end
  else if (AOldName <> '') then
  begin
    FHash.Remove(Item);
  end
  else if (ANewName <> '') then
  begin
    FHash.Add(ANewName,Item);
  end;
end;

procedure THashedCollection.Notify(Item: TCollectionItem;
  Action: TCollectionNotification);
begin
  inherited Notify(Item, Action);

  Case Action of
    cnAdded                 : ItemAdded(Item);
    cnExtracting, cnDeleting: ItemRemoved(Item);
  end;
end;

procedure THashedCollection.PushResolveRequest(AObject: TNamedCollectionItem; AMetaClass: TMetaclass;
  const AProperty: ShortString);
begin
  raise Exception.Create('Unhandled PushResolveRequest');
end;

constructor THashedCollection.Create(AItemClass: TNamedCollectionItemClass);
begin
  inherited Create(AItemClass);
  FHash := TFPHashObjectList.Create(False);
end;

destructor THashedCollection.Destroy;
begin
  inherited Destroy;
  FHash.Free;//has is used by inherited destructor
end;

function THashedCollection.IndexOfName(const AName: String): Integer;
var
  hash_idx: Integer;

  item : TCollectionItem;
begin
  hash_idx := FHash.FindIndexOf(AName);

  if hash_idx = -1 then
  begin
    Result := -1;
  end
  else
  begin
    item := TCollectionItem(FHash.Items[hash_idx]);

    Result := item.Index;

    Assert(Items[Result] = item, 'THashedCollection desynch');
  end;
end;

procedure THashedCollection.Remove(AIdentifier: String);
var
  idx: Integer;
begin
  idx := IndexOfName(AIdentifier);
  if idx>=0 then
    Delete(idx);
end;

function THashedCollection.FindItem(const AName: String): TNamedCollectionItem;
var
  idx: Integer;
begin
  idx := IndexOfName(AName);

  if idx = -1 then
    Result := nil
  else
    Result := TNamedCollectionItem(Items[idx]);
end;

function CompareByDisplayName(Item1, Item2: TCollectionItem): Integer;
begin
  Result := CompareStr(Item1.DisplayName,Item2.DisplayName);
end;

procedure THashedCollection.SortByDisplayName;
begin
  Sort(@CompareByDisplayName);
end;

{ TNamedCollectionItem }

procedure TNamedCollectionItem.SetIdentifier(AValue: AnsiString);
begin
  Changed(false);
  if Assigned(Collection) then
    (Collection as THashedCollection).ItemIdentifierChanged(Self, FIdentifier, AValue);
  FIdentifier:=AValue;
end;

procedure TNamedCollectionItem.SetMeta(AValue: AnsiString);
begin
  FMeta:=AValue;
end;

procedure TNamedCollectionItem.AssignTo(Dest: TPersistent);
var
  dest_typed:  TNamedCollectionItem;
begin
  if Dest is TNamedCollectionItem then
  begin
    dest_typed := TNamedCollectionItem(Dest);
    dest_typed.Identifier := Identifier;
    dest_typed.DisplayName:=DisplayName;
  end
  else
  begin
     inherited AssignTo(Dest);
  end;
end;

function TNamedCollectionItem.GetDisplayName: string;
begin
  Result := FIdentifier;
end;

procedure TNamedCollectionItem.SetDisplayName(const Value: string);
begin
//do nothing here
end;

procedure TNamedCollectionItem.PushResolveRequest(AMetaClass: TMetaclass; const AProperty: ShortString);
begin
  (Collection as THashedCollection).PushResolveRequest(self, AMetaClass, AProperty);
end;

class function TNamedCollectionItem.UseMeta: boolean;
begin
  Result := false;
end;

{ TGCollection }

function TGArrayCollection.Add: TItemType;
begin
  Result := TItemType(inherited Add);
end;

constructor TGArrayCollection.Create;
begin
  inherited Create(TItem);
end;

function TGArrayCollection.GetItems(const Idx: Integer): TItemType;
begin
  Result := TItem( inherited Items[Idx]);
end;

procedure TGArrayCollection.SetItems(const Idx: Integer; AValue: TItemType);
begin
  inherited Items[Idx] := AValue;
end;

{ TObjectMap }

procedure TObjectMap.Deref(Item: Pointer);
begin
  Finalize(TKey(Item^));

//  TData(Pointer(PByte(Item)+KeySize)^).Free;
end;

{ TPrimarySkills }

procedure TPrimarySkills.AssignTo(Dest: TPersistent);
begin
  if Dest is TPrimarySkills then
  begin
    TPrimarySkills(Dest).Attack:=Attack;
    TPrimarySkills(Dest).Defence:=Defence;
    TPrimarySkills(Dest).Spellpower:=Spellpower;
    TPrimarySkills(Dest).Knowledge:=Knowledge;
  end
  else begin
    inherited AssignTo(Dest);
  end;
end;

constructor TPrimarySkills.Create;
begin

end;

procedure TPrimarySkills.SetZero;
begin
  Attack :=0;
  Defence:=0;
  Spellpower:=0;
  Knowledge:=0;
end;

{ THeroSecondarySkill }

procedure THeroSecondarySkill.AssignTo(Dest: TPersistent);
begin
  if Dest is THeroSecondarySkill then
  begin
    THeroSecondarySkill(Dest).Level:=Level;
    THeroSecondarySkill(Dest).Identifier:=Identifier;
  end
  else begin
    inherited AssignTo(Dest);
  end;
end;


end.

