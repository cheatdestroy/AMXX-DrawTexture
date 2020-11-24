#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <xs>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#pragma semicolon 1

#define PLUG_NAME "Draw Texture"
#define PLUG_VERSION "1.0.6"
#define PLUG_AUTHOR "CheaT"

#define FLAG_ACCESS ADMIN_BAN

#define MIN_POINTS 2
#define MAX_POINTS 6
#define MAX_RECT_POINTS 5
#define MAX_STACKS 33

#define TASK_DRAW 692307
#define TASK_CHECK 692308

enum _:Files {
	fRect,
	fPoints
};

enum _:EntityInfo {
	entMODEL[32],
	entNAME[32],
	entID,
	entDIR,
	entCOLOR,
	Float:entSPEED,
	bool:entDELETE,
	entSTACK
};

enum _:OldEntityInfo {
	oldSOLID,
	Float:oldSPEED
};

enum _:PointsInfo {
	pntPOINT,
	pntCOLOR,
	pntSTACK
};

enum _:RectangleDirection {
	DirNONE,
	DirX1,
	DirX2,
	DirY1,
	DirY2,
	DirZ1,
	DirZ2
};

new const g_szDirType[RectangleDirection][64] = {
	"Не отрисовывать",
	"X",
	"X2",
	"Y",
	"Y2",
	"Z",
	"Z2"
};

enum _:CoordsType {
	Aim,
	Player
};

new const g_szCoordsType[CoordsType][64] = {
	"Координаты прицела",
	"Координаты игрока"
};

enum _:Colors {
	ColorRed,
	ColorYellow,
	ColorWhite,
	ColorCyan,
	ColorBlue,
	ColorGreen,
	ColorPink,
	ColorPurple
};

new const g_szColors[Colors][32] = {
	"Красный",
	"Жёлтый",
	"Белый",
	"Голубой",
	"Синий",
	"Зелёный",
	"Розовый",
	"Фиолетовый",
};

new const g_iColors[Colors][3] = {
	{255, 0, 0},
	{255, 255, 0},
	{255, 255, 255},
	{0, 255, 255},
	{0, 0, 255},
	{0, 255, 0},
	{255, 0, 255},
	{150, 0, 255},
};

new const DT_FILES[2][16] = {
	"rect.ini",
	"points.ini"
};

new const DT_FILES_TEMP[2][16] = {
	"rect_t.ini",
	"points_t.ini"
};

new const g_szEntityAllowed[2][32] = {
	"trigger_push",
	"trigger_teleport"
};

new g_szDir[256];
new g_iForwardSpawn;

new g_iStack = 0;
new g_iPointStack = 0;

new Float:g_iPoints[MAX_STACKS][MAX_POINTS][3];
new Float:g_iPlayerPoints[33][MAX_POINTS][3];
new Float:g_iEntityRect[MAX_STACKS][MAX_RECT_POINTS][3];

new Array:g_aEntity, Array:g_aOldEntity, Array:g_aPoints;

new g_iSprite;
new g_iSelectedEnt[33][EntityInfo], g_iSelectedPoint[33][PointsInfo], g_iCoordsType[33], g_iPlayerPage[33];

public plugin_init()
{
	register_plugin(PLUG_NAME, PLUG_VERSION, PLUG_AUTHOR);

	register_clcmd("say /drawt", "DrawMenu");
	register_clcmd("drawt", "DrawMenu");
	register_clcmd("ent_speed", "EntSpeed");

	set_task(2.0, "DrawTask", TASK_DRAW, _, _, "ab");

	register_menucmd(register_menuid("DrawMenu"), (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9), "Handle_DrawMenu");
	register_menucmd(register_menuid("EntityMenu"), (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9), "Handle_EntityMenu");
	register_menucmd(register_menuid("PointsMenu"), (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9), "Handle_PointsMenu");
	register_menucmd(register_menuid("EntityOptions"), (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9), "Handle_EntityOptions");
	register_menucmd(register_menuid("PointsOptions"), (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9), "Handle_PointsOptions");

	if(g_iForwardSpawn)
	{
		unregister_forward(FM_Spawn, g_iForwardSpawn);
	}
}

public plugin_precache()
{
	g_iSprite = precache_model("sprites/laserbeam.spr");

	g_aEntity = ArrayCreate(EntityInfo);
	g_aOldEntity = ArrayCreate(OldEntityInfo);
	g_aPoints = ArrayCreate(PointsInfo);

	new mapName[128], cfgDir[64], filesIni[64];
	get_mapname(mapName, charsmax(mapName));
	get_configsdir(cfgDir, sizeof(cfgDir));
	formatex(g_szDir, charsmax(g_szDir), "%s/drawt/", cfgDir);
	if(!dir_exists(g_szDir))
	{
		mkdir(g_szDir);
	}

	formatex(g_szDir, charsmax(g_szDir), "%s/%s/", g_szDir, mapName);
	if(!dir_exists(g_szDir))
	{
		mkdir(g_szDir);
	}

	for(new i = 0; i < sizeof(DT_FILES); i++)
	{
		formatex(filesIni, 63, "%s/%s", g_szDir, DT_FILES[i]);  
		if(!file_exists(filesIni))
		{
			server_print("[%s] Не найден файл %s.", PLUG_NAME, DT_FILES[i]);
		}
	}

	Load(fRect);

	g_iForwardSpawn = register_forward(FM_Spawn, "FwdSpawn", true);

	Load(fPoints);
}

public plugin_end()
{ 
    ArrayDestroy(g_aEntity);
    ArrayDestroy(g_aOldEntity);
    ArrayDestroy(g_aPoints);
}

public client_putinserver(id)
{
	g_iPlayerPage[id] = 0;
	g_iSelectedPoint[id][pntPOINT] = 0;
	g_iSelectedPoint[id][pntCOLOR] = 0;
	g_iSelectedPoint[id][pntSTACK] = -1;
	g_iSelectedEnt[id][entMODEL] = "^0";
	g_iSelectedEnt[id][entNAME] = "^0";
	g_iSelectedEnt[id][entID] = -1;
	g_iSelectedEnt[id][entDIR] = DirNONE;
	g_iSelectedEnt[id][entCOLOR] = 0;
	g_iSelectedEnt[id][entSPEED] = 0.0;
	g_iSelectedEnt[id][entDELETE] = false;
	g_iSelectedEnt[id][entSTACK] = -1;
}

public EntSpeed(id)
{
	if(!(get_user_flags(id) & FLAG_ACCESS))
	{
		return PLUGIN_HANDLED;
	}

	new args[256];
	read_args(args, charsmax(args));
	remove_quotes(args);
	if(is_str_num(args))
	{
		if(pev_valid(g_iSelectedEnt[id][entID]) && !g_iSelectedEnt[id][entDELETE] && g_iSelectedEnt[id][entID] != -1)
		{
			new Float:fSpeed = str_to_float(args);
			set_pev(g_iSelectedEnt[id][entID], pev_speed, fSpeed);

			g_iSelectedEnt[id][entSPEED] = fSpeed;
			ArraySetCell(g_aEntity, GetIndex(g_iSelectedEnt[id][entMODEL]), fSpeed, entSPEED);

			client_print_color(id, print_team_blue, "^4[%s] ^1Вы ^3установили скорость ^1(^4%0.1f^1) ^1выбранному объекту!", PLUG_NAME, str_to_float(args));
			return EntityOptions(id);
		}
	}

	client_print_color(id, print_team_red, "^4[%s] ^1Введите ^3целое число!", PLUG_NAME);
	return PLUGIN_HANDLED;
}

public DelayCheck(iEntityID)
{
	iEntityID -= TASK_CHECK;

	if(!pev_valid(iEntityID))
	{
		return PLUGIN_CONTINUE;
	}

	new szClass[32], szModel[32], bool:isAllowed = false;
	pev(iEntityID, pev_classname, szClass, charsmax(szClass));
	pev(iEntityID, pev_model, szModel, charsmax(szModel));

	for(new i = 0; i < sizeof(g_szEntityAllowed); i++)
	{
		if(equal(szClass, g_szEntityAllowed[i]))
		{
			isAllowed = true;
		}
	}

	if(!isAllowed)
	{
		return PLUGIN_CONTINUE;
	}

	new iSize = ArraySize(g_aEntity);
	new aEntity[EntityInfo];

	//Create old entity properties, to removel new changes
	new aOldEntity[OldEntityInfo];
	aOldEntity[oldSOLID] = pev(iEntityID, pev_solid);
	pev(iEntityID, pev_speed, aOldEntity[oldSPEED]);

	ArrayPushArray(g_aOldEntity, aOldEntity);

	//Checking entity in array
	for(new i = 0; i < iSize; i++)
	{
		new index = GetIndex(szModel);
		if(index != -1)
		{
			ArrayGetArray(g_aEntity, index, aEntity);
			if(equal(szClass, aEntity[entNAME]) && equal(szModel, aEntity[entMODEL]))
			{
				aEntity[entID] = iEntityID;
				ArraySetCell(g_aEntity, index, aEntity[entID], entID);
				aEntity[entSTACK] = -1;
				set_pev(iEntityID, pev_speed, aEntity[entSPEED]);
				if(aEntity[entDELETE])
				{
					set_pev(iEntityID, pev_solid, SOLID_NOT);
					ArraySetCell(g_aEntity, index, DirNONE, entDIR);
				}
				else if(aEntity[entDIR] != DirNONE && g_iStack < MAX_STACKS)
				{
					aEntity[entSTACK] = DrawRectangle(aEntity[entDIR], aEntity[entID], -1);
				}
				ArraySetCell(g_aEntity, index, aEntity[entSTACK], entSTACK);
				return PLUGIN_CONTINUE;
			}
		}
	}

	//If entity is new (not in array), add new entity to array
	new Float:fMoveDir[3];
	pev(iEntityID, pev_movedir, fMoveDir);

	aEntity[entMODEL] = szModel;
	aEntity[entNAME] = szClass;
	aEntity[entID] = iEntityID;
	aEntity[entCOLOR] = ColorGreen;
	aEntity[entSPEED] = aOldEntity[oldSPEED];
	aEntity[entDELETE] = false;
	aEntity[entSTACK] = -1;
	if(g_iStack < MAX_STACKS && !equal(g_szEntityAllowed[1], szClass))
	{
		if(fMoveDir[0] == -1)
		{
			aEntity[entSTACK] = DrawRectangle(aEntity[entDIR] = DirX1, iEntityID, -1);
		}
		else if(fMoveDir[0] == 1)
		{
			aEntity[entSTACK] = DrawRectangle(aEntity[entDIR] = DirX2, iEntityID, -1);
		}
		else if(fMoveDir[1] == -1)
		{
			aEntity[entSTACK] = DrawRectangle(aEntity[entDIR] = DirY1, iEntityID, -1);
		}
		else if(fMoveDir[1] == 1)
		{
			aEntity[entSTACK] = DrawRectangle(aEntity[entDIR] = DirY2, iEntityID, -1);
		}
		else if(fMoveDir[2] == -1)
		{
			aEntity[entSTACK] = DrawRectangle(aEntity[entDIR] = DirZ1, iEntityID, -1);
		}
		else
		{
			aEntity[entSTACK] = DrawRectangle(aEntity[entDIR] = DirZ2, iEntityID, -1);
		}
	}
	else
	{
		aEntity[entDIR] = DirNONE;
	}

	Save(fRect, ArrayPushArray(g_aEntity, aEntity));
	return PLUGIN_CONTINUE;
}

public FwdSpawn(iEntity)
{
	if(pev_valid(iEntity))
	{
		set_task(0.1, "DelayCheck", iEntity + TASK_CHECK);
		return FMRES_HANDLED;
	}

	return FMRES_IGNORED;
}

public DrawMenu(id)
{
	if(!(get_user_flags(id) & FLAG_ACCESS))
	{
		return PLUGIN_HANDLED;
	}

	new Float:origin[3]; pev(id, pev_origin, origin);
	new szMenu[512], iKeys = (1<<0|1<<9), iLen = formatex(szMenu, charsmax(szMenu), "\yМеню отрисовки^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r1\y] Создать набор точек^n");
	if(ArraySize(g_aPoints) > 0)
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r2\y] Список набора точек^n");
		iKeys |= (1<<1);
	}
	else iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r2\y] \dСписок набора точек (0)^n");
	if(ArraySize(g_aEntity) > 0)
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r3\y] Список объектов^n^n");
		iKeys |= (1<<2);
	}
	else iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r3\y] \dСписок объектов (0)^n^n");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r0\y] \wВыход");
	return show_menu(id, iKeys, szMenu, -1, "DrawMenu");
}

public Handle_DrawMenu(id, iKey)
{
	switch(iKey)
	{
		case 0:
		{
			for(new i = 0; i < MAX_POINTS; i++)
			{
				for(new j = 0; j < 3; j++)
				{
					g_iPlayerPoints[id][i][j] = 0.0;
				}
			}
			g_iSelectedPoint[id][pntPOINT] = 0;
			g_iSelectedPoint[id][pntSTACK] = -1;
			return PointsOptions(id);
		}
		case 1:
		{
			if(ArraySize(g_aPoints) > 0)
			{
				return PointsMenu(id, g_iPlayerPage[id] = 0);
			}
		}
		case 2:
		{
			if(ArraySize(g_aEntity) > 0)
			{
				return EntityMenu(id, g_iPlayerPage[id] = 0);
			}
		}
		case 9:
		{
			return PLUGIN_HANDLED;
		}
	}
	return DrawMenu(id);
}


public PointsOptions(id)
{
	new Float:fOrigin[3]; pev(id, pev_origin, fOrigin);
	new szMenu[512], iKeys = (1<<2|1<<3|1<<5|1<<6|1<<7|1<<9), iLen = formatex(szMenu, charsmax(szMenu), "\yМеню точек^n\dX [%0.3f] | Y [%0.3f] | Z [%0.3f]^n^n", fOrigin[0], fOrigin[1], fOrigin[2]);
	if(g_iSelectedPoint[id][pntPOINT] < MAX_POINTS)
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r1\y] \wПоставить точку \d[\r%d\d]^n", g_iSelectedPoint[id][pntPOINT]);
		iKeys |= (1<<0);
	}
	else iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r1\y] \dМаксимум точек!^n");
	if(g_iSelectedPoint[id][pntPOINT])
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r2\y] \wУдалить последнюю точку^n");
		iKeys |= (1<<1);
	}
	else iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r2\y] \dУдалить последнюю точку^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r3\y] \wТип координат: %s^n", g_szCoordsType[g_iCoordsType[id]]);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r4\y] \wЦвет \r[%s]^n", g_szColors[g_iSelectedPoint[id][pntCOLOR]]);
	if(g_iSelectedPoint[id][pntPOINT] == 2)
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r5\y] \yПостроить прямоугольник^n");
		iKeys |= (1<<4);
	}
	else iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r5\y] \dПостроить прямоугольник^n");
	if(g_iSelectedPoint[id][pntPOINT] > 1)
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y[\r6\y] \wСохранить^n^n");
	}
	else iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y[\r6\y] \dСохранить^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r7\y] \wОбновить координаты^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r8\y] \wТелепорт^n^n");
	if(g_iSelectedPoint[id][pntSTACK] != -1)
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r9\y] \rУдалить^n^n");
		iKeys |= (1<<8);
	}
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r0\y] \wВыход");
	return show_menu(id, iKeys, szMenu, -1, "PointsOptions");
}

public Handle_PointsOptions(id, iKey)
{
	switch(iKey)
	{
		case 0:
		{
			if(g_iSelectedPoint[id][pntPOINT] < MAX_POINTS)
			{
				if(g_iCoordsType[id] == Aim && !is_aiming_at_sky(id))
				{
					fm_get_aim_origin(id, g_iPlayerPoints[id][g_iSelectedPoint[id][pntPOINT]]);
				}
				else if(g_iCoordsType[id] == Player)
				{
					pev(id, pev_origin, g_iPlayerPoints[id][g_iSelectedPoint[id][pntPOINT]]);
				}

				++g_iSelectedPoint[id][pntPOINT];

				client_print_color(id, print_team_blue, "^4[%s] ^1Вы ^3успешно ^1поставили точку ^4#%d^1!", PLUG_NAME, g_iSelectedPoint[id][pntPOINT]);
			}
		}
		case 1:
		{
			--g_iSelectedPoint[id][pntPOINT];
			for(new i = 0; i < 3; i++)
			{
				g_iPlayerPoints[id][g_iSelectedPoint[id][pntPOINT]][i] = 0.0;
			}
			client_print_color(id, print_team_blue, "^4[%s] ^1Вы ^3удалили ^1последнюю поставленную точку!", PLUG_NAME);
		}
		case 2:
		{
			g_iCoordsType[id] = g_iCoordsType[id] == Player ? Aim : Player;
		}
		case 3:
		{
			if(++g_iSelectedPoint[id][pntCOLOR] >= Colors)
			{
				g_iSelectedPoint[id][pntCOLOR] = 0;
			}
		}
		case 4:
		{
			if(g_iSelectedPoint[id][pntPOINT] == 2)
			{
				new Float:maxX, Float:minX, Float:maxY, Float:minY, Float:maxZ, Float:minZ;

				minZ = floatmin(g_iPlayerPoints[id][0][2], g_iPlayerPoints[id][1][2]);
				maxZ = floatmax(g_iPlayerPoints[id][0][2], g_iPlayerPoints[id][1][2]);

				new Float:diffX, Float:diffY;
				diffX = floatabs(floatabs(g_iPlayerPoints[id][0][0]) - floatabs(g_iPlayerPoints[id][1][0]));
				diffY = floatabs(floatabs(g_iPlayerPoints[id][0][1]) - floatabs(g_iPlayerPoints[id][1][1]));
				if(diffX > diffY)
				{
					minX = floatmin(g_iPlayerPoints[id][0][0], g_iPlayerPoints[id][1][0]);
					maxX = floatmax(g_iPlayerPoints[id][0][0], g_iPlayerPoints[id][1][0]);
					maxY = minY = g_iPlayerPoints[id][0][1];
				}
				else
				{
					minY = floatmin(g_iPlayerPoints[id][0][1], g_iPlayerPoints[id][1][1]);
					maxY = floatmax(g_iPlayerPoints[id][0][1], g_iPlayerPoints[id][1][1]);
					maxX = minX = g_iPlayerPoints[id][0][0];
				}

				g_iPlayerPoints[id][0][0] = minX;
				g_iPlayerPoints[id][0][1] = minY;
				g_iPlayerPoints[id][0][2] = minZ;

				g_iPlayerPoints[id][1][0] = maxX;
				g_iPlayerPoints[id][1][1] = maxY;
				g_iPlayerPoints[id][1][2] = minZ;

				g_iPlayerPoints[id][2][0] = maxX;
				g_iPlayerPoints[id][2][1] = maxY;
				g_iPlayerPoints[id][2][2] = maxZ;

				g_iPlayerPoints[id][3][0] = minX;
				g_iPlayerPoints[id][3][1] = minY;
				g_iPlayerPoints[id][3][2] = maxZ;

				g_iPlayerPoints[id][4][0] = minX;
				g_iPlayerPoints[id][4][1] = minY;
				g_iPlayerPoints[id][4][2] = minZ;

				g_iSelectedPoint[id][pntPOINT] = 5;
			}
		}
		case 5:
		{
			if(g_iSelectedPoint[id][pntSTACK] == -1)
			{
				for(new i = 0; i < MAX_POINTS; i++)
				{
					for(new j = 0; j < 3; j++)
					{
						g_iPoints[g_iPointStack][i][j] = g_iPlayerPoints[id][i][j];
					}
				}
				g_iSelectedPoint[id][pntSTACK] = g_iPointStack;

				ArrayPushArray(g_aPoints, g_iSelectedPoint[id]);

				Save(fPoints, g_iPointStack);
				++g_iPointStack;
			}
			else
			{
				for(new i = 0; i < MAX_POINTS; i++)
				{
					for(new j = 0; j < 3; j++)
					{
						g_iPoints[g_iSelectedPoint[id][pntSTACK]][i][j] = g_iPlayerPoints[id][i][j];
					}
				}

				ArraySetCell(g_aPoints, g_iSelectedPoint[id][pntSTACK], g_iSelectedPoint[id][pntPOINT], pntPOINT);
				ArraySetCell(g_aPoints, g_iSelectedPoint[id][pntSTACK], g_iSelectedPoint[id][pntCOLOR], pntCOLOR);

				Save(fPoints, g_iSelectedPoint[id][pntSTACK], 1);
			}

			return PointsMenu(id, g_iPlayerPage[id] = 0);
		}
		case 6:
		{
			new Float:fOrigin[3]; pev(id, pev_origin, fOrigin);
			client_print(id, print_console, "%f %f %f", fOrigin[0], fOrigin[1], fOrigin[2]);
		}
		case 7:
		{
			if(!is_empty(g_iPlayerPoints[id][0]))
			{
				set_pev(id, pev_origin, g_iPlayerPoints[id][0]);
			}
		}
		case 8:
		{
			if(g_iSelectedPoint[id][pntSTACK] != -1)
			{
				Save(fPoints, g_iSelectedPoint[id][pntSTACK], 2);

				for(new i = g_iSelectedPoint[id][pntSTACK]; i < g_iPointStack; i++)
				{
					for(new j = 0; j < MAX_POINTS; j ++)
					{
						for(new k = 0; k < 3; k++)
						{
							g_iPoints[i][j][k] = g_iPoints[i+1][j][k];
						}
					}
				}

				--g_iPointStack;
				ArrayDeleteItem(g_aPoints, g_iSelectedPoint[id][pntSTACK]);

				return DrawMenu(id);
			}
		}
		case 9:
		{
			return PLUGIN_HANDLED;
		}
	}
	return PointsOptions(id);
}

public PointsMenu(id, iPage)
{
	if(iPage < 0)
	{
		return PLUGIN_HANDLED;
	}

	new szMenu[512], iKeys = (1<<9), iLen = formatex(szMenu, charsmax(szMenu), "\yМеню точек^n^n");

	new iStart, iEnd, i;
	i = min(iPage * 7, ArraySize(g_aPoints));
	iStart = i - (i % 7);

	iEnd = min(iStart + 7, ArraySize(g_aPoints));
	iPage = iStart / 7;

	g_iPlayerPage[id] = iPage;
	
	new iItem, aPoints[PointsInfo];
	for(new i = iStart; i < iEnd; i++)
	{
		ArraySetCell(g_aPoints, i, i, pntSTACK);
		ArrayGetArray(g_aPoints, i, aPoints);
		if(aPoints[pntSTACK] != -1)
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r%d\y] \wНабор точек \r№%d^n", iItem + 1, i + 1);
			iKeys |= (1<<iItem);
			iItem++;
		}
	}

	if(iEnd < ArraySize(g_aPoints))
	{
		iKeys |= (1<<7);
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y[\r8\y] \wДалее");
	}
	
	if(iPage)
	{
		iKeys |= (1<<8);
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y[\r9\y] \wНазад");
	}

	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y[\r0\y] \wВыход");

	return show_menu(id, iKeys, szMenu, -1, "PointsMenu");
}

public Handle_PointsMenu(id, iKey)
{
	switch(iKey)
	{
		case 7:
		{
			return PointsMenu(id, ++g_iPlayerPage[id]);
		}
		case 8:
		{
			return PointsMenu(id, --g_iPlayerPage[id]);
		}
		case 9:
		{
			return PLUGIN_HANDLED;
		}
		default:
		{
			ArrayGetArray(g_aPoints, (g_iPlayerPage[id] * 7) + iKey, g_iSelectedPoint[id]);
			for(new i = 0; i < g_iSelectedPoint[id][pntPOINT]; i++)
			{
				for(new j = 0; j < 3; j++)
				{
					g_iPlayerPoints[id][i][j] = g_iPoints[g_iSelectedPoint[id][pntSTACK]][i][j];
				}
			}
			return PointsOptions(id);
		}
	}
	return PLUGIN_HANDLED;
}

public EntityMenu(id, iPage)
{
	if(iPage < 0)
	{
		return PLUGIN_HANDLED;
	}

	new szMenu[512], iKeys = (1<<9), iLen = formatex(szMenu, charsmax(szMenu), "\yМеню объектов^n^n");

	new iStart, iEnd, i;
	i = min(iPage * 7, ArraySize(g_aEntity));
	iStart = i - (i % 7);

	iEnd = min(iStart + 7, ArraySize(g_aEntity));
	iPage = iStart / 7;

	g_iPlayerPage[id] = iPage;
	
	new iItem, aEntity[EntityInfo];
	for(new i = iStart; i < iEnd; i++)
	{
		ArrayGetArray(g_aEntity, i, aEntity);
		if(!aEntity[entDELETE] && pev_valid(aEntity[entID]))
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r%d\y] \w%s \r№%d^n", iItem + 1, aEntity[entNAME], aEntity[entID]);
			iKeys |= (1<<iItem);
		}
		else if(aEntity[entDELETE] && pev_valid(aEntity[entID]))
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r%d\y] \dУдалён \r№%d^n", iItem + 1, aEntity[entID]);
			iKeys |= (1<<iItem);
		}

		iItem++;
	}

	if(iEnd < ArraySize(g_aEntity))
	{
		iKeys |= (1<<7);
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y[\r8\y] \wДалее");
	}
	
	if(iPage)
	{
		iKeys |= (1<<8);
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y[\r9\y] \wНазад");
	}

	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y[\r0\y] \wВыход");

	return show_menu(id, iKeys, szMenu, -1, "EntityMenu");
}

public Handle_EntityMenu(id, iKey)
{
	switch(iKey)
	{
		case 7:
		{
			return EntityMenu(id, ++g_iPlayerPage[id]);
		}
		case 8:
		{
			return EntityMenu(id, --g_iPlayerPage[id]);
		}
		case 9:
		{
			return PLUGIN_HANDLED;
		}
		default:
		{
			ArrayGetArray(g_aEntity, (g_iPlayerPage[id] * 7) + iKey, g_iSelectedEnt[id]);
			return EntityOptions(id);
		}
	}
	return PLUGIN_HANDLED;
}

public EntityOptions(id)
{
	new index = GetIndex(g_iSelectedEnt[id][entMODEL]);

	if(index == -1)
	{
		return EntityMenu(id, g_iPlayerPage[id] = 0);
	}

	//Update entity, when user on click any items...
	ArrayGetArray(g_aEntity, index, g_iSelectedEnt[id]);

	new szMenu[512], iKeys = (1<<0|1<<8|1<<9), iLen = formatex(szMenu, charsmax(szMenu), "\yНастройки объектов^n\dClassName \r%s \d| Объект \r#%d \d| Стак \r%d^n^n", g_iSelectedEnt[id][entNAME], g_iSelectedEnt[id][entID], g_iSelectedEnt[id][entSTACK]);
	if(!g_iSelectedEnt[id][entDELETE])
	{
		iKeys |= (1<<1|1<<3|1<<5|1<<6);
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r1\y] \wТелепорт^n");
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r2\y] \wУдалить с карты^n^n");
		if(g_iSelectedEnt[id][entDIR] != DirNONE || g_iStack < MAX_STACKS)
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r3\y] \wСторона \r[%s]^n", g_szDirType[g_iSelectedEnt[id][entDIR]]);
			iKeys |= (1<<2);
		}
		else iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r3\y] \dМаксимально отрисовок^n");
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r4\y] \wЦвет \r[%s]^n", g_szColors[g_iSelectedEnt[id][entCOLOR]]);
		if(equal(g_iSelectedEnt[id][entNAME], g_szEntityAllowed[0]))
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r5\y] \wИзменить скорость \r[Текущая %0.1f]^n", g_iSelectedEnt[id][entSPEED]);
			iKeys |= (1<<4);
		}
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y[\r6\y] \yСохранить изменения^n");
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r7\y] \rУдалить все изменения^n^n");
	}
	else
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r1\y] \rВосстановить объект^n^n");
	}
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r9\y] \wНазад^n");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y[\r0\y] \wВыход");
	return show_menu(id, iKeys, szMenu, -1, "EntityOptions");
}

public Handle_EntityOptions(id, iKey)
{
	new index = GetIndex(g_iSelectedEnt[id][entMODEL]);
	new bool:isDelete = ArrayGetCell(g_aEntity, index, entDELETE);
	
	switch(iKey)
	{
		case 0:
		{
			if(!isDelete)
			{
				new Float:origin[3];
				pev(g_iSelectedEnt[id][entID], pev_maxs, origin);
				set_pev(id, pev_origin, origin);
				client_print_color(id, print_team_blue, "^4[%s] ^1Вы были ^3телепортированы ^1к выбранному объекту!", PLUG_NAME);
			}
			else
			{
				g_iSelectedEnt[id][entDELETE] = false;
				ArraySetCell(g_aEntity, index, false, entDELETE);
				Save(fRect, index);
				client_print_color(id, print_team_blue, "^4[%s] ^1Вы ^3восстановили ^1выбранный объект!", PLUG_NAME);
				return EntityMenu(id, g_iPlayerPage[id] = 0);
			}
		}
		case 1:
		{
			if(!isDelete)
			{
				ArraySetCell(g_aEntity, index, true, entDELETE);
				ArraySetCell(g_aEntity, index, DirNONE, entDIR);
				ArraySetCell(g_aEntity, index, -1, entSTACK);

				Save(fRect, index);

				DrawRectangle(DirNONE, g_iSelectedEnt[id][entID], g_iSelectedEnt[id][entSTACK]);

				g_iSelectedEnt[id][entMODEL] = "^0";
				g_iSelectedEnt[id][entNAME] = "^0";
				g_iSelectedEnt[id][entID] = -1;
				g_iSelectedEnt[id][entDIR] = DirNONE;
				g_iSelectedEnt[id][entSPEED] = 0.0;
				g_iSelectedEnt[id][entDELETE] = false;

				client_print_color(id, print_team_red, "^4[%s] ^1Вы ^3удалили ^1выбранный объект с карты!", PLUG_NAME);
				return EntityMenu(id, g_iPlayerPage[id] = 0);
			}
		}
		case 2:
		{
			if(!isDelete)
			{
				if(g_iSelectedEnt[id][entDIR] != DirNONE || g_iStack < MAX_STACKS)
				{
					switch(g_iSelectedEnt[id][entDIR])
					{
						case DirNONE:
						{
							g_iSelectedEnt[id][entDIR] = DirX1;
						}
						case DirX1:
						{
							g_iSelectedEnt[id][entDIR] = DirX2;
						}
						case DirX2:
						{
							g_iSelectedEnt[id][entDIR] = DirY1;
						}
						case DirY1:
						{
							g_iSelectedEnt[id][entDIR] = DirY2;
						}
						case DirY2:
						{
							g_iSelectedEnt[id][entDIR] = DirZ1;
						}
						case DirZ1:
						{
							g_iSelectedEnt[id][entDIR] = DirZ2;
						}
						case DirZ2:
						{
							g_iSelectedEnt[id][entDIR] = DirNONE;
						}
					}

					ArraySetCell(g_aEntity, index, g_iSelectedEnt[id][entDIR], entDIR);
					g_iSelectedEnt[id][entSTACK] = DrawRectangle(g_iSelectedEnt[id][entDIR], g_iSelectedEnt[id][entID], g_iSelectedEnt[id][entSTACK]);
					ArraySetCell(g_aEntity, index, g_iSelectedEnt[id][entSTACK], entSTACK);
				}
			}
		}
		case 3:
		{
			if(!isDelete)
			{
				if(++g_iSelectedEnt[id][entCOLOR] >= Colors)
				{
					g_iSelectedEnt[id][entCOLOR] = 0;
				}
				ArraySetCell(g_aEntity, index, g_iSelectedEnt[id][entCOLOR], entCOLOR);
			}
		}
		case 4:
		{
			if(!isDelete)
			{
				client_cmd(id, "messagemode ent_speed");
			}
		}
		case 5:
		{
			if(!isDelete)
			{
				Save(fRect, index);
				client_print_color(id, print_team_blue, "^4[%s] ^1Изменения сохранены!", PLUG_NAME);
			}
		}
		case 6:
		{
			if(!isDelete)
			{
				new iSolid = ArrayGetCell(g_aOldEntity, index, oldSOLID);
				set_pev(g_iSelectedEnt[id][entID], pev_solid, iSolid);

				new Float:fSpeed = ArrayGetCell(g_aOldEntity, index, oldSPEED);
				ArraySetCell(g_aEntity, index, fSpeed, entSPEED);
				set_pev(g_iSelectedEnt[id][entID], pev_speed, fSpeed);

				Save(fRect, index);
				client_print_color(id, print_team_red, "^4[%s] ^1Изменения удалены!", PLUG_NAME);
			}
		}
		case 8:
		{
			return EntityMenu(id, g_iPlayerPage[id] = 0);
		}
		case 9:
		{
			return PLUGIN_HANDLED;
		}
	}
	return EntityOptions(id);
}

public DrawRectangle(iDir, iEntityID, iEntitySTACK)
{
	if(!pev_valid(iEntityID))
	{
		return -1;
	}

	if(iDir == DirNONE)
	{
		for(new i = 0; i < MAX_RECT_POINTS; i++)
		{
			for(new j = 0; j < 3; j++)
			{
				g_iEntityRect[iEntitySTACK][i][j] = 0.0;
			}
		}
		iEntitySTACK = -1;
		--g_iStack;
	}
	else
	{	
		new Float:sizeMax[3], Float:sizeMin[3];
		pev(iEntityID, pev_maxs, sizeMax);
		pev(iEntityID, pev_mins, sizeMin);

		if(iEntitySTACK == -1)
		{
			iEntitySTACK = GetFreeStack();
			++g_iStack;
		}

		switch(iDir)
		{
			case DirX1:
			{
				g_iEntityRect[iEntitySTACK][0][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][0][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][0][2] = sizeMax[2];

				g_iEntityRect[iEntitySTACK][1][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][1][1] = sizeMin[1];
				g_iEntityRect[iEntitySTACK][1][2] = sizeMax[2];

				g_iEntityRect[iEntitySTACK][2][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][2][1] = sizeMin[1];
				g_iEntityRect[iEntitySTACK][2][2] = sizeMin[2];

				g_iEntityRect[iEntitySTACK][3][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][3][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][3][2] = sizeMin[2];

				g_iEntityRect[iEntitySTACK][4][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][4][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][4][2] = sizeMax[2];

			}
			case DirX2:
			{
				g_iEntityRect[iEntitySTACK][0][0] = sizeMin[0];
				g_iEntityRect[iEntitySTACK][0][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][0][2] = sizeMax[2];

				g_iEntityRect[iEntitySTACK][1][0] = sizeMin[0];
				g_iEntityRect[iEntitySTACK][1][1] = sizeMin[1];
				g_iEntityRect[iEntitySTACK][1][2] = sizeMax[2];

				g_iEntityRect[iEntitySTACK][2][0] = sizeMin[0];
				g_iEntityRect[iEntitySTACK][2][1] = sizeMin[1];
				g_iEntityRect[iEntitySTACK][2][2] = sizeMin[2];

				g_iEntityRect[iEntitySTACK][3][0] = sizeMin[0];
				g_iEntityRect[iEntitySTACK][3][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][3][2] = sizeMin[2];

				g_iEntityRect[iEntitySTACK][4][0] = sizeMin[0];
				g_iEntityRect[iEntitySTACK][4][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][4][2] = sizeMax[2];
			}
			case DirY1:
			{
				g_iEntityRect[iEntitySTACK][0][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][0][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][0][2] = sizeMax[2];

				g_iEntityRect[iEntitySTACK][1][0] = sizeMin[0];
				g_iEntityRect[iEntitySTACK][1][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][1][2] = sizeMax[2];

				g_iEntityRect[iEntitySTACK][2][0] = sizeMin[0];
				g_iEntityRect[iEntitySTACK][2][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][2][2] = sizeMin[2];

				g_iEntityRect[iEntitySTACK][3][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][3][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][3][2] = sizeMin[2];

				g_iEntityRect[iEntitySTACK][4][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][4][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][4][2] = sizeMax[2];
			}
			case DirY2:
			{
				g_iEntityRect[iEntitySTACK][0][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][0][1] = sizeMin[1];
				g_iEntityRect[iEntitySTACK][0][2] = sizeMax[2];

				g_iEntityRect[iEntitySTACK][1][0] = sizeMin[0];
				g_iEntityRect[iEntitySTACK][1][1] = sizeMin[1];
				g_iEntityRect[iEntitySTACK][1][2] = sizeMax[2];

				g_iEntityRect[iEntitySTACK][2][0] = sizeMin[0];
				g_iEntityRect[iEntitySTACK][2][1] = sizeMin[1];
				g_iEntityRect[iEntitySTACK][2][2] = sizeMin[2];

				g_iEntityRect[iEntitySTACK][3][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][3][1] = sizeMin[1];
				g_iEntityRect[iEntitySTACK][3][2] = sizeMin[2];

				g_iEntityRect[iEntitySTACK][4][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][4][1] = sizeMin[1];
				g_iEntityRect[iEntitySTACK][4][2] = sizeMax[2];
			}
			case DirZ1:
			{
				g_iEntityRect[iEntitySTACK][0][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][0][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][0][2] = sizeMax[2];

				g_iEntityRect[iEntitySTACK][1][0] = sizeMin[0];
				g_iEntityRect[iEntitySTACK][1][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][1][2] = sizeMax[2];

				g_iEntityRect[iEntitySTACK][2][0] = sizeMin[0];
				g_iEntityRect[iEntitySTACK][2][1] = sizeMin[1];
				g_iEntityRect[iEntitySTACK][2][2] = sizeMax[2];

				g_iEntityRect[iEntitySTACK][3][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][3][1] = sizeMin[1];
				g_iEntityRect[iEntitySTACK][3][2] = sizeMax[2];

				g_iEntityRect[iEntitySTACK][4][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][4][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][4][2] = sizeMax[2];
			}
			case DirZ2:
			{
				g_iEntityRect[iEntitySTACK][0][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][0][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][0][2] = sizeMin[2];

				g_iEntityRect[iEntitySTACK][1][0] = sizeMin[0];
				g_iEntityRect[iEntitySTACK][1][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][1][2] = sizeMin[2];

				g_iEntityRect[iEntitySTACK][2][0] = sizeMin[0];
				g_iEntityRect[iEntitySTACK][2][1] = sizeMin[1];
				g_iEntityRect[iEntitySTACK][2][2] = sizeMin[2];

				g_iEntityRect[iEntitySTACK][3][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][3][1] = sizeMin[1];
				g_iEntityRect[iEntitySTACK][3][2] = sizeMin[2];

				g_iEntityRect[iEntitySTACK][4][0] = sizeMax[0];
				g_iEntityRect[iEntitySTACK][4][1] = sizeMax[1];
				g_iEntityRect[iEntitySTACK][4][2] = sizeMin[2];
			}
		}
	}

	return iEntitySTACK;
}

public DrawTask()
{
	new iColor;
	if(g_iStack > 0)
	{
		new iSize, iStack;
		iSize = ArraySize(g_aEntity);
		for(new i = 0; i < iSize; i++)
		{
			iStack = ArrayGetCell(g_aEntity, i, entSTACK);
			if(iStack == -1)
			{
				continue;
			}

			iColor = ArrayGetCell(g_aEntity, i, entCOLOR);
			for(new j = 1; j < MAX_RECT_POINTS; j++)
			{
				CreateBeampoints(g_iEntityRect[iStack][j-1], g_iEntityRect[iStack][j], g_iColors[iColor]);
			}
		}
	}

	if(g_iPointStack >= 0)
	{
		for(new i = 0; i < g_iPointStack; i++)
		{
			if(is_empty(g_iPoints[i][MIN_POINTS-1]))
			{
				continue;
			}

			iColor = ArrayGetCell(g_aPoints, i, pntCOLOR);
			for(new j = 1; j < MAX_POINTS; j++)
			{
				CreateBeampoints(g_iPoints[i][j-1], g_iPoints[i][j], g_iColors[iColor]);
			}
		}
	}
}

public CreateBeampoints(Float:firstOrigin[3], Float:secondOrigin[3], iColors[3])
{
	if(is_empty(firstOrigin) || is_empty(secondOrigin))
	{
		return;
	}

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMPOINTS);
	engfunc(EngFunc_WriteCoord, firstOrigin[0]);
	engfunc(EngFunc_WriteCoord, firstOrigin[1]);
	engfunc(EngFunc_WriteCoord, firstOrigin[2]);
	engfunc(EngFunc_WriteCoord, secondOrigin[0]);
	engfunc(EngFunc_WriteCoord, secondOrigin[1]);
	engfunc(EngFunc_WriteCoord, secondOrigin[2]);
	write_short(g_iSprite);
	write_byte(0);			// framestart
	write_byte(0);			// framerate
	write_byte(20);			// life in 0.1's
	write_byte(20);			// width
	write_byte(0);			// noise
	write_byte(iColors[0]);	// red
	write_byte(iColors[1]);	// green
	write_byte(iColors[2]);	// blue
	write_byte(255);		// brightness
	write_byte(0);			// speed
	message_end();
}

stock fm_get_aim_origin(id, Float:origin[3])
{
	static Float:start[3], Float:view_ofs[3];
	pev(id, pev_origin, start);
	pev(id, pev_view_ofs, view_ofs);
	xs_vec_add(start, view_ofs, start);
	
	static Float:dest[3];
	pev(id, pev_v_angle, dest);
	engfunc(EngFunc_MakeVectors, dest);
	global_get(glb_v_forward, dest);
	xs_vec_mul_scalar(dest, 9999.0, dest);
	xs_vec_add(start, dest, dest);
	
	engfunc(EngFunc_TraceLine, start, dest, 0, id, 0);
	get_tr2(0, TR_vecEndPos, origin);
	
	return 1;
}

stock GetIndex(szModel[])
{
	new iIndex = ArrayFindString(g_aEntity, szModel);
	return iIndex;
}

stock GetFreeStack()
{
	new iStack = -1;
	for(new i = 0; i < MAX_STACKS; i++)
	{
		if(g_iEntityRect[i][0][0] == 0.0)
		{
			iStack = i;
			break;
		}
	}
	return iStack;
}

//iMode: 0 - normal save, 1 - delete string and save new string, 2 - delete string
stock Save(file, index, iMode = 0)
{
	if(iMode != 2)
	{
		if(file == fRect && ArraySize(g_aEntity) == 0 || file == fPoints && is_empty(g_iPoints[index][MIN_POINTS-1]))
		{
			return 0;
		}
	}

	new szFile[128], szTemp[128];
	formatex(szFile, charsmax(szFile), "%s/%s", g_szDir, DT_FILES[file]);
	formatex(szTemp, charsmax(szTemp), "%s/%s", g_szDir, DT_FILES_TEMP[file]);

	new szText[256];

	//fRect variables
	new aEntity[EntityInfo], szClass[32], szModel[32];

	//fPoints variables
	new aPoints[PointsInfo], iLen, iCount;

	if(file == fRect)
	{
		ArrayGetArray(g_aEntity, index, aEntity);
		formatex(szText, charsmax(szText), "^"%s^" ^"%s^" ^"%d^" ^"%d^" ^"%f^" ^"%d^"", 
			aEntity[entNAME], aEntity[entMODEL], aEntity[entDIR], aEntity[entCOLOR], aEntity[entSPEED], aEntity[entDELETE]);
	}
	else if(file == fPoints)
	{
		ArrayGetArray(g_aPoints, index, aPoints);
		iLen = formatex(szText, charsmax(szText), "^"%d^" ^"%d^"", aPoints[pntPOINT], aPoints[pntCOLOR]);

		for(new i = 0; i < aPoints[pntPOINT]; i++)
		{
			iLen += formatex(szText[iLen], charsmax(szText) - iLen, " ^"%0.3f %0.3f %0.3f^"", g_iPoints[index][i][0], g_iPoints[index][i][1], g_iPoints[index][i][2]);
		}
	}

	new iFile = fopen(szTemp ,"wt");
	new iOldFile = fopen(szFile, "rt");
	new szData[256], bool:isReplaced, bool:isAllowed;
	while(!feof(iOldFile))
	{
		fgets(iOldFile, szData, 255);
		if(file == fRect)
		{
			parse(szData, szClass, 31, szModel, 31);
			isAllowed = equal(szClass, aEntity[entNAME]) && equal(szModel, aEntity[entMODEL]);
		}
		else if(file == fPoints)
		{
			isAllowed = iCount == index;
			++iCount;
		}

		if(isAllowed && !isReplaced)
		{
			if(iMode == 2 || iMode == 1)
			{
				fputs(iFile, "");
			}
			
			if(iMode == 0 || iMode == 1)
			{
				fprintf(iFile, "%s^n", szText);
			}
			isReplaced = true;
		}
		else
		{
			fputs(iFile, szData);
		}
	}

	if(!isReplaced && iMode != 2)
	{
		fprintf(iFile, "%s^n", szText);
	}

	fclose(iFile);
	fclose(iOldFile);

	delete_file(szFile);
	while(!rename_file(szTemp, szFile, 1)) {}

	return 1;
}

stock Load(file)
{
	new szFile[128];
	formatex(szFile, charsmax(szFile), "%s/%s", g_szDir, DT_FILES[file]);
	new iFile = fopen(szFile, "rt");

	if(!iFile)
	{
		server_print("[%s] Не удаётся открыть файл %s.", PLUG_NAME, DT_FILES[file]);
		return;
	}

	new szData[256];

	//fRect variables
	new szName[32], szModel[32], szDir[16], szColor[16], szSpeed[16], szDelete[16], aEntity[EntityInfo];

	//fPoints variables
	new szPoint[16], szPoints[MAX_POINTS][32], aPoints[PointsInfo];

	while(!feof(iFile))
	{
		fgets(iFile, szData, charsmax(szData));

		if(!szData[0] || szData[0] == ';')
		{
			continue;
		}

		if(file == fRect)
		{
			parse(szData, szName, 31, szModel, 31, szDir, 15, szColor, 15, szSpeed, 15, szDelete, 15);

			aEntity[entMODEL] = szModel;
			aEntity[entNAME] = szName;
			aEntity[entDIR] = str_to_num(szDir);
			aEntity[entCOLOR] = str_to_num(szColor);
			aEntity[entSPEED] = str_to_float(szSpeed);
			aEntity[entDELETE] = bool:str_to_num(szDelete);

			ArrayPushArray(g_aEntity, aEntity);
		}
		else if(file == fPoints)
		{
			parse(szData, szPoint, 15, szColor, 15, szPoints[0], 31, szPoints[1], 31, szPoints[2], 31, szPoints[3], 31, szPoints[4], 31, szPoints[5], 31);

			aPoints[pntPOINT] = str_to_num(szPoint);
			aPoints[pntCOLOR] = str_to_num(szColor);
			aPoints[pntSTACK] = g_iPointStack;

			new szOrigin[3][32];
			for(new i = 0; i < str_to_num(szPoint); i++)
			{
				parse(szPoints[i], szOrigin[0], 31, szOrigin[1], 31, szOrigin[2], 31);
				for(new j = 0; j < 3; j++)
				{
					g_iPoints[g_iPointStack][i][j] = str_to_float(szOrigin[j]);
				}
			}

			++g_iPointStack;
			ArrayPushArray(g_aPoints, aPoints);
		}
	}

	fclose(iFile);
}


bool:is_aiming_at_sky(id)
{
    new Float:origin[3];
    fm_get_aim_origin(id, origin);

    return engfunc(EngFunc_PointContents, origin) == CONTENTS_SKY;
}

bool:is_empty(Float:fOrigin[3])
{
	new bool:empty = (fOrigin[0] + fOrigin[1] + fOrigin[2]) == 0 ? true : false;
	return empty;
}