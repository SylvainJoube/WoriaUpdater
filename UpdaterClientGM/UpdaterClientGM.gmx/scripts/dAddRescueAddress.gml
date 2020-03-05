/// dAddRescueAddress(arg_ip, arg_port, placerEnPremier, nomGraphiqueAdresse);
// Ajouter via GM une adresse de connexion alternative à essayer
// (pour ne pas avoir à mettre à jour la dll juste pour ajouter une adresse possible de connexion)


var ip = argument0;
var port = argument1;
var putFirst = argument2;
var nomGraphiqueAdresse = argument3;

dSetString(nomGraphiqueAdresse);
external_call(global.DLL_dAddRescueAddress, -1, 0); // passage du nom graphique (à afficher) de l'adresse
dSetString(ip);
return external_call(global.DLL_dAddRescueAddress, port, putFirst);
