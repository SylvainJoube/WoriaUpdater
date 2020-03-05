/// dSetString(str);

var str=argument0;
var len=string_length(str);

dSetCurrentString(0, len);

for (i=1; i<=len; i++) // L'indexation du string commence à 1.
    dSetCurrentString(i, ord(string_copy(str, i, 1)));

return true;
