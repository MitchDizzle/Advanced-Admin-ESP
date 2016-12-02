#include <sdkhooks>
#include <CustomPlayerSkins>

#define PLUGIN_NAME    "CS:GO Give ESP"
#define PLUGIN_VERSION "1.1.0"

ConVar AdminESP_Color[2];
ConVar AdminESP_Default;

int colors[2][4];

bool isUsingESP[MAXPLAYERS+1];
bool glowsSetup = false;
int playersInESP = 0;
ConVar sv_force_transmit_players;

public Plugin myinfo = {
	name        = PLUGIN_NAME,
	author      = "Mitch",
	description = "Give players ESP/WH",
	version     = PLUGIN_VERSION,
	url         = "mtch.tech"
};

public OnPluginStart() {
	sv_force_transmit_players = FindConVar("sv_force_transmit_players");
	// Create plugin console variables on success
	CreateConVar("sm_csgo_giveesp_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AdminESP_Color[0] = CreateConVar("sm_csgo_giveesp_tcolor",  "192 160 96 64", "Determines R G B A glow colors for Terrorists team\nSet to \"0 0 0 0\" to disable",                      0);
	AdminESP_Color[1] = CreateConVar("sm_csgo_giveesp_ctcolor", "96 128 192 64", "Determines R G B A glow colors for Counter-Terrorists team\nFormat should be \"R G B A\" (with spaces)", 0);
	AdminESP_Default = CreateConVar("sm_csgo_giveesp_default", "0", "Set to 1 if admins should automatically be given ESP", 0);
	AutoExecConfig(true, "csgo_give_esp");
	AdminESP_Color[0].AddChangeHook(ConVarChange);
	AdminESP_Color[1].AddChangeHook(ConVarChange);
	retrieveColorValue();

	RegAdminCmd("sm_giveesp", Command_GiveESP, ADMFLAG_CHEATS);

	HookEvent("player_spawn", Event_PlayerSpawn);
	glowsSetup = false;
	playersInESP = 0;
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	retrieveColorValue();
}

public void retrieveColorValue() {
	char pieces[4][16];
	char color[32];
	for(int i=0;i<=1;i++) {
		AdminESP_Color[i].GetString(color, sizeof(color));
		if(ExplodeString(color, " ", pieces, sizeof(pieces), sizeof(pieces[])) == 4) {
			colors[i][0] = StringToInt(pieces[0]);
			colors[i][1] = StringToInt(pieces[1]);
			colors[i][2] = StringToInt(pieces[2]);
			colors[i][3] = StringToInt(pieces[3]);
		}
	}
}

public OnPluginEnd() {
	removeGlows();
}

public void OnMapStart() {
	resetPlayerVars(0);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if(AdminESP_Default.BoolValue) {
		int client = GetClientOfUserId(event.GetInt("userid"));
		if(client > 0 && client <= MaxClients && IsClientInGame(client) && CheckCommandAccess(client, "sm_giveesp", ADMFLAG_CHEATS, false)) {
			isUsingESP[client] = true;
		}
	}
	checkGlows();
	return Plugin_Continue;
}

public void toggleGlow(int client, bool value) {
	isUsingESP[client] = value;
	checkGlows();
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
	return Plugin_Handled;
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

public void removeGlows() {
	for(int client = 1; client <= MaxClients; client++) {
		if(glowsSetup && IsClientInGame(client)) {
			CPS_RemoveSkin(client, CPS_RENDER);
		}
	}
	glowsSetup = false;
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
		skin = CPS_SetSkin(client, model, CPS_RENDER);
		if(skin > MaxClients && SDKHookEx(skin, SDKHook_SetTransmit, OnSetTransmit)) {
			team = GetClientTeam(client)-2;
			if(team >= 0) {
				SetupGlow(skin, colors[team]);
			}
		}
	}
}

public Action OnSetTransmit(int entity, int client) {
	if(isUsingESP[client] && EntRefToEntIndex(CPS_GetSkin(client)) != entity) {
		return Plugin_Continue;
	}
	return Plugin_Handled;
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
	// Bots should be ignored (because their glow skin won't be removed after controlling)
	return (1 <= client <= MaxClients && IsClientInGame(client)) ? true : false;
}