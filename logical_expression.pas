{ This file is a part of Map editor for VCMI project

  Copyright (C) 2015 Alexander Shishkin alexvins@users.sourceforge,net

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
unit logical_expression;

{$I compilersetup.inc}

interface

uses
  Classes, SysUtils, editor_classes;

type
  TLogicalExpression = class;

  { TLogicalExpressionItem }

  TLogicalExpressionItem = class (TCollectionItem,  IEmbeddedValue)
  private
    FAsString: AnsiString;
    FCollection: TLogicalExpression;

    function IsCollection: Boolean;
    function IsObject: Boolean;
    function IsString: Boolean;
    procedure SetAsString(AValue: AnsiString);
  protected
    function GetAsObject: TObject; virtual; abstract;
  published
    property AsString: AnsiString read FAsString write SetAsString stored IsString;
    property AsCollection:TLogicalExpression read FCollection stored IsCollection;
    property AsObject: TObject read GetAsObject stored IsObject;
  end;

  TLogicalExpression = class (TCollection, IArrayCollection)
  public

  end;

implementation

{ TLogicalExpressionItem }

procedure TLogicalExpressionItem.SetAsString(AValue: AnsiString);
begin
  if FAsString=AValue then Exit;
  FAsString:=AValue;
end;

function TLogicalExpressionItem.IsString: Boolean;
begin
  Result := AsString <> '';
end;

function TLogicalExpressionItem.IsCollection: Boolean;
begin
  Result := FCollection.Count > 0;
end;

function TLogicalExpressionItem.IsObject: Boolean;
begin
  Result := not IsString and not IsCollection;
end;

end.

