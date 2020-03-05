/// DLL_init();

//dNePasSupprimerPourExporter();

//get_string("", working_directory);
//get_string("", working_directory+'\UpdaterClient_xe8_GM_DLL.dll');

var dPa = "UpdaterClientDll.dll";//'UpdaterClient_xe8_GM_DLL.dll';//'C:\Users\admin\Desktop\top\taptapDlle\core.dll';//'C:\Users\admin\Desktop\top\#çà@°]=}~é&\core.dll';

global.DLL_filePath=dPa;//'core.dll';//'C:\Users\admin\Desktop\Woria Alpha\Client\CoreDll v2\core.dll';
var dllPath=global.DLL_filePath;

global.DLL_dPlay=external_define(dllPath, 'dPlay', dll_cdecl, ty_real, 1, ty_real);
global.DLL_dStep=external_define(dllPath, 'dStep', dll_cdecl, ty_real, 0);

global.DLL_dGetUpdaterButton=external_define(dllPath, 'dGetUpdaterButton', dll_cdecl, ty_real, 2, ty_real, ty_real);
global.DLL_dGetUpdaterNetSpeed=external_define(dllPath, 'dGetUpdaterNetSpeed', dll_cdecl, ty_real, 1, ty_real);

global.DLL_dGetCurrentString=external_define(dllPath, 'dGetCurrentString', dll_cdecl, ty_real, 1, ty_real);
global.DLL_dSetCurrentString=external_define(dllPath, 'dSetCurrentString', dll_cdecl, ty_real, 2, ty_real, ty_real);

global.DLL_dGet_jeuPretAEtreLance=external_define(dllPath, 'dGet_jeuPretAEtreLance', dll_cdecl, ty_real, 0);
global.DLL_dGetProgressBarVariable=external_define(dllPath, 'dGetProgressBarVariable', dll_cdecl, ty_real, 1, ty_real);
global.DLL_dChangeInstallMode=external_define(dllPath, 'dChangeInstallMode', dll_cdecl, ty_real, 0);
global.DLL_dUninstallFull=external_define(dllPath, 'dUninstallFull', dll_cdecl, ty_real, 1, ty_real);
global.DLL_dAddRescueAddress=external_define(dllPath, 'dAddRescueAddress', dll_cdecl, ty_real, 2, ty_real, ty_real);


//dNePasSupprimerPourExporter();


