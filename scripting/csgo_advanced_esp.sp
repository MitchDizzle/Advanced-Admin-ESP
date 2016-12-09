#include <sdkhooks>
#include <CustomPlayerSkins>

#define PLUGIN_NAME    "Advanced Admin ESP"
#define PLUGIN_VERSION "1.2.1"

ConVar cColor[2];
ConVar cDefault;
ConVar cLifeState;
ConVar cNotify;

int colors[2][4];

bool isUsingESP[MAXPLAYERS+1];
int playersInESP = 0;
ConVar sv_force_transmit_players;

public Plugin myinfo = {
	name        = PLUGIN_NAME,
	author      = "Mitch",
	description = "Allow admins to use a server side ESP/WH",
	version     = PLUGIN_VERSION,
	url         = "mtch.tech"
};

public OnPluginStart() {
	sv_force_transmit_players = FindConVar("sv_force_transmit_players");
	// Create plugin console variables on success
	CreateConVar("sm_advanced_esp_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);
	cColor[0] = CreateConVar("sm_advanced_esp_tcolor",  "192 160 96 64", "Determines R G B A glow colors for Terrorists team\nSet to \"0 0 0 0\" to disable",                      0);
	cColor[1] = CreateConVar("sm_advanced_esp_ctcolor", "96 128 192 64", "Determines R G B A glow colors for Counter-Terrorists team\nFormat should be \"R G B A\" (with spaces)", 0);
	cDefault = CreateConVar("sm_advanced_esp_default", "0", "Set to 1 if admins should automatically be given ESP", 0);
	cLifeState = CreateConVar("sm_advanced_esp_lifestate", "0", "Set to 1 if admins should only see esp when dead, 2 to only see esp while alive, 0 dead or alive.", 0);
	cNotify = CreateConVar("sm_advanced_esp_notify", "0", "Set to 1 if giving and setting esp should notify the rest of the server.", 0);
	AutoExecConfig(true, "csgo_advanced_esp");
	cColor[0].AddChangeHook(ConVarChange);
	cColor[1].AddChangeHook(ConVarChange);
	cLifeState.AddChangeHook(ConVarChange);
	for(int i = 0; i <= 1; i++) {
		retrieveColorValue(i);
	}

	LoadTranslations("common.phrases");
	LoadTranslations("esp.phrases");

	RegAdminCmd("sm_giveesp", Command_GiveESP, ADMFLAG_CHEATS); //Give other players
	RegAdminCmd("sm_esp", Command_ESP, ADMFLAG_CHEATS);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	playersInESP = 0;
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	for(int i = 0; i <= 1; i++) {
		if(convar == cColor[i]) {
			retrieveColorValue(i);
		}
	}
	checkGlows();
}

public void retrieveColorValue(int index) {
	char pieces[4][16];
	char color[64];
	cColor[index].GetString(color, sizeof(color));
	if(ExplodeString(color, " ", pieces, sizeof(pieces), sizeof(pieces[])) == 4) {
		for(int j = 0; j <= 3; j++) {
			colors[index][j] = StringToInt(pieces[j]);
		}
	}
}

public Action Command_GiveESP(client, args) {
	if(args < 1) {
		ReplyToCommand(client, "[SM] sm_giveesp <player/#userid> [0/1]");
		return Plugin_Handled;
	}
	char arg1[32];
	char targetName[MAX_TARGET_LENGTH+8];
	int clientList[MAXPLAYERS];
	int clientCount;
	bool multiLang;
	GetCmdArg(1, arg1, sizeof(arg1));
	if ((clientCount = ProcessTargetString(arg1,client,clientList,MAXPLAYERS,COMMAND_FILTER_CONNECTED,targetName,sizeof(targetName),multiLang)) <= 0) {
		ReplyToTargetError(client, clientCount);
		return Plugin_Handled;
	}
	bool value = false;
	if(args > 1) {
		GetCmdArg(2, arg1, sizeof(arg1));
		value = (StringToInt(arg1) != 0);
	}
	for(int i = 0; i < clientCount; i++) {
		if(!IsClientInGame(clientList[i])) continue;
		if(args > 1) {
			toggleGlow(clientList[i], value);
		} else {
			toggleGlow(clientList[i], !isUsingESP[clientList[i]]);
		}
	}
	notifyServer(client, targetName, (args > 1) ? (value ? 1 : 0) : 2);
	return Plugin_Handled;
}

public Action Command_ESP(client, args) {
	if(!client || !IsClientInGame(client)) {
		return Plugin_Handled;
	}
	bool value = false;
	if(args > 0) {
		char arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));
		toggleGlow(client, (StringToInt(arg1) != 0));
	} else {
		toggleGlow(client, !isUsingESP[client]);
	}
	char targetName[64];
	GetClientName(client, targetName, sizeof(targetName));
	notifyServer(client, targetName, (args > 1) ? (value ? 1 : 0) : 2);
	return Plugin_Handled;
}

public void notifyServer(int client, char[] targetName, int status) {
	if(cNotify.BoolValue) {
		switch(status) {
			case 0:  ShowActivity(client, "%t", "ESP Off", targetName);
			case 1:  ShowActivity(client, "%t", "ESP On", targetName);
			default: ShowActivity(client, "%t", "ESP Toggle", targetName);
		}
	}
}

public OnPluginEnd() {
	destoryGlows();
}

public void OnMapStart() {
	resetPlayerVars(0);
}

public void OnClientDisconnect(int client) {
	resetPlayerVars(client);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if(cDefault.BoolValue) {
		int client = GetClientOfUserId(event.GetInt("userid"));
		if(client > 0 && client <= MaxClients && IsClientInGame(client) && CheckCommandAccess(client, "sm_esp", ADMFLAG_CHEATS, false)) {
			isUsingESP[client] = true;
		}
	}
	checkGlows();
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	checkGlows();
}

public void toggleGlow(int client, bool value) {
	isUsingESP[client] = value;
	checkGlows();
}

public void resetPlayerVars(int client) {
	if(client == 0) {
		for(int i = 1; i <= MaxClients; i++) {
			resetPlayerVars(i);
		}
		return;
	}
	if(isUsingESP[client]) {
		isUsingESP[client] = false;
		playersInESP--;
	}
}

public void checkGlows() {
	//Check to see if some one has a glow enabled.
	playersInESP = 0;
	for(int client = 1; client <= MaxClients; client++) {
		if(isUsingESP[client]) {
			playersInESP++;
		}
	}
	//Force transmit makes sure that the players can see the glow through wall correctly.
	//This is usually for alive players for the anti-wallhack made by valve.
	destoryGlows();
	if(playersInESP > 0) {
		sv_force_transmit_players.SetString("1", true, false);
		createGlows();
	} else {
		sv_force_transmit_players.SetString("0", true, false);
	}
}

public void destoryGlows() {
	for(int client = 1; client <= MaxClients; client++) {
		if(IsClientInGame(client)) {
			CPS_RemoveSkin(client);
		}
	}
}

public void createGlows() {
	char model[PLATFORM_MAX_PATH];
	int skin = -1;
	int team = 0;
	//Loop and setup a glow on alive players.
	for(int client = 1; client <= MaxClients; client++) {
		//Ignore dead and bots
		if(!IsClientInGame(client) || !IsPlayerAlive(client)) {// || IsFakeClient(client)) {
			continue;
		}
		//Create Skin
		GetClientModel(client, model, sizeof(model));
		skin = CPS_SetSkin(client, model, CPS_RENDER|CPS_TRANSMIT);
		if(skin > MaxClients && SDKHookEx(skin, SDKHook_SetTransmit, OnSetTransmit)) {
			team = GetClientTeam(client)-2;
			if(team >= 0) {
				SetupGlow(skin, colors[team]);
			}
		}
	}
}

public Action OnSetTransmit(int entity, int client) {
	if(isUsingESP[client] && EntRefToEntIndex(CPS_GetSkin(client)) != entity && getLifeState(client)) {
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public bool getLifeState(int client) {
	switch(cLifeState.IntValue) {
		case 1: return !IsPlayerAlive(client); //Only see glows when player is dead.
		case 2: return IsPlayerAlive(client); //Only see glows when player is alive.
		default: return true;
	}
	return false;
}

public void SetupGlow(int entity, int color[4]) {
	static offset;
	// Get sendprop offset for prop_dynamic_override
	if (!offset && (offset = GetEntSendPropOffs(entity, "m_clrGlow")) == -1) {
		LogError("Unable to find property offset: \"m_clrGlow\"!");
		return;
	}

	// Enable glow for custom skin
	SetEntProp(entity, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(entity, Prop_Send, "m_nGlowStyle", 0);
	SetEntPropFloat(entity, Prop_Send, "m_flGlowMaxDist", 10000.0);

	// So now setup given glow colors for the skin
	for(int i=0;i<4;i++) {
		SetEntData(entity, offset + i, color[i], _, true); 
	}
}

public bool IsValidClient(int client) {
	return (1 <= client && client <= MaxClients && IsClientInGame(client));
}