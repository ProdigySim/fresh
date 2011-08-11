
#pragma semicolon 1

#include <sourcemod>

public Plugin:myinfo =
{
	name = "No Spitter During Tank",
	author = "Don",
	description = "Prevents the director from giving the infected team a spitter while the tank is alive",
	version = "1.3",
	url = "https://bitbucket.org/DonSanchez/random-sourcemod-stuff"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	decl String:game[12];
	GetGameFolderName(game, sizeof(game));
	if (StrEqual(game, "left4dead2"))	// Only load the plugin if the server is running Left 4 Dead 2.
	{
		return APLRes_Success;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports L4D2");
		return APLRes_Failure;
	}
}

static bool:IsTankAlive;

public OnPluginStart()
{
	HookEvent("tank_spawn", Event_tank_spawn_Callback);
	HookEvent("player_death", Event_player_death_Callback);
	HookEvent("round_end", Event_round_end_Callback);
}

public Event_tank_spawn_Callback(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!IsTankAlive)
	{
		SetConVarInt(FindConVar("z_versus_spitter_limit"), 0);
		IsTankAlive = true;
	}
}

public Event_player_death_Callback(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (IsTankAlive)
	{
		new String:victimname[8];
		GetEventString(event, "victimname", victimname, sizeof(victimname));
		if (StrEqual(victimname, "Tank"))
		{
			new killer = GetClientOfUserId(GetEventInt(event, "attacker")); 
			new String:killerName[MAX_NAME_LENGTH];
			GetClientName(killer, killerName, sizeof(killerName));
			new killed = GetClientOfUserId(GetEventInt(event, "userid"));
			new String:killedName[MAX_NAME_LENGTH];
			GetClientName(killed, killedName, sizeof(killedName));
			new String:weapon[8];
			GetEventString(event, "weapon", weapon, sizeof(weapon));
			if (!(StrEqual(killerName, killedName) && StrEqual(weapon, "world")))	/* Tank pass from first to second player triggers a player_death event,
												 * this check prevents it from counting as a tank death in our plugin.
												 */
			{
				SetConVarInt(FindConVar("z_versus_spitter_limit"), 1);
				IsTankAlive = false;
			}
		}
	}
}

public Event_round_end_Callback(Handle:event, const String:name[], bool:dontBroadcast)		// Needed for when the round ends without the tank dying.
{
	if (IsTankAlive)
	{
		SetConVarInt(FindConVar("z_versus_spitter_limit"), 1);
		IsTankAlive = false;
	}
}

public OnPluginEnd()
{
	if (IsTankAlive)
	{
		SetConVarInt(FindConVar("z_versus_spitter_limit"), 1);
	}
}
