/// dUninstallFull(arg_windowHandle);
// arg_valueIndex :
// -1 : Uninstall_currentFileCount
//  0 : savoir si la désinstallation est en cours ou non
//  1 : désinstaller
//  2 : annuler la désinstallation

return external_call(global.DLL_dUninstallFull, argument0);
