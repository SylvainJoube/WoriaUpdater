unit U_CraftTable;

interface
uses U_Objects;
// /!\
// /!\ /!\
// /!\ /!\ /!\ U_CraftTable et U_EditCraftTable ne se voient pas et ne s'utilisent pas. /!\ /!\ /!\
const craftTable_width = 8;
const craftTable_height = 8;

procedure CraftTable_initModels(standAlone : boolean = StandAloneExe);

type TCraftTableRessource = class // qui N'EST PAS la même que dans U_EditCraftTable, où elle est un record.
  // La pos x, y est indiquée dans le tableau A3CraftTableModel.
  public
    Lancable, Solide, ExtraireAvec, Propulseur : boolean; // Les caractéristiques nécessaires pour placer la ressource.
    function IsEqualTo(autreRess : TCraftTableRessource) : boolean; // Est égalme et non au moins égale. (plus = faux; moins = faux)
    function IsAsLeastEqualTo(autreRess : TCraftTableRessource) : boolean; // Est au moins égale. (égal = vrai; plus = vrai; moins = faux)
    //function IsAsLeastEqualTo(autreRess : TModelRessource) : boolean; overload;
end;
// Unisuement pour la vérification côté serveur, pour limiter la taille de la liste de vérification.
type TCraftTableRessource_verifServeur = record
  craftTableRessource : TCraftTableRessource;
  Nombre : word;
end;

type TCraftTableModelObject = (tyCoque, tyExtracteur, tyReacteur, tyCanon);
type TCraftTableModel = class
  public
    Id : cardinal;
    Nom : string;
    // Type de l'objet crafté
    CraftedObject : TCraftTableModelObject;
    // Ressources nécessaires
    A2NeededRessource : array [0..craftTable_width-1, 0..craftTable_height-1] of TCraftTableRessource;
    // Vérification côté serveur : je mets ici une liste des ressources nécessairs au craft
    A1NeededRessource_verifServeur : array of TCraftTableRessource_verifServeur;
end;


var A1CraftTableModel : array of TCraftTableModel;

type TA2GameCraftTable = array [0..craftTable_width-1, 0..craftTable_height-1] of TModelRessource; // 1 seule par case
function CraftTable_getObjectIdFromArray(var A2GameCraftTable : TA2GameCraftTable) : integer; // -1 sur échec
function CraftTableModel_find(modelId : cardinal) : TCraftTableModel;


type TCraftModelRessource_number = record
  modelRessource : TModelRessource;
  number : cardinal;
end;
type TCraftTable_ressRecue = record
  Id, Nb : cardinal;
end;
type TA1CraftTable_ressRecue = array of TCraftTable_ressRecue;
type PTA1CraftTable_ressRecue = ^TA1CraftTable_ressRecue;

implementation
uses U_Files, U_NetSys3, SysUtils;

function TCraftTableRessource.IsEqualTo(autreRess : TCraftTableRessource) : boolean;
begin
  Result:=false;
  if  (autreRess.Lancable=self.Lancable)
  and (autreRess.Solide=self.Solide)
  and (autreRess.ExtraireAvec=self.ExtraireAvec)
  and (autreRess.Propulseur=self.Propulseur) then
    Result:=true;
end;

function TCraftTableRessource.IsAsLeastEqualTo(autreRess : TCraftTableRessource) : boolean;
begin
  Result:=true;
  if autreRess.Lancable     and not self.Lancable then begin Result:=false; exit; end;
  if autreRess.Solide       and not self.Solide then begin Result:=false; exit; end;
  if autreRess.ExtraireAvec and not self.ExtraireAvec then begin Result:=false; exit; end;
  if autreRess.Propulseur   and not self.Propulseur then begin Result:=false; exit; end;
end;

{function TCraftTableRessource.IsAsLeastEqualTo(autreRess : TModelRessource) : boolean;
begin
  Result:=true;
  if autreRess.Lancable     and not self.Lancable then begin Result:=false; exit; end;
  if autreRess.Solide       and not self.Solide then begin Result:=false; exit; end;
  if autreRess.ExtraireAvec and not self.ExtraireAvec then begin Result:=false; exit; end;
  if autreRess.Propulseur   and not self.Propulseur then begin Result:=false; exit; end;
end;}

// Création d'un nouvel objet modèle

procedure CraftTable_initModels(standAlone : boolean = StandAloneExe);
var len, i, x, y : cardinal;
    craft, craftRectifie : TCraftTableModel;
    wsize, hsize, xMin, yMin : cardinal;
    solide, lancable, extraire, propulser : boolean;
    craftRess, craftRess2 : TCraftTableRessource;
    len2, i2 : cardinal;
    found : boolean;
    path : string;
begin
  if standAlone then path:='data\craftObjects.sys'
                else path:='C:\Users\Sylvain\Desktop\Womos Universe\WandaServer\data\craftObjects.sys';
  if not ReadBufferFromFile(path) then exit;
  len:=readuint;
  SetLength(A1CraftTableModel, len);
  if len=0 then exit;
  // Chargement de l'objet d'index i
  for i:=0 to len-1 do begin
    craft:=TCraftTableModel.Create;
    craftRectifie:=TCraftTableModel.Create; // Je calcule la position d'origine du dessin et je le mets en haut à gauche.
    A1CraftTableModel[i]:=craftRectifie; // il n'a que son tableau d'initialisé
    craftRectifie.Id:=readuint;
    craftRectifie.Nom:=readstring;
    craftRectifie.CraftedObject:=TCraftTableModelObject(readuint);
    wsize:=readuint; // Je mets la taille de la table de crafs, au cas où (en cas de changement)
    hsize:=readuint;

    for x:=0 to wsize-1 do
    for y:=0 to hsize-1 do begin
      solide:=readbool;
      lancable:=readbool;
      extraire:=readbool;
      propulser:=readbool; // S'il y a quelque chose, je crée l'objet.
      if solide or lancable or extraire or propulser then begin
        craft.A2NeededRessource[x, y]:=TCraftTableRessource.Create;
        craft.A2NeededRessource[x, y].Solide:=solide;
        craft.A2NeededRessource[x, y].Lancable:=lancable;
        craft.A2NeededRessource[x, y].ExtraireAvec:=extraire;
        craft.A2NeededRessource[x, y].Propulseur:=propulser;
      end;
    end;

    // Je calcule la position d'origine des dessins et je les mets en haut à gauche.
    xMin:=craftTable_width; // Position volontairement invalide !
    yMin:=craftTable_height;
    for x:=0 to craftTable_width-1 do
    for y:=0 to craftTable_height-1 do
    if craft.A2NeededRessource[x, y]<>nil then begin
      if xMin>x then xMin:=x;
      if yMin>y then yMin:=y;
    end;

    //WriteLn('Rectifié : ', xMin, ',', yMin);
    // Initialement, toutes les cases de craftRectifie.A2NeededRessource sont à nil.
    for x:=xMin to craftTable_width-1 do
    for y:=yMin to craftTable_height-1 do
    if craft.A2NeededRessource[x, y]<>nil then begin
      craftRectifie.A2NeededRessource[x-xMin, y-yMin]:=craft.A2NeededRessource[x, y];
    end;

    // Je constitue la liste A1NeededRessource_verifServeur :
    for x:=0 to craftTable_width-1 do
    for y:=0 to craftTable_height-1 do begin
      craftRess:=craftRectifie.A2NeededRessource[x, y];
      if craftRess<>nil then begin // Je l'ajoute à A1NeededRessource_verifServeur
        len2:=length(craftRectifie.A1NeededRessource_verifServeur);
        // Je regarde si elle est déjà dans la liste
        found:=false;
        if len2<>0 then for i2:=0 to len2-1 do begin
          craftRess2:=craftRectifie.A1NeededRessource_verifServeur[i2].craftTableRessource;
          if craftRess2.IsEqualTo(craftRess) then begin
            found:=true;
            craftRectifie.A1NeededRessource_verifServeur[i2].Nombre:=craftRectifie.A1NeededRessource_verifServeur[i2].Nombre+1;
            break;
            // désolé pour la lourdeur de l'écriture, mais c'est un record ^^ (donc pas de passage par adresse sans pointeur)
          end;
        end;
        if not found then begin
          SetLength(craftRectifie.A1NeededRessource_verifServeur, len2+1);
          craftRectifie.A1NeededRessource_verifServeur[len2].Nombre:=1;
          craftRectifie.A1NeededRessource_verifServeur[len2].craftTableRessource:=craftRess;
        end;
      end;
    end;
    {WriteLn('Objet : ', length(craftRectifie.A1NeededRessource_verifServeur));
    len2:=length(craftRectifie.A1NeededRessource_verifServeur);
    if len2<>0 then for i2:=0 to len2-1 do begin
      WriteLn(craftRectifie.A1NeededRessource_verifServeur[i2].Nombre, ' propulseur=', booltostr(craftRectifie.A1NeededRessource_verifServeur[i2].craftTableRessource.Propulseur, true));
    end;}

  end;


end;

function CraftTableModel_find(modelId : cardinal) : TCraftTableModel;
var len, i : cardinal;
begin
  Result:=nil;
  len:=Length(A1CraftTableModel);
  if len=0 then exit;
  for i:=0 to len-1 do
  if A1CraftTableModel[i].Id=modelId then begin
    Result:=A1CraftTableModel[i];
    exit;
  end;
end;






// Crafting table
function CraftTable_getObjectIdFromArray(var A2GameCraftTable : TA2GameCraftTable) : integer; // -1 sur échec
var xMin, yMin, x, y : cardinal;
    len, i : cardinal;
    same : boolean;
    ress : TModelRessource;
    xInGameCraftTable, yInGameCraftTable : cardinal;
    craftTableModel : TCraftTableModel;
    craftTableRessource : TCraftTableRessource;
begin
  Result:=-1;
  // Je regarde le point d'origine du dessin du craft
  xMin:=craftTable_width; // Position volontairement invalide !
  yMin:=craftTable_height;
  for x:=0 to craftTable_width-1 do
  for y:=0 to craftTable_height-1 do
  if A2GameCraftTable[x, y]<>nil then begin
    if xMin>x then xMin:=x;
    if yMin>y then yMin:=y;
  end;
  //showmessage('Rectif : '+inttostr(xMin)+', '+inttostr(yMin));
  // Je vais maintenant comparer ce tableau avec les tableaux des crafts en mémoire (définis via l'éditeur)
  // (en prenant en compte xMin et yMin)
  len:=Length(A1CraftTableModel);
  if len<>0 then for i:=0 to len-1 do begin
    same:=true; // Correspond (en attente d'une infirmation)
    craftTableModel:=A1CraftTableModel[i];
    for x:=0 to craftTable_width-1 do if same then
    for y:=0 to craftTable_height-1 do begin
      xInGameCraftTable:=x+xMin;
      yInGameCraftTable:=y+yMin;
      if (xInGameCraftTable>=craftTable_width) or (yInGameCraftTable>=craftTable_height) then
        ress:=nil // Position invalide (hors du tableau) donc ressource nule.
      else
        ress:=A2GameCraftTable[x+xMin, y+yMin];
      craftTableRessource:=craftTableModel.A2NeededRessource[x, y];
      // Première vérification : si la ressource est nule
      if ress=nil then begin
        if craftTableRessource=nil then continue // ça correspond
        else begin same:=false; break; end;//showMessage('ress=nil et craftTableRessource=nil'); break; end;
      end;
      // Donc ici, ress<>nil
      if craftTableRessource=nil then begin
        same:=false; // ress<>nil et il n'y a rien sur le modèle : ne correspond pas.
        //showMessage('ress<>nil et craftTableRessource=nil en '+inttostr(x)+','+inttostr(y));
        break;
      end;
      // ici, rien n'est nul, je vérifie que la ressource a les aptitudes demandées
      // La ressource ress doit au moins avoir les caractéristiques demandées
      if craftTableRessource.Lancable     and not ress.Lancable     then begin same:=false; break; end;//showMessage('Pas lancable !'); end;
      if craftTableRessource.Solide       and not ress.Solide       then begin same:=false; break; end;//showMessage('Pas solide !'); end;
      if craftTableRessource.ExtraireAvec and not ress.ExtraireAvec then begin same:=false; break; end;//showMessage('Pas extraire !'); end;
      if craftTableRessource.Propulseur   and not ress.Propulseur   then begin same:=false; break; end;//showMessage('Pas propulser !'); end;
      // Ici, tout coïncide, je peux donc
    end;
    if same then begin // Si tout coïncide
      Result:=craftTableModel.Id;
      exit;
    end;
  end;
end;












end.
