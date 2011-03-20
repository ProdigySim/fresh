#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include <l4d2lib>

#define DEBUG	0


public Plugin:myinfo =
{
	name = "Freshogl Scoring System",
	author = "ProdigySim + CanadaRox",
	description = "Simplified Confogl scoring",
	version = "1.0",
	url = "http://prodigysim.com/l4d2/fresh/"
};

// Healthbonus variables (invariable) (feel free to change)
#define SM_fHBRatio 					2.0
#define SM_fSurvivalBonusRatio		0.0
#define SM_fHealPercent				0.8
#define SM_iPillPercent				50
#define	SM_iAdrenPercent			25

new const Float:SM_fTempMulti[3] = {	0.30625,
										0.17500,
										0.10000 
};


// Macro == micro
#define GetMapMaxScore() L4D_GetVersusMaxCompletionScore()
#define SM_IsPlayerIncap(%0) GetEntProp((%0), Prop_Send, "m_isIncapacitated")
#define IsSurvivor(%0) (IsClientInGame(%0) && GetClientTeam(%0) == 2)
#define GetSurvivorPermanentHealth(%0) GetEntProp((%0), Prop_Send, "m_iHealth")
#define GetSurvivorIncapCount(%0) GetEntProp((%0), Prop_Send, "m_currentReviveCount")

// This map's multiplier
new Float:SM_fMapMulti;

// Saves first round score
new SM_iFirstScore;

// Default Cvar Values
new Handle:SM_hSurvivalBonus;
new Handle:SM_hTieBreaker;

public OnPluginStart()
{
	SM_hSurvivalBonus = FindConVar("vs_survival_bonus");
	SM_hTieBreaker = FindConVar("vs_tiebreak_bonus");
	RegConsoleCmd("sm_health", SM_Cmd_Health);
	
	HookEvent("door_close", SM_DoorClose_Event);
	HookEvent("player_death", SM_PlayerDeath_Event);
	HookEvent("finale_vehicle_leaving", SM_FinaleVehicleLeaving_Event, EventHookMode_PostNoCopy);
	RegConsoleCmd("say", SM_Command_Say);
	RegConsoleCmd("say_team", SM_Command_Say);
	
	SetConVarInt(SM_hTieBreaker, 0);
}

public OnPluginEnd()
{
	ResetConVar(SM_hSurvivalBonus);
	ResetConVar(SM_hTieBreaker);
}

public OnMapStart()
{
	SM_fMapMulti = float(GetMapMaxScore()) / 400.0;
	
	SetConVarInt(SM_hTieBreaker, 0);
		
	SM_iFirstScore = 0;
}

public Action:SM_DoorClose_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetEventBool(event, "checkpoint"))
	{
		SetConVarInt(SM_hSurvivalBonus, SM_CalculateSurvivalBonus());
	}
}

public Action:SM_PlayerDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	// Can't just check for fakeclient
	if(client && GetClientTeam(client) == 2)
	{
		SetConVarInt(SM_hSurvivalBonus, SM_CalculateSurvivalBonus());
	}
}

public L4D2_OnRealRoundEnd(roundNumber)
{
	if(roundNumber==1) 
	{
		// First round just ended, save the current score.
		decl iAliveCount;
		SM_iFirstScore = RoundToFloor(SM_CalculateAvgHealth(iAliveCount) * SM_fMapMulti * SM_fHBRatio + 400 * SM_fMapMulti * SM_fSurvivalBonusRatio);
		
		// If the score is nonzero, trust the SurvivalBonus var.
		SM_iFirstScore = (SM_iFirstScore ? GetConVarInt(SM_hSurvivalBonus) *iAliveCount : 0);
		PrintToChatAll("[ScoreMod] Round 1 Bonus: %d", SM_iFirstScore);
	}
	else if (roundNumber==2)
	{
		// Second round has ended, print scores
		
		decl iAliveCount;
		new iScore = RoundToFloor(SM_CalculateAvgHealth(iAliveCount) * SM_fMapMulti * SM_fHBRatio + 400 * SM_fMapMulti * SM_fSurvivalBonusRatio);
		// If the score is nonzero, trust the SurvivalBonus var.
		iScore = iScore ? GetConVarInt(SM_hSurvivalBonus) * iAliveCount : 0; 
		PrintToChatAll("[ScoreMod] Round 1 Bonus: %d", SM_iFirstScore);
		PrintToChatAll("[ScoreMod] Round 2 Bonus: %d", iScore);
	}
}

public Action:SM_FinaleVehicleLeaving_Event(Handle:event, const String:name[], bool:dontBroadcast)
{	
	SetConVarInt(SM_hSurvivalBonus, SM_CalculateSurvivalBonus());
}

public Action:SM_Cmd_Health(client, args)
{	
	decl iAliveCount;
	new Float:fAvgHealth = SM_CalculateAvgHealth(iAliveCount);
	
	if (L4D2_GetCurrentRound() == 2) PrintToChat(client, "[ScoreMod] Round 1 Bonus: %d", SM_iFirstScore);
	
	if (client)	PrintToChat(client, "[ScoreMod] Average Health: %.02f", fAvgHealth);
	else PrintToServer("[ScoreMod] Average Health: %.02f", fAvgHealth);
	
	new iScore = RoundToFloor(fAvgHealth * SM_fMapMulti * SM_fHBRatio) * iAliveCount;
	
	#if DEBUG
		LogMessage("[ScoreMod] CalcScore: %d MapMulti: %.02f Multiplier %.02f", iScore, SM_fMapMulti, SM_fHBRatio);
	#endif

	if (client)
	{
		PrintToChat(client, "[ScoreMod] Health Bonus: %d", iScore );
		if (SM_fSurvivalBonusRatio != 0.0) PrintToChat(client, "[ScoreMod] Static Survival Bonus Per Survivor: %d", RoundToFloor(400 * SM_fMapMulti * SM_fSurvivalBonusRatio));
	}
	else
	{
		PrintToServer("[ScoreMod] Health Bonus: %d", iScore );
		if (SM_fSurvivalBonusRatio != 0.0) PrintToServer("[ScoreMod] Static Survival Bonus Per Survivor: %d", RoundToFloor(400 * SM_fMapMulti * SM_fSurvivalBonusRatio));
	}

	return Plugin_Handled;
}

stock SM_CalculateSurvivalBonus()
{
	return RoundToFloor(SM_CalculateAvgHealth() * SM_fMapMulti * SM_fHBRatio + 400 * SM_fMapMulti * SM_fSurvivalBonusRatio);
}

stock SM_CalculateScore()
{
	decl iAliveCount;
	new Float:fScore = SM_CalculateAvgHealth(iAliveCount);
	return RoundToFloor(fScore * SM_fMapMulti * SM_fHBRatio + 400 * SM_fMapMulti * SM_fSurvivalBonusRatio) * iAliveCount;
}

stock Float:SM_CalculateAvgHealth(&iAliveCount=0)
{
	new iTotalHealth;
	new iTotalTempHealth[3];
	
	new Float:fTotalAdjustedTempHealth;
	new bool:IsFinale = L4D_IsMissionFinalMap();
	// Temporary Storage Variables for inventory
	new iTemp;
	new iCurrHealth;
	new iCurrTemp;
	new iIncapCount;
	decl String:strTemp[50];
	
	new iSurvCount;
	iAliveCount =0;
		
	for (new index = 1; index < MaxClients; index++)
	{
		if (IsSurvivor(index))
		{
			iSurvCount++;
			if (IsPlayerAlive(index))
			{
			
				if (!SM_IsPlayerIncap(index))
				{
					// Get Main health stats
					iCurrHealth = GetSurvivorPermanentHealth(index);
					
					iCurrTemp = GetSurvivorTempHealth(index);
					
					iIncapCount = GetSurvivorIncapCount(index);
					
					// Adjust for kits
					iTemp = GetPlayerWeaponSlot(index, 3);
					if (iTemp > -1)
					{
						GetEdictClassname(iTemp, strTemp, sizeof(strTemp));
						if (StrEqual(strTemp, "weapon_first_aid_kit"))
						{
							iCurrHealth = RoundToFloor(iCurrHealth + ((100 - iCurrHealth) * SM_fHealPercent));
							iCurrTemp = 0;
							iIncapCount = 0;
						}
					}
					// Adjust for pills/adrenaline
					iTemp = GetPlayerWeaponSlot(index, 4);
					if (iTemp > -1)
					{
						GetEdictClassname(iTemp, strTemp, sizeof(strTemp));
						if (StrEqual(strTemp, "weapon_pain_pills")) iCurrTemp += SM_iPillPercent;
						else if (StrEqual(strTemp, "weapon_adrenaline")) iCurrTemp += SM_iAdrenPercent;
					}
					// Enforce max 100 total health points 
					if ((iCurrTemp + iCurrHealth) > 100) iCurrTemp = 100 - iCurrHealth;
					iAliveCount++;
					
					iTotalHealth += iCurrHealth;
					iTotalTempHealth[iIncapCount] += iCurrTemp;
				}
				else if (!IsFinale) iAliveCount++;
			}
		}
	}
	
	for (new i; i < 3; i++) fTotalAdjustedTempHealth += iTotalTempHealth[i] * SM_fTempMulti[i];
	
	// Total Score = Average Health points * numAlive
	
	// Average Health points = Total Health Points / Survivor Count
	// Total Health Points = Total Permanent Health + Total Adjusted Temp Health
	
	// return Average Health Points
	new Float:fAvgHealth  = (iTotalHealth + fTotalAdjustedTempHealth) / iSurvCount; 
	
	#if DEBUG
		LogMessage("[ScoreMod] TotalPerm: %d TotalAdjustedTemp: %.02f SurvCount: %d AliveCount: %d AvgHealth: %.02f", 
			iTotalHealth, fTotalAdjustedTempHealth, iSurvCount, iAliveCount, fAvgHealth);
	#endif
			
	return fAvgHealth;
}

public Action:SM_Command_Say(client, args)
{
	decl String:sMessage[MAX_NAME_LENGTH];
	GetCmdArg(1, sMessage, sizeof(sMessage));
	
	if (StrEqual(sMessage, "!health")) return Plugin_Handled;
	
	return Plugin_Continue;
}

stock GetSurvivorTempHealth(client)
{
	new temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return (temphp > 0 ? temphp : 0);
}


