/// BoxText(width,str)

var Width,list,Plus,c,find,linesList,posList,word,Str,d,str,oldStr,car,Car;
Width=argument0;

var wordList=ds_list_create(); // la liste des mots
var char="";
var nbMots=0;
var c=1;
var str=argument1;
var strLen=string_length(str);
var mot;
ds_list_add(wordList, ''); // premier mot vide
for (c=1; c<=strLen; c++) {
    char=string_copy(str, c, 1);
    if char = chr(10) { // saut de ligne
        nbMots++;
        ds_list_add(wordList, chr(10));
        nbMots++;
        ds_list_add(wordList, ''); // nouveau mot
        continue;
    }
    
    if char=" " {
        nbMots++;
        ds_list_add(wordList, ''); // nouveau mot
    } else {
        mot=ds_list_find_value(wordList, nbMots)+char;
        ds_list_replace(wordList, nbMots, mot);
    }
}
//show_message("Mots : "+string(ds_list_size(list)))

var list=wordList;
linesList=ds_list_create()
ds_list_add(linesList,"")
posList=0
c=0
repeat(ds_list_size(list)) {
    var readWord = ds_list_find_value(list, c);
    if readWord == chr(10) {
        ds_list_add(linesList, "");
        posList+=1;
        c++;
        continue;
    }
    word=ds_list_find_value(list,c)+" "
    Str=ds_list_find_value(linesList, posList)
    
    if string_width(Str+word)>Width // si ça dépasse de la ligne
        {if string_width(word)<=Width // si le mot tient en une ligne
            {ds_list_add(linesList, word)
            posList+=1}
        else // si il est trop grand pour tenir en une ligne
            {
            d=1 // on va en mettre un bout au début puis poursuivre
            str=""
            repeat(1000)
                {oldStr=str
                car=string_copy(word,d,1)
                str+=car
                if string_width(Str+str)>Width // si on a dépassé la boite
                    {ds_list_replace(linesList,posList,Str+oldStr) // on remplace la ligne (elle est pleine)
                    posList+=1
                    Str=string_copy(word,d,1)
                    str=""
                    ds_list_add(linesList,Str)}
                
                if car=""
                    {ds_list_replace(linesList,posList,Str+str) // on remplace la ligne (elle est pleine)
                    break}
                d+=1}
            }
        }
    else // donc que  string_width(Str+word)<=Width, que ça tient en une ligne
        {ds_list_replace(linesList,posList,Str+word)}
    c+=1}


/*Str=""
c=0
repeat(ds_list_size(linesList))
    {Str+=ds_list_find_value(linesList,c)+"#"
    c+=1}*/
//show_message(string(ds_list_size(linesList)))




//ds_list_destroy(list) // la liste des mots
//ds_list_destroy(linesList) // la liste de ce qu'il y a écrit à chaque ligne

return(linesList)

