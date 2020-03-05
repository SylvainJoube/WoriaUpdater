unit U_PngUtils;

interface
uses windows, math, sysUtils, graphics, dialogs, pngimage, pngextra, pnglang, zlibpas;

type TPngUtils = class // juste pour regrouper les fonctions
  public
    procedure DrawPngWithAlpha_pos(source, dest: TPNGObject; xOrig, yOrig : integer);
    procedure ClearAlpha(png : TPngObject);
    procedure ResizeAndClearAlpha(png : TPngObject; newWidth, newHeight : cardinal);

end;

implementation

procedure DrawPngWithAlpha(Src, Dest: TPNGObject; const R: TRect);
var X, Y, xInSrc, yInSrc : Integer;
    pDestAlpha, pSrcAlpha : PByte;
begin
  Src.Draw(Dest.Canvas, R);
  //if R.Top>=R.Bottom then exit;
  //if R.Left>=R.Right then exit;
  // I have no idea why standard implementation of TPNGObject.Draw doesn't apply transparency.
  for Y := R.Top to R.Bottom - 1 do
  for X := R.Left to R.Right - 1 do begin
    xInSrc:=X - R.Left;
    yInSrc:=Y - R.Top;
    pDestAlpha:=@Dest.AlphaScanline[Y]^[X];//@Dest.AlphaScanline[Y]^[X]
    pSrcAlpha:=@Src.AlphaScanline[yInSrc]^[xInSrc]; // y en premier
    pDestAlpha^ := Min(255, pSrcAlpha^ + pDestAlpha^); // addition des deux alphas (et non(dépassement de l'alpha max de 255
  end;
end;


type TMergeColor_components = array [0..2] of byte;
procedure MergeColor_getComponents(col : integer; var components : TMergeColor_components);
begin
  components[0]:=trunc(col/(256*256));
  components[1]:=trunc(col/(256)-components[0]*256);
  components[2]:=trunc(col-components[1]*256-components[0]*256*256);
end;
{function MergeColor(col1, col2 : integer; alpha : integer) : integer; // alpha : 0-255    , alpha2 : integer
var alphaTotal : integer;
    colComponent1, colComponent2, colFinal : TMergeColor_components;
    factAlpha1, factAlpha2 : double;
    i : cardinal;
begin
  (*if alpha=0 then begin
    factAlpha1:=0.5;
    factAlpha2:=0.5;
  end else begin
    factAlpha1:=alpha1/alphaTotal;
    factAlpha2:=alpha2/alphaTotal;
  end;*)
  if alpha<0 then alpha:=0;
  if alpha>255 then alpha:=255;
  factAlpha1:=(255-alpha)/255; // alpha background
  factAlpha2:=(alpha)/255; // alpha dessin dessus


  MergeColor_getComponents(col1, colComponent1);
  MergeColor_getComponents(col2, colComponent2);
  for i:=0 to 2 do begin
    colFinal[i]:=trunc(colComponent1[i]*factAlpha1+colComponent2[i]*factAlpha2);
  end;
  Result:=colFinal[0]*256*256+colFinal[1]*256+colFinal[2];
end;}
function MergeColor(colSource, colDest : integer; alphaSource, alphaDest : integer) : integer; // alpha : 0-255
var alphaTotal : integer;
    colComponent1, colComponent2, colFinal : TMergeColor_components;
    factAlphaSource, factAlphaDest, factAlphaMultiply : double;
    alphaDepasse255 : integer;
    i : cardinal;
begin
  if alphaSource<0 then alphaSource:=0;
  if alphaSource>255 then alphaSource:=255;
  if alphaDest<0 then alphaDest:=0;
  if alphaDest>255 then alphaDest:=255;
  alphaTotal:=alphaSource+alphaDest;
  if alphaTotal=0 then begin
    factAlphaSource:=0.5;
    factAlphaDest:=0.5;
  end else begin

    // Dessin de l'alpha destination
    // et dessus, dessin de l'alpha source.
    //realAlphaSource:=alphaSource+alphaDest; // l'alpha de la source + de la destination

    // J'enlève à alphaDestination l'alphaTotal qui dépasse des 255
    if alphaTotal<=255 then alphaDepasse255:=0
                       else alphaDepasse255:=alphaTotal-255;
    alphaDest:=alphaDest-alphaDepasse255;
    //alphaSource:=alphaSource;
    factAlphaSource:=alphaSource/255;
    factAlphaDest:=alphaDest/255;
    alphaTotal:=alphaSource+alphaDest;
    //factAlphaTotal:=factAlphaDest+factAlphaSource; // ne peut dépasser 1 (parce que alphaSource+alphaDest<=255)
    if alphaTotal>=255 then factAlphaMultiply:=1
                       else factAlphaMultiply:=1/max(0.0001, alphaTotal/255);
    factAlphaSource:=factAlphaSource*factAlphaMultiply;
    factAlphaDest:=factAlphaDest*factAlphaMultiply;
    {factAlphaSource:=alphaSource/alphaTotal;
    factAlphaDest:=alphaDest/alphaTotal;
    if alphaSource=0 then factAlphaDest:=1;
    if alphaDest=0 then factAlphaSource:=1;}
    //factAlphaDest:=(1-factAlphaDest)*alphaSource/256;
    //factAlphaSource:=alphaSource/256; // dessin de l'alpha source
    //factAlpha1:=max(0, (alphaSource-alphaDest)/alphaTotal);
    //factAlpha2:=alpha2/alphaTotal;
    // dessin alpha source : 1-alphaDest; alphaDest = alphaDest/255
  end;
  //factAlphaDest:=0.5;
  //factAlphaSource:=0.5;


  MergeColor_getComponents(colSource, colComponent1);
  MergeColor_getComponents(colDest, colComponent2);
  //alphaTotalManquant:=255-alphaTotal;
  //factAjout:=255/max(1, factAjout); // si alphaTotalManquant, peu importe la couleur, c'est transparent !

  for i:=0 to 2 do begin
    colFinal[i]:=trunc(colComponent1[i]*factAlphaSource+colComponent2[i]*factAlphaDest);
  end;
  Result:=colFinal[0]*256*256+colFinal[1]*256+colFinal[2];
end;



procedure DrawPngWithAlpha_pos_externe(source, dest: TPNGObject; xOrig, yOrig : integer);
var X, Y, xInSource, yInSource : Integer;
    pAlphaSource, pAlphaDest : PByte;
    simuleAlphaDest, simuleAlphaSource : byte; // si les images ne sopportent pas la gestion de l'alpha
    colDest, colSource, destColor : integer;
    x1, x2, y1, y2 : integer; // zone de dessin dans Dest
    enableAlpha_source, enableAlpha_dest : boolean;
begin
  if source=nil then exit;
  if dest=nil then exit;
  if source.Width=0 then exit;
  if source.Height=0 then exit;

  if  ((source.Header.ColorType=COLOR_GRAYSCALEALPHA) or (source.Header.ColorType=COLOR_RGBALPHA)) then
    enableAlpha_source:=true else enableAlpha_source:=false;
  if ((dest.Header.ColorType=COLOR_GRAYSCALEALPHA) or (dest.Header.ColorType=COLOR_RGBALPHA)) then
    enableAlpha_dest:=true else enableAlpha_dest:=false;

  //WriteLn('enableAlpha_source='+booltostr(enableAlpha_source, true));
  //WriteLn('enableAlpha_dest='+booltostr(enableAlpha_dest, true));
  //showMessage('enableAlpha_source='+booltostr());
  x1:=xOrig;
  y1:=yOrig;
  x2:=xOrig+source.Width-1;
  y2:=yOrig+source.Height-1;
  // I have no idea why standard implementation of TPNGObject.Draw doesn't apply transparency.
  for x:=x1 to x2 do
  for y:=y1 to y2 do begin
    if x<0 then continue;
    if y<0 then continue; // je ne dessine pas hors de l'image de destination !
    if x>=dest.Width then continue;
    if y>=dest.Height then continue;
    xInSource:=x-x1; // position toujours valide
    yInSource:=y-y1;
    colSource:=source.Pixels[xInSource, yInSource];
    colDest:=dest.Pixels[x, y];

    if enableAlpha_dest then begin // gestion de l'alpha destination
      pAlphaDest:=@dest.AlphaScanline[y]^[x];
    end else begin
      simuleAlphaDest:=1;
      pAlphaDest:=@simuleAlphaDest;
    end;
    if enableAlpha_source then begin // gestion de l'alpha source
      pAlphaSource:=@source.AlphaScanline[yInSource]^[xInSource]; // y en premier
    end else begin
      simuleAlphaSource:=1;
      pAlphaSource:=@simuleAlphaSource;
    end;

    destColor:=MergeColor(colSource, colDest, pAlphaSource^, pAlphaDest^);
    Dest.Pixels[x, y]:=destColor;
    if enableAlpha_dest then pAlphaDest^ := max(pAlphaSource^, pAlphaDest^);

    //destColor:=clBlack;
    //pDestAlpha^ := Min(255, pSrcAlpha^ + pDestAlpha^); // addition des deux alphas (et non-dépassement de l'alpha max de 255
    
  end;
end;
procedure TPngUtils.DrawPngWithAlpha_pos(source, dest: TPNGObject; xOrig, yOrig : integer);
begin
  DrawPngWithAlpha_pos_externe(source, dest, xOrig, yOrig);
end;

//ClearPngAlpha : réinitialisation de l'alpha de l'image png
procedure ClearPngAlpha_externe(png : TPngObject);
var x, y : cardinal;
    pAlpha : PByte;
begin
  if png=nil then exit;
  if (png.Header.ColorType<>COLOR_GRAYSCALEALPHA) and (png.Header.ColorType<>COLOR_RGBALPHA) then exit; // l'image ne supporte pas la gestion de l'alpha
  //showMessage('png.Width='+inttostr(png.Width)+'  png.Height='+inttostr(png.Height));
  if png.Width=0 then exit;
  if png.Height=0 then exit;
  for x:=0 to png.Width-1 do
  for y:=0 to png.Height-1 do begin
    pAlpha:=@png.AlphaScanline[y]^[x];
    pAlpha^:=0;
    png.Canvas.Pixels[x, y]:=clBlack;
  end;
end;
procedure TPngUtils.ClearAlpha(png : TPngObject);
begin
  try
  ClearPngAlpha_externe(png);
  except
  end;
end;

procedure PngObject_resizeAndClearAlpha_externe(png : TPngObject; newWidth, newHeight : cardinal);
var x, y : cardinal;
begin
  try
    if png=nil then exit;
    png.Resize(newWidth, newHeight);
    if (newWidth<>0) and (newHeight<>0) then begin
      for x:=0 to newWidth-1 do
      for y:=0 to newHeight-1 do begin
        png.Pixels[x, y]:=0; // réinitialisation de la couleur des pixels
      end;
      if (png.Header.ColorType=COLOR_GRAYSCALEALPHA) or (png.Header.ColorType=COLOR_RGBALPHA) then begin // Si l'alpha est prise en charge par l'image
        for x:=0 to newWidth-1 do
        for y:=0 to newHeight-1 do begin
          png.AlphaScanline[y]^[x]:=0; // Réinitialisation de l'alpha
        end;
      end;
    end;
  except
    ShowMessage('PngObject_resizeAndClearAlpha : exception.');
  end;
end;
procedure TPngUtils.ResizeAndClearAlpha(png : TPngObject; newWidth, newHeight : cardinal);
begin
  try
    PngObject_resizeAndClearAlpha_externe(png, newWidth, newHeight);
  except
  end;
end;

end.
