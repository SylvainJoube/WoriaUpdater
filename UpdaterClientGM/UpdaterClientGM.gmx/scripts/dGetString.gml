/// dGetString();

var strLen=dGetCurrentString(0);
var str='';
var i;
for (i=1; i<=strLen; i++) // L'indexation du string commence à 1.
    str+=chr(dGetCurrentString(i));

return str;
