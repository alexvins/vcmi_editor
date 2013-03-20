{ This file is a part of Map editor for VCMI project

  Copyright (C) 2013 Alexander Shishkin alexvins@users.sourceforge,net

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

unit editor_gl;

{$I compilersetup.inc}

interface

uses
  Classes, SysUtils, math, GL, GLext, LazLoggerBase;

type
  TRBGAColor = packed record   //todo: optimise
    r,g,b,a : UInt8;
  end;

const

  FRAGMENT_PALETTE_SHADER =
  '#version 120'#13#10 +
  'uniform vec4 maskColor = vec4(1.0, 1.0, 0.0, 0.0);'+
  'uniform sampler2DRect bitmap;'+
  'uniform sampler1D palette;'+
  'uniform vec4 flagColor;'+
  'uniform vec4 eps = vec4(0.009, 0.009, 0.009, 0.009);'+

  'void main(){'+
    'float idx_f = texture2DRect(bitmap,gl_TexCoord[0].xy).r;'+
    'vec4 texel = texture1D(palette, idx_f);'+
    'if(all(greaterThanEqual(texel,maskColor-eps)) && all(lessThanEqual(texel,maskColor+eps)))'+
    '  texel = flagColor;'+
    'gl_FragColor = texel;'+
  '}';

   FRAGMENT_FLAG_SHADER =

   '#version 120'#13#10 +
   'uniform vec4 maskColor = vec4(1.0, 1.0, 0.0, 0.0);'+
   'uniform sampler2DRect bitmap;'+
   'uniform vec4 flagColor;'+

   'void main(){'+
     'vec4 eps = vec4(0.009, 0.009, 0.009, 0.009);'+
     'vec4 texel = texture2DRect(bitmap,gl_TexCoord[0].xy);'+
     'if(all(greaterThanEqual(texel,maskColor-eps)) && all(lessThanEqual(texel,maskColor+eps)))'+
     '  texel = flagColor;'+
     'gl_FragColor = texel;'+
  '}';

type

  TGLSprite = record
    TextureID: GLuint;
    PaletteID: Gluint;
    Width: Int32;
    Height: Int32;

    TopMagin: int32;
    LeftMargin: int32;

    X: Int32;
    Y: Int32;
  end;

  { TShaderContext }

  TShaderContext = class
  private
    FCurrentProgram: GLuint;
  private
    PaletteProgram: GLuint;
    PalettePaletteUniform: GLuint;
    PaletteBitmapUniform: GLUint;
    PaletteFlagColorUniform: GLuint;

    FlagProgram: GLuint;
    FlagFlagColorUniform: GLuint;
    FlagBitmapUniform: GLUint;
  public
    destructor Destroy; override;
    procedure Init;

    procedure UseNoShader();
    procedure UsePaletteShader();
    //procedure UseFlagShader();

    procedure SetFlagColor(FlagColor: TRBGAColor);
  end;

procedure BindPalette(ATextureId: GLuint; ARawImage: Pointer);

procedure BindUncompressedPaletted(ATextureId: GLuint; w,h: Int32; ARawImage: Pointer);

procedure BindUncompressedRGBA(ATextureId: GLuint; w,h: Int32; var ARawImage);
procedure BindCompressedRGBA(ATextureId: GLuint; w,h: Int32; var ARawImage);
procedure Unbind(var ATextureId: GLuint); inline;

procedure RenderSprite(const ASprite: TGLSprite; dim: integer = -1; mir: UInt8 = 0);
procedure RenderRect(x,y: Integer; dimx,dimy:integer);

procedure CheckGLErrors(Stage: string);

function MakeShaderProgram(const AShaderSource: AnsiString):GLuint;

var
  ShaderContext: TShaderContext;


implementation


procedure BindRGBA(ATextureId: GLuint; w, h: Int32; ARawImage: Pointer; AInternalFormat: GLEnum); inline;
begin
  glEnable(GL_TEXTURE_RECTANGLE);
  glBindTexture(GL_TEXTURE_RECTANGLE, ATextureId);

  glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

  glTexImage2D(GL_TEXTURE_RECTANGLE, 0,AInternalFormat,w,h,0,GL_RGBA, GL_UNSIGNED_BYTE, ARawImage);
  glDisable(GL_TEXTURE_RECTANGLE);
end;

procedure BindPalette(ATextureId: GLuint; ARawImage: Pointer);
begin
  glEnable(GL_TEXTURE_1D);
  glBindTexture(GL_TEXTURE_1D, ATextureId);

  glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

  glTexImage1D(GL_TEXTURE_1D, 0,GL_RGBA,256,0,GL_RGBA, GL_UNSIGNED_BYTE, ARawImage);
  glDisable(GL_TEXTURE_1D);

  CheckGLErrors('Bind palette');
end;


procedure BindUncompressedPaletted(ATextureId: GLuint; w, h: Int32;
  ARawImage: Pointer);
begin
  glEnable(GL_TEXTURE_RECTANGLE);
  glBindTexture(GL_TEXTURE_RECTANGLE, ATextureId);

  glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

  glTexImage2D(GL_TEXTURE_RECTANGLE, 0,GL_LUMINANCE,w,h,0,GL_RED, GL_UNSIGNED_BYTE, ARawImage);
  glDisable(GL_TEXTURE_RECTANGLE);

  CheckGLErrors('Bind paletted');
end;

procedure BindUncompressedRGBA(ATextureId: GLuint; w, h: Int32; var ARawImage);
begin
  BindRGBA(ATextureId,w, h,@ARawImage,GL_RGBA);
end;

procedure BindCompressedRGBA(ATextureId: GLuint; w, h: Int32; var ARawImage);
begin
  BindRGBA(ATextureId,w, h,@ARawImage,GL_COMPRESSED_RGBA);
end;

procedure Unbind(var ATextureId: GLuint);
begin
  glDeleteTextures(1,@ATextureId);
  ATextureId := 0;
end;

procedure RenderSprite(const ASprite: TGLSprite; dim: integer; mir: UInt8);
var
  factor: Double;
  cur_dim: integer;
  H: Int32;
  W: Int32;
begin

  if dim <=0 then //render real size w|o scale
  begin
    H := ASprite.Height;
    W := ASprite.Width;
  end
  else
  begin
    cur_dim := Max(ASprite.Width,ASprite.Height);
    factor := Min(dim / cur_dim, 1); //no zoom

    h := round(Double(ASprite.Height) * factor);
    w := round(Double(ASprite.Width) * factor);
  end;

  //CheckGLErrors('render sprite0 mir='+IntToStr(mir)+ ' xy='+IntToStr(ASprite.X)+' '+ IntToStr(ASprite.Y));

  glEnable(GL_TEXTURE_RECTANGLE);
  glEnable(GL_TEXTURE_1D);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_RECTANGLE,ASprite.TextureID);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_1D,ASprite.PaletteID);


    glBegin(GL_POLYGON);

      case mir of
        0:begin
          glMultiTexCoord2i(GL_TEXTURE0, 0,0);
          glVertex2i(ASprite.X,  ASprite.Y);

          glMultiTexCoord2i(GL_TEXTURE0, ASprite.Width, 0);
          glVertex2i(ASprite.X+W,ASprite.Y);

          glMultiTexCoord2i(GL_TEXTURE0, ASprite.Width, ASprite.Height);
          glVertex2i(ASprite.X+W,ASprite.Y+H);

          glMultiTexCoord2i(GL_TEXTURE0, 0,ASprite.Height);
          glVertex2i(ASprite.X,  ASprite.Y+H);
        end;
        1: begin
          glMultiTexCoord2i(GL_TEXTURE0, ASprite.Width,0);
          glVertex2i(ASprite.X,  ASprite.Y);

          glMultiTexCoord2i(GL_TEXTURE0, 0, 0);
          glVertex2i(ASprite.X+W,ASprite.Y);

          glMultiTexCoord2i(GL_TEXTURE0, 0, ASprite.Height);
          glVertex2i(ASprite.X+W,ASprite.Y+H);

          glMultiTexCoord2i(GL_TEXTURE0, ASprite.Width,ASprite.Height);
          glVertex2i(ASprite.X,  ASprite.Y+H);
          end;
        2: begin
          glMultiTexCoord2i(GL_TEXTURE0, 0,ASprite.Height);
          glVertex2i(ASprite.X,  ASprite.Y);

          glMultiTexCoord2i(GL_TEXTURE0, ASprite.Width, ASprite.Height);
          glVertex2i(ASprite.X+W,ASprite.Y);

          glMultiTexCoord2i(GL_TEXTURE0, ASprite.Width, 0);
          glVertex2i(ASprite.X+W,ASprite.Y+H);

          glMultiTexCoord2i(GL_TEXTURE0, 0,0);
          glVertex2i(ASprite.X,  ASprite.Y+H);
          end;
        3:begin
          glMultiTexCoord2i(GL_TEXTURE0, ASprite.Width,ASprite.Height);
          glVertex2i(ASprite.X,  ASprite.Y);

          glMultiTexCoord2i(GL_TEXTURE0, 0, ASprite.Height);
          glVertex2i(ASprite.X+W,ASprite.Y);

          glMultiTexCoord2i(GL_TEXTURE0, 0, 0);
          glVertex2i(ASprite.X+W,ASprite.Y+H);

          glMultiTexCoord2i(GL_TEXTURE0, ASprite.Width,0);
          glVertex2i(ASprite.X,  ASprite.Y+H);
          end;
      end;



    glEnd();

  glDisable(GL_TEXTURE_1D);
  glDisable(GL_TEXTURE_RECTANGLE);

  CheckGLErrors('render sprite mir='+IntToStr(mir)+ ' xy='+IntToStr(ASprite.X)+' '+ IntToStr(ASprite.Y));
end;

procedure RenderRect(x, y: Integer; dimx, dimy: integer);
begin
  glLineWidth(1);
  glPushAttrib(GL_CURRENT_BIT);
  glBegin(GL_LINE_LOOP);

    glColor4ub(200, 200, 200, 255);



    glVertex2i(x, y);
    glVertex2i(x + dimx, y);

    glVertex2i(x + dimx, y + dimy);
    glVertex2i(x, y + dimy);


    glEnd();
  glPopAttrib();
end;

procedure CheckGLErrors(Stage: string);
var
  err: GLenum;
begin

  repeat
    err := glGetError();

    if err<>GL_NO_ERROR then
    begin
      DebugLogger.DebugLn(Stage +': Gl error '+IntToHex(err,8));
    end;

  until err = GL_NO_ERROR ;


end;

function MakeShaderProgram(const AShaderSource: AnsiString): GLuint;
var
  shader_object, program_object: GLuint;
  status: GLint;
  info_log_len: GLint;

  info_log: string;
begin
  Result := 0;
  shader_object := glCreateShader(GL_FRAGMENT_SHADER);

  if shader_object = 0 then
  begin
    CheckGLErrors('MakeShaderProgram');
    Exit;
  end;

  glShaderSource(shader_object,1,@(AShaderSource),nil);
  glCompileShader(shader_object);
  status := GL_FALSE;
  glGetShaderiv(shader_object,GL_COMPILE_STATUS,@status);

  if status <> GL_TRUE then
  begin
    glGetShaderiv(shader_object,GL_INFO_LOG_LENGTH, @info_log_len);
    SetLength(info_log,info_log_len);
    glGetShaderInfoLog(shader_object,info_log_len,@info_log_len,@info_log[1]);

    DebugLn('Shader compile log:');
    DebugLn(info_log);
  end;


  if status = GL_TRUE then
  begin
    program_object := glCreateProgram();
    glAttachShader(program_object, shader_object);

    glLinkProgram(program_object);
    status := GL_FALSE;
    glGetProgramiv(program_object, GL_LINK_STATUS, @status);

    //todo: print log

    if (status = GL_TRUE) then
      Result := program_object;
  end;

  glDeleteShader(shader_object); //always mark shader for deletion
end;

{ TShaderContext }

destructor TShaderContext.Destroy;
begin
  UseNoShader;
  glDeleteProgram(PaletteProgram);
  //TODO: delete shader?
  inherited Destroy;
end;

procedure TShaderContext.Init;
begin
  PaletteProgram := MakeShaderProgram(FRAGMENT_PALETTE_SHADER);
  if PaletteProgram = 0 then
    raise Exception.Create('Error compiling palette shader');

  PaletteBitmapUniform := glGetUniformLocation(PaletteProgram, PChar('bitmap'));
  PalettePaletteUniform := glGetUniformLocation(PaletteProgram, PChar('palette'));
  PaletteFlagColorUniform := glGetUniformLocation(PaletteProgram, PChar('flagColor'));

  FlagProgram := MakeShaderProgram(FRAGMENT_FLAG_SHADER);
  if FlagProgram = 0 then
    raise Exception.Create('Error compiling flag shader');

  FlagFlagColorUniform := glGetUniformLocation(FlagProgram, PChar('flagColor'));
  FlagBitmapUniform := glGetUniformLocation(FlagProgram, PChar('bitmap'));
end;

procedure TShaderContext.SetFlagColor(FlagColor: TRBGAColor);

begin
  if FCurrentProgram = PaletteProgram then
  begin
    glUniform4f(PaletteFlagColorUniform, FlagColor.r/255, FlagColor.g/255, FlagColor.b/255, FlagColor.a/255);
  end
  else if FCurrentProgram = FlagProgram then begin
    glUniform4f(FlagFlagColorUniform, FlagColor.r/255, FlagColor.g/255, FlagColor.b/255, FlagColor.a/255);
  end;

end;

//procedure TShaderContext.UseFlagShader;
//begin
//  FCurrentProgram := FlagProgram;
//  glUseProgram(FCurrentProgram);
//  glUniform1i(FlagBitmapUniform, 0); //texture unit0
//end;

procedure TShaderContext.UseNoShader;
begin
  FCurrentProgram := 0;
  glUseProgram(FCurrentProgram);
end;

procedure TShaderContext.UsePaletteShader;
begin
  FCurrentProgram := PaletteProgram;
  glUseProgram(FCurrentProgram);
  glUniform1i(PaletteBitmapUniform, 0); //texture unit0
  glUniform1i(PalettePaletteUniform, 1);//texture unit1

end;


end.

