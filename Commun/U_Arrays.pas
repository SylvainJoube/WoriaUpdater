unit U_Arrays;

interface
uses math;

type TObjectArray = array of TObject;
type TPObjectArray = ^TObjectArray;

type TCardinalArray = array of cardinal;
type TPCardinalArray = ^TCardinalArray;

type TByteArray = array of byte;
type TPByteArray = ^TByteArray;

type TStringArray = array of string;
type TPStringArray = ^TStringArray;

// Fonctions de tri
{type TSortItem = class
  public
    value : cardinal;
    ref : TObject;  // Je pensais qu'utiliser un record serait plus optimisé, mais en fait, c'est la même chose.
end;}
type TSortItemRec = record
  value : cardinal;
  ref : TObject;
end;
type TPSortItemRec = ^TSortItemRec;
type TSortList = class
  private
    A1pItem : array of TPSortItemRec;//TSortItem;
    A1Item : array of TSortItemRec;// juste pour avoir les instances
    putIndex : cardinal;
    //A1SortItem : array of TSortItem;
    //function MoveUpToGreater(currentIndex : cardinal) : cardinal; // retourne l'index où je me suis arrété
    function Switch(currentIndex : cardinal) : boolean;
  public
    procedure Add(obj : TObject; value : cardinal);
    //procedure Sort0;
    procedure Sort;
    procedure Test;
    function Get(index : cardinal) : TObject;
    destructor Destroy; override;
    constructor Create(arraySize : cardinal = 0); virtual; // Définir la taille est important, pour un classement de nombreux objets (significatif à partir d'environ 1000 objets)
end;


procedure CardinalArrayDelete(ar : TPCardinalArray; index : cardinal);
//procedure CardinalArray_add(ar : TPCardinalArray; value : cardinal);
function CardinalArrayFindIndex(ar : TPCardinalArray; value : cardinal) : integer; // Trouver l'index d'une valeur dans une liste d'entiers non signés (4 octets).
procedure ByteArrayDelete(ar : TPByteArray; index : cardinal);
procedure StringArrayDelete(ar : TPStringArray; index : cardinal);
function ObjectArrayDelete(ar : TPObjectArray; index : cardinal) : boolean;
function ObjectArrayFindIndex(ar : TPObjectArray; value : TObject) : integer;
function ObjectArrayDeleteFromValue(ar : TPObjectArray; value : TObject) : boolean;
procedure ObjectArrayDestroy(ar : TPObjectArray);
function ObjectArrayInsert(ar : TPObjectArray; index : cardinal; newObj : TObject) : boolean;

procedure ArrayDelete(ar : pointer; arraySize : cardinal; itemSize : cardinal; index : cardinal);

implementation
uses SysUtils;

procedure CardinalArrayDelete(ar : TPCardinalArray; index : cardinal);
var i, reste : integer;
    index64 : int64;
begin
try
  if Length(ar^)=0 then exit; // Liste vide
  index64:=index; // Pour éviter le [warning] combinaison de deux nombres aux bornes différentes.
  if Length(ar^)<=index64 then exit; // Index non contenu dans la liste (trop grand)
  reste:=Length(ar^)-1-index64;
  if reste<>0 then
  for i:=index64 to Length(ar^)-2 do begin
    ar^[i]:=ar^[i+1];
  end;
  SetLength(ar^, Length(ar^)-1);
except WriteLn('GRAVE CardinalArrayDelete : exception.'); end;
end;

procedure CardinalArray_add(ar : TPCardinalArray; value : cardinal);
var len : cardinal;
begin
try
  len:=length(ar^);
  SetLength(ar^, len+1);
  ar^[len+1]:=value;
except WriteLn('GRAVE CardinalArrayAdd : exception.'); end;
end;

procedure ByteArrayDelete(ar : TPByteArray; index : cardinal);
var i, reste : integer;
    index64 : int64;
begin
try
  if Length(ar^)=0 then exit; // Liste vide
  index64:=index; // Pour éviter le [warning] combinaison de deux nombres aux bornes différentes.
  if Length(ar^)<=index64 then exit; // Index non contenu dans la liste (trop grand)
  reste:=Length(ar^)-1-index64;
  if reste<>0 then
  for i:=index64 to Length(ar^)-2 do begin
    ar^[i]:=ar^[i+1];
  end;
  SetLength(ar^, Length(ar^)-1);
except WriteLn('GRAVE ByteArrayDelete : exception.'); end;
end;


procedure StringArrayDelete(ar : TPStringArray; index : cardinal);
var i, reste : integer;
    index64 : int64;
begin
try
  if Length(ar^)=0 then exit; // Liste vide
  index64:=index; // Pour éviter le [warning] combinaison de deux nombres aux bornes différentes.
  if Length(ar^)<=index64 then exit; // Index non contenu dans la liste (trop grand)
  reste:=Length(ar^)-1-index64;
  if reste<>0 then
  for i:=index64 to Length(ar^)-2 do begin
    ar^[i]:=ar^[i+1];
  end;
  SetLength(ar^, Length(ar^)-1);
except WriteLn('GRAVE StringArrayDelete : exception.'); end;
end;
                                    
function ObjectArrayDelete(ar : TPObjectArray; index : cardinal) : boolean;
var i, reste : integer;
    index64 : int64;
    obj : TObject;
begin
Result:=false;
try
  if Length(ar^)=0 then exit; // Liste vide
  index64:=index; // Pour éviter le [warning] combinaison de deux nombres aux bornes différentes.
  if Length(ar^)<=index64 then exit; // Index non contenu dans la liste (trop grand)
  reste:=Length(ar^)-1-index64;
  if reste<>0 then
  for i:=index64 to Length(ar^)-2 do begin
    obj:=ar^[i+1];
    ar^[i]:=obj;
  end;
  SetLength(ar^, Length(ar^)-1);
  Result:=true;
except WriteLn('GRAVE ObjectArrayDelete : exception.'); end;
end;

function ObjectArrayFindIndex(ar : TPObjectArray; value : TObject) : integer;
var i : cardinal;
begin
  Result:=-1;
  if Length(ar^)=0 then exit;
  for i:=0 to Length(ar^)-1 do begin
    if ar^[i]=value then begin
      Result:=i; // J'ai trouvé l'index.
      exit;
    end;
  end;
end;
function ObjectArrayDeleteFromValue(ar : TPObjectArray; value : TObject) : boolean;
var index : integer;
begin
  Result:=false; // Non trouvé
  index:=ObjectArrayFindIndex(ar, value);
  //WriteLn('ObjectArrayDeleteFromValue : '+IntToStr(index));
  if index=-1 then exit;
  ObjectArrayDelete(ar, index);
  Result:=true;
end;


procedure ArrayDelete(ar : pointer; arraySize : cardinal; itemSize : cardinal; index : cardinal);
var i, reste : integer;
    index64 : int64;
    //obj : TObject;
    bytePtrWrite, bytePtrRead : PByte;
begin
  if arraySize=0 then exit;
  index64:=index; // Pour éviter le [warning] combinaison de deux nombres aux bornes différentes.
  if arraySize<=index64 then exit; // Index non contenu dans la liste (trop grand)
  reste:=arraySize-1-index64;
  bytePtrWrite:=PByte(ar);
  bytePtrRead:=PByte(ar);

  if reste<>0 then begin
    Inc(bytePtrRead, (itemSize+1)*index); // Initialisation de la position du pointeur : case suivante.
    Inc(bytePtrWrite, itemSize*index);
    // Modificaion des octets suivants. Je shift le tout de itemSize.
    // Je copie la zone mémoire allant de bytePtrRead à bytePtrRead+reste*itemSize dans la zone allant bytePtrWrite à bytePtrWrite+reste*itemSiz
    for i:=0 to (reste)*Int64(itemSize)-1 do begin
      bytePtrWrite^:=bytePtrRead^;
      Inc(bytePtrWrite, 1);
      Inc(bytePtrRead, 1);
    end;
  end;

  //for i:=index64 to arraySize-2 do begin
    {ar[i]:=ar[i+1];}
  //end;
  ReallocMem(ar, (arraySize-1)*itemSize);
end;

// Trouver l'index d'une valeur dans une liste d'entiers non signés (4 octets).
function CardinalArrayFindIndex(ar : TPCardinalArray; value : cardinal) : integer;
var i : cardinal;
begin
  if Length(ar^)=0 then begin
    Result:=-1;
    exit;
  end;
  Result:=-1;
  for i:=0 to Length(ar^)-1 do
  if ar^[i]=value then begin
    Result:=i;
    exit;
  end;
end;

// Libération de la mémoire utilisée par la liste.
procedure ObjectArrayDestroy(ar : TPObjectArray);
var len, i : cardinal;
begin
  if ar=nil then exit;
  len:=Length(ar^);
  if len=0 then exit;
  for i:=0 to len-1 do
    ar^[i].Destroy;
end;

function ObjectArrayInsert(ar : TPObjectArray; index : cardinal; newObj : TObject) : boolean;
var len, i, iInverse : cardinal;
begin
  Result:=false;
  if ar=nil then exit;
  len:=length(ar^);
  if index>len then exit; // index trop grand, même en ayant redimensionné
  SetLength(ar^, len+1);
  // Si ce n'est pas un ajout à la fin de la liste, je décale les objets qui viennent après index
  if index<>len then begin
    for i:=index to len-1 do begin // len-1 et non len-2 : len-1 est ici le dernier index de l'ancienne liste (ancienne taille)
      iInverse:=len-1-(i-index); // i=index : len-1 à i=len : len-1-len+1+index=index
      ar^[iInverse+1]:=ar^[iInverse];
    end;
  end;
  ar^[index]:=newObj;
  Result:=true;
end;



procedure TSortList.Add(obj : TObject; value : cardinal);
var //item : TSortItem;
    len : cardinal;
    pItem : TPSortItemRec;
begin
  len:=length(A1Item);
  if putIndex>=len then begin
    SetLength(A1Item, putIndex+1);
    //SetLength(A1SortItem, putIndex+1);
  end;
  //SetLength(A1pItem, len+1);
  //A1pItem[len]:=@A1Item[len];
  pItem:=@A1Item[putIndex];
  pItem^.value:=value;
  pItem^.ref:=obj;
  putIndex:=putIndex+1;
  //SetLength(A1SortItem, putIndex+1);
  //A1SortItem[putIndex]:=TSortItem.Create;

  {if putIndex>=len then
    SetLength(A1Item, putIndex+1);
  if length(A1pItem)<putIndex+1 then SetLength(A1pItem, putIndex+1);
  pItem:=@A1Item[putIndex];
  pItem^.value:=value;
  pItem^.ref:=obj;
  A1pItem[putIndex]:=pItem;

  putIndex:=putIndex+1;}



  {item:=TSortItem.Create;
  item.value:=value;
  item.ref:=obj;

  len:=length(A1SortItem);
  if putIndex>=len then
    SetLength(A1SortItem, putIndex+1);
  
  A1SortItem[putIndex]:=item;
  putIndex:=putIndex+1;}
end;

{function TSortList.MoveUpToGreater(currentIndex : cardinal) : cardinal; // retourne l'index où je me suis arrété
var len, i, lastIndex : cardinal;
    currentItem, item, lastItem : TSortItem;
    currentValue, value, stopIndex : cardinal;
    found : boolean;
begin
  len:=length(A1SortItem);
  if currentIndex>=len then begin // index invalide ou à la fin de la liste
    Result:=len;
    exit;
  end;

  currentItem:=A1SortItem[currentIndex];
  currentValue:=currentItem.value;
  stopIndex:=currentIndex+1; // index suivant (nombre plus grand ou fin de la liste)
  found:=false;
  // Il y a au moins un objet restant après celui là. (sinon, je suis parti via exit)
  for i:=currentIndex+1 to len-1 do begin
    item:=A1SortItem[i];
    value:=item.value;
    if value>=currentValue then begin // valeur à la position i plus grande que la valeur donnée
      lastIndex:=i-1; // toujours positif, pas de souci
      if lastIndex<>currentIndex then begin // échange des positions si j'ai avancé.
        lastItem:=A1SortItem[lastIndex];
        A1SortItem[lastIndex]:=currentItem;
        A1SortItem[currentIndex]:=lastItem;
        stopIndex:=i;
      end;
      found:=true;
      break;
    end;
  end;

  // cas où c'est le plus grand nombre, donc où il ne s'est pas arrété à la fin
  if not found then begin
    item:=A1SortItem[len-1];
    A1SortItem[len-1]:=currentItem;
    A1SortItem[currentIndex]:=item;
    stopIndex:=len-1;
  end;
  //WriteLn('MoveUpToGreater diff='+inttostr(stopIndex-currentIndex));

  Result:=stopIndex;
end;}

{function TSortList.Switch(currentIndex : cardinal) : boolean; // interversion des positions : teste currentIndex avec currentIndex+1
var item1, item2 : TSortItem;
begin
  Result:=false; // pas bougé
  item1:=A1SortItem[currentIndex];
  item2:=A1SortItem[currentIndex+1];
  if item1.value>item2.value then begin
    A1SortItem[currentIndex]:=item2;
    A1SortItem[currentIndex+1]:=item1;
    // Bougé
    Result:=true;
  end;
end;}

function TSortList.Switch(currentIndex : cardinal) : boolean; // interversion des positions : teste currentIndex avec currentIndex+1
var pItem1, pItem2 : TPSortItemRec;
begin
  Result:=false; // pas bougé
  pItem1:=A1pItem[currentIndex];
  pItem2:=A1pItem[currentIndex+1];
  if pItem1^.value>pItem2^.value then begin
    A1pItem[currentIndex]:=pItem2;
    A1pItem[currentIndex+1]:=pItem1;
    // Bougé
    Result:=true;
  end;
end;

{procedure TSortList.Sort0; // dans l'ordre croissant
var len, stopIndex, newStopIndex : cardinal;
    diffMax : integer;
    //iterations : cardinal;
begin
  // Avancer jusqu'à trouver plus grand; répéter le nombre de fois nécessaires.
  len:=length(A1SortItem);
  diffMax:=len;
  //iterations:=0;
  while diffMax>1 do begin
    diffMax:=0;
    stopIndex:=0;
    while stopIndex<len-1 do begin
      newStopIndex:=MoveUpToGreater(stopIndex);
      diffMax:=max(diffMax, newStopIndex-stopIndex);
      stopIndex:=newStopIndex;
    end;
    //iterations:=iterations+1;
  end;
  //WriteLn('TSortList.Sort0 : itérations=', iterations);
end;}

procedure TSortList.Sort; // dans l'ordre croissant
var i : cardinal;
    change : boolean;
    //iterations : cardinal;
begin
  if putIndex=0 then exit;
  if putIndex=1 then begin
    SetLength(A1pItem, 1);
    A1pItem[0]:=@A1Item[0];
    exit;
  end;
  SetLength(A1pItem, putIndex);
  for i:=0 to putIndex-1 do
    A1pItem[i]:=@A1Item[i];
  
  change:=true;
  //iterations:=0;
  while change do begin
    change:=false;
    for i:=0 to putIndex-2 do
      change:=(Switch(i)) or change;
    //iterations:=iterations+1;
  end;
  //WriteLn('TSortList.Sort : itérations=', iterations);
end;

type TNb = class
  public
    nb : cardinal;
end;
procedure TSortList.Test;
var i, len : cardinal;
    time : int64;
    obj : TNb;
begin
  RandSeed:=42;
  len:=8000;
  time:=trunc(now*power(10, 8));
  for i:=0 to len-1 do begin
    obj:=TNb.Create;
    obj.nb:=random(100000);
    Add(obj, obj.nb);
  end;
  {Add(nil, 6);
  Add(nil, 24);
  Add(nil, 7);
  Add(nil, 8);
  Add(nil, 11);
  Add(nil, 15);
  Add(nil, 87);
  Add(nil, 8);
  Add(nil, 54);
  Add(nil, 4);}
  Sort;
  WriteLn('Temps pris : '+inttostr(trunc(now*power(10, 8))-time));
  len:=100;//length(A1SortItem);
  for i:=0 to len-1 do
    WriteLn(TNb(Get(i)).Nb);
end;

function TSortList.Get(index : cardinal) : TObject;
begin
  Result:=nil;
  if integer(index)>=length(A1pItem) then exit;
  Result:=A1pItem[index]^.ref;
end;

destructor TSortList.Destroy;
begin
  inherited;
end;

constructor TSortList.Create(arraySize : cardinal = 0);
begin
  inherited Create;
  SetLength(A1Item, arraySize);
  //SetLength(A1SortItem, arraySize);
  putIndex:=0;
end;

end.
