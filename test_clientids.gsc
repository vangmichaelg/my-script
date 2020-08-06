#include maps/mp/_utility;
#include common_scripts/utility;
#include maps/mp/gametypes_zm/_hud_util;
#include maps/mp/zombies/_zm;
#include maps/mp/zombies/_zm_utility;
#include maps/mp/zombies/_zm_weapons;
#include maps/mp/zombies/_zm_stats;
#include maps/mp/gametypes_zm/_hud_message;
#include maps/mp/zombies/_zm_powerups;
#include maps/mp/zombies/_zm_perks;
#include maps/mp/zombies/_zm_audio;
#include maps/mp/zombies/_zm_score;
#include maps/mp/zombies/_zm_spawner;
#include maps/mp/zombies/_zm_transit;

init()
{
	level.clientid = 0;
	level.perk_purchase_limit = 9;
	thread initCustomPowerups(); //initilize custom powerups
	level thread onplayerconnect();
	drawZombiesCounter(); //Thanks to CabConModding
	thread gscRestart();
	//riotshield health 
	level.cmEquipmentRiotshieldHitPoints = getDvarIntDefault( "cmEquipmentRiotshieldHitPoints", 80000 );
	level.zombie_vars[ "riotshield_hit_points" ] = level.cmEquipmentRiotshieldHitPoints;
    thread setPlayersToSpectator();
    for(;;)
    {
        level waittill("connected", player);
		player thread welcome();
		player thread [[level.givecustomcharacters]]();
		//The real cause of the invisible player glitch is that this function isn't always called on map_restart so call it here.
		//This will just call the method the map uses for give_personality_characters or give_team_characters without all the includes and it workes on NukeTown as well.
		//We don't need to check the game mode since each game mode's init function does set level.givecustomcharacters with an pointer to the correct method.
    }
}

welcome()
{
	if ( level.round_number > 0 )
    {
        if (isDefined(level.zombiemode_using_juggernaut_perk) && level.zombiemode_using_juggernaut_perk)
         self doGivePerk("specialty_armorvest");
		self iprintln("You got Juggernaut");
     }
	self waittill( "spawned_player" ); 	
}

doGivePerk(perk)
{
    self endon("disconnect");
    self endon("death");
    level endon("game_ended");
    self endon("perk_abort_drinking");
    if (!(self hasperk(perk) || (self maps/mp/zombies/_zm_perks::has_perk_paused(perk))))
    {
        gun = self maps/mp/zombies/_zm_perks::perk_give_bottle_begin(perk);
        evt = self waittill_any_return("fake_death", "death", "player_downed", "weapon_change_complete");
        if (evt == "weapon_change_complete")
            self thread maps/mp/zombies/_zm_perks::wait_give_perk(perk, 1);
        self maps/mp/zombies/_zm_perks::perk_give_bottle_end(gun, perk);
        if (self maps/mp/zombies/_zm_laststand::player_is_in_laststand() || isDefined(self.intermission) && self.intermission)
            return;
        self notify("burp");
    }
}

onplayerconnect()
{ 
		level endon( "end_game" );
    self endon( "disconnect" );
		for (;;)
	{
		level waittill( "connected", player );
		player.clientid = level.clientid;
		player thread onplayerspawned();
		level.clientid++;
		player thread displayScore();	
		player thread startCustomPowerups(); //start custom powerups - Credit _Ox. just edited and added more powerups.
		player thread startCustomPerkMachines(); //spawns custom perk machines on the map
	}
}

onplayerspawned()
{
		level endon( "game_ended" );
    self endon( "disconnect" );
		for (;;)
		{
				self waittill ( "spawned_player" );
				
				if(level.round_number >= 0 && self.score < 6000) //in case players have low score and die or players join late (Helps to aid the high round, cant afford jug or gun situation)
					self.score = 6000;
				else if(level.round_number >= 15 && self.score < 15000)
					self.score = 15000;
				self thread initCustomPerksOnPlayer(); //checks mapname and if it should give PHD flopper automatically
		}		
	self thread AnimatedTextCUSTOMPOS("Welcome to ^1Zombies \n^7Thanks to ^5DoktorSAS", 0,-200); //Welcome Messages
}

AnimatedTextCUSTOMPOS(text, x, y)
{ //Made by DoktorSAS
	textSubStr = getSubStr(text,0,text.size);
	result = "";
	welcome = self createFontString("hudsmall",1.9);
	welcome setPoint("CENTER","CENTER",x, y);
	welcome setText("");	
	for(i=0;i<textSubStr.size;i++)
	{
		color = textSubStr[i]+textSubStr[i+1];
		if(color == "^1" || color == "^2" || color == "^3" || color == "^4" || color == "^5" || color == "^6" || color == "^7" || color == "^8" || color == "^0" || color == "\n")
		{
			result = result + color;
			i++;
		}else
			result = result + textSubStr[i];
		if(i == textSubStr.size)
		{
			welcome setText(text);
		}else
		{
			welcome setText(result);
			wait 0.15;
			welcome setText(result + "^7_");
		}
		wait 0.15;
	}
	wait 2;
	welcome setText("");
	self iprintln("Whats Inside: \n # ^1NO ^2Perk ^7Limit \n # ^1Zombies ^7Counter");
}

drawZombiesCounter()
{ //Thanks to CabConModding
    level.zombiesCountDisplay = createServerFontString("hudsmall" , 1.9);
    level.zombiesCountDisplay setPoint("CENTER", "CENTER", "CENTER", 200);
    thread updateZombiesCounter();
}

updateZombiesCounter()
{ //Thanks to CabConModding
    level endon("stopUpdatingZombiesCounter");
    while(true)
	{
        zombiesCount = get_current_zombie_count();
        if(zombiesCount >= 0)
		{
        	level.zombiesCountDisplay setText("Zombies: ^1" + zombiesCount);
        }else
        	level.zombiesCountDisplay setText("Zombies: ^2" + zombiesCount);
        waitForZombieCountChanged("stopUpdatingZombiesCounter");
    }
}

recreateZombiesCounter()
{ //Thanks to CabConModding
    level notify("stopUpdatingZombiesCounter");
    thread updateZombiesCounter();
}

waitForZombieCountChanged(endonNotification)
{ //Thanks to CabConModding
    level endon(endonNotification);
    oldZombiesCount = get_current_zombie_count();
    while(true)
	{
        newZombiesCount = get_current_zombie_count();
        if(oldZombiesCount != newZombiesCount)
		{
            return;
        }
        wait 0.05;
    }
}

displayScore()
{
	self waittill("spawned_player");
	self.scoreText = CreateFontString("Objective", 1.5);
	self.scoretext setPoint("CENTER", "RIGHT", "CENTER", "RIGHT");
	self.scoreText.label = &"^2Score: ^7";
	while(true)
	{
		wait 0.25;
		if(getplayers().size >= 5 && self.scoretext.alpha == 0)
		{
			self.scoretext FadeOverTime( 1 );
			self.scoretext.alpha = 1;
		}
		else if(getplayers().size < 5 && self.scoretext.alpha >= 0)
		{
			self.scoretext FadeOverTime( 1 );
			self.scoretext.alpha = 0;
		}
		else if(getplayers().size >= 5 && isDefined(self.scoretext))
		{
			self.scoretext SetValue(self.score);
		}
	}
}

gscRestart()
{
	level waittill( "end_game" );
      	wait 12;
        map_restart( false );
}

setPlayersToSpectator()
{
	level.no_end_game_check = 1;
	wait 3;
	players = get_players();
	i = 0;
	while ( i < players.size )
	{
		if ( i == 0 )
		{
			i++;
		}
		players[ i ] setToSpectator();
		i++;
	}
	wait 5; 
	spawnAllPlayers();
}

setToSpectator()
{
    self.sessionstate = "spectator"; 
    if (isDefined(self.is_playing))
    {
        self.is_playing = false;
    }
}

spawnAllPlayers()
{
	players = get_players();
	i = 0;
	while ( i < players.size )
	{
		if ( players[ i ].sessionstate == "spectator" && isDefined( players[ i ].spectator_respawn ) )
		{
			players[ i ] [[ level.spawnplayer ]]();
			if ( level.script != "zm_tomb" || level.script != "zm_prison" || !is_classic() )
			{
				thread maps\mp\zombies\_zm::refresh_player_navcard_hud();
			}
		}
		i++;
	}
	level.no_end_game_check = 0;
}

startCustomPowerups()
{
	if(!isDefined(level.custompowerupinit))
	{
		level.custompowerupinit = true;
		wait 2;
        	if(isDefined(level._zombiemode_powerup_grab))
        		level.original_zombiemode_powerup_grab = level._zombiemode_powerup_grab;
		wait 2;
        	level._zombiemode_powerup_grab = ::custom_powerup_grab;
	}
}

initCustomPowerups() //credit goes to _Ox for the original code <3
{
	level.unlimited_ammo_duration = 20;
	//unlimited ammo drop "bottomless clip" credit to _Ox
	include_zombie_powerup("unlimited_ammo");
	add_zombie_powerup("unlimited_ammo", "T6_WPN_AR_GALIL_WORLD", &"ZOMBIE_POWERUP_UNLIMITED_AMMO", ::func_should_always_drop, 0, 0, 0);
	powerup_set_can_pick_up_in_last_stand("unlimited_ammo", 1);
	if(getDvar("mapname") == "zm_prison")
	{
		//fast feet - speed potion, basically you run fast for 15 seconds
		include_zombie_powerup("fast_feet");
		add_zombie_powerup("fast_feet", "bottle_whisky_01", &"ZOMBIE_POWERUP_FAST_FEET", ::func_should_always_drop, 0, 0, 0);
		powerup_set_can_pick_up_in_last_stand("fast_feet", 1);
		//pack a punch - pack a punches your current gun credit Knight
		include_zombie_powerup("pack_a_punch");
		add_zombie_powerup("pack_a_punch", "p6_zm_al_vending_pap_on", &"ZOMBIE_POWERUP_PACK_A_PUNCH", ::func_should_drop_pack_a_punch, 0, 0, 0);
		powerup_set_can_pick_up_in_last_stand("pack_a_punch", 0);
		//couldn't find a better model for this money drop, if you find a better one pls let me know haha
		include_zombie_powerup("money_drop");
		add_zombie_powerup("money_drop", "p6_anim_zm_al_magic_box_lock_red", &"ZOMBIE_POWERUP_MONEY_DROP", ::func_should_always_drop, 0, 0, 0);
		powerup_set_can_pick_up_in_last_stand("money_drop", 1);
	}
	else
	{
		include_zombie_powerup("fast_feet");
		add_zombie_powerup("fast_feet", "zombie_pickup_perk_bottle", &"ZOMBIE_POWERUP_FAST_FEET", ::func_should_always_drop, 0, 0, 0);
		powerup_set_can_pick_up_in_last_stand("fast_feet", 1);
		
		include_zombie_powerup("pack_a_punch");
		add_zombie_powerup("pack_a_punch", "p6_anim_zm_buildable_pap", &"ZOMBIE_POWERUP_PACK_A_PUNCH", ::func_should_drop_pack_a_punch, 0, 0, 0);
		powerup_set_can_pick_up_in_last_stand("pack_a_punch", 0);
		
		include_zombie_powerup("money_drop");
		add_zombie_powerup("money_drop", "zombie_teddybear", &"ZOMBIE_POWERUP_MONEY_DROP", ::func_should_always_drop, 0, 0, 0);
		powerup_set_can_pick_up_in_last_stand("money_drop", 1);
	}
}

func_should_drop_pack_a_punch()
{
	if ( level.zmPowerupsEnabled[ "pack_a_punch" ].active != 1 || level.round_number < 12 || isDefined( level.rounds_since_last_pack_a_punch_drop ) && level.rounds_since_last_pack_a_punch_drop < 5 )
	{
		return 0;
	}
	return 1;
}

custom_powerup_grab(powerup, player) //credit to _Ox much thx for powerup functions
{
	if(powerup.powerup_name == "money_drop")
		player thread doRandomScore(); //some cash money
	else if(powerup.powerup_name == "pack_a_punch")
		player thread doPackAPunchWeapon(); //i dont even use this one, its so OP lmao. If we could edit drop rate for this drop only it'd be better
	else if(powerup.powerup_name == "unlimited_ammo")
		player thread doUnlimitedAmmo(); //credit to _Ox for this one baby. its so good
	else if(powerup.powerup_name == "fast_feet")
		player thread doFastFeet(); //go fast as fuck boi
	else if (isDefined(level.original_zombiemode_powerup_grab))
		level thread [[level.original_zombiemode_powerup_grab]](s_powerup, e_player);
}

doFastFeet() //gotta go fast!
{
	self thread poweruptext("Fast Feet!"); //thanks to _Ox again for the powerup pickup string
	self playsound("zmb_cha_ching"); //m-m-m-m-m-money shot
	self setmovespeedscale(3); //super sonic speed
	wait 15;
	self setmovespeedscale(1);
	self playsound("zmb_insta_kill"); //less happy sound than before
}

doUnlimitedAmmo() //unlimited ammo powerup function credit _Ox
{
	foreach(player in level.players)
	{
		player notify("end_unlimited_ammo");
		player playsound("zmb_cha_ching");
		player thread poweruptext("Bottomless Clip");
		player thread monitorUnlimitedAmmo(); //bottomless clip
		player thread notifyUnlimitedAmmoEnd(); //notify when it ends
	}
}

monitorUnlimitedAmmo() //credit to _Ox
{
	level endon("end_game");
	self endon("disonnect");
	self endon("end_unlimited_ammo");
	for(;;)
	{
		self setWeaponAmmoClip(self GetCurrentWeapon(), 150);
		wait .05;
	}
}

notifyUnlimitedAmmoEnd() //credit to _Ox
{
	level endon("end_game");
	self endon("disonnect");
	self endon("end_unlimited_ammo");
	wait level.unlimited_ammo_duration;
	self playsound("zmb_insta_kill");
	self notify("end_unlimited_ammo");
}

doPackAPunchWeapon() //pack a punch function credit Knight
{
    baseweapon = get_base_name(self getcurrentweapon());
    weapon = get_upgrade(baseweapon);
    if(IsDefined(weapon) && isDefined(self.packapunching))
    {
        level.rounds_since_last_pack_a_punch_drop = 0;
        self.packapunching = undefined;
        self takeweapon(baseweapon);
        self giveweapon(weapon, 0, self get_pack_a_punch_weapon_options(weapon));
        self switchtoweapon(weapon);
        self givemaxammo(weapon);
    }
    else
    	self playsoundtoplayer( level.zmb_laugh_alias, self );
}

get_upgrade(weapon)
{
    if(IsDefined(level.zombie_weapons[weapon].upgrade_name) && IsDefined(level.zombie_weapons[weapon]))
    {
    	self.packapunching = true;
        return get_upgrade_weapon(weapon, 0 );
    }
    else
        return get_upgrade_weapon(weapon, 1 );
}

doRandomScore() //this is a bad way of doing this but i couldnt get the array to work before and did this out of frustration
{
	x = randomInt(9); //picks a number 0-9
	self playsound("zmb_cha_ching");
	if(x==1)
		self.score += 50; //+50
	else if(x==2)
		self.score += 100; //+100
	else if(x==3)
		self.score += 250; //+250 I think you get the idea
	else if(x==4)
		self.score += 500;
	else if(x==5)
		self.score += 750;
	else if(x==6)
		self.score += 1000;
	else if(x==7)
		self.score += 2500;
	else if(x==8)
		self.score += 5000;
	else if(x==9)
		self.score += 7500;
	else
		self.score += 10000;
}

poweruptext(text) //credit to _Ox for base string hud
{
	self endon("disconnect");
	level endon("end_game");
	hud_string = newclienthudelem(self);
	hud_string.elemtype = "font";
	hud_string.font = "objective";
	hud_string.fontscale = 2;
	hud_string.x = 0;
	hud_string.y = 0;
	hud_string.width = 0;
	hud_string.height = int( level.fontheight * 2 );
	hud_string.xoffset = 0;
	hud_string.yoffset = 0;
	hud_string.children = [];
	hud_string setparent(level.uiparent);
	hud_string.hidden = 0;
	hud_string maps/mp/gametypes_zm/_hud_util::setpoint("TOP", undefined, 0, level.zombie_vars["zombie_timer_offset"] - (level.zombie_vars["zombie_timer_offset_interval"] * 2));
	hud_string.sort = .5;
	hud_string.alpha = 0;
	hud_string fadeovertime(.5);
	hud_string.alpha = 1;
	hud_string setText(text);
	hud_string thread poweruptextmove();
}

poweruptextmove() //credit to _Ox for base string hud
{
	wait .5;
	self fadeovertime(1.5);
	self moveovertime(1.5);
	self.y = 270;
	self.alpha = 0;
	wait 1.5;
	self destroy();
}

onPlayerDowned()
{
	self endon("disconnect");
	self endon("death");
	level endon("end_game");
	
	for(;;)
	{
		self waittill( "player_downed" );
    	self unsetperk( "specialty_additionalprimaryweapon" ); //removes the mulekick perk functionality
		self unsetperk( "specialty_longersprint" ); //removes the staminup perk functionality
		self unsetperk( "specialty_deadshot" ); //removes the deadshot perk functionality
		self.hasPHD = undefined; //resets the flopper variable
		self.hasMuleKick = undefined; //resets the mule kick variable
		self.hasStaminUp = undefined; //resets the staminup variable
		self.hasDeadshot = undefined; //resets the deadshot variable
    	self.icon1 Destroy();self.icon1 = undefined; //deletes the perk icons and resets the variable
    	self.icon2 Destroy();self.icon2 = undefined; //deletes the perk icons and resets the variable
    	self.icon3 Destroy();self.icon3 = undefined; //deletes the perk icons and resets the variable
    	self.icon4 Destroy();self.icon4 = undefined; //deletes the perk icons and resets the variable
    }
}

initCustomPerksOnPlayer()
{
	self.hasPHD = undefined; //also resets phd flopper when a player dies and respawns
	if(getDvar("mapname") == "zm_nuked" || getDvar("mapname") == "zm_transit" || getDvar("mapname") == "zm_buried" || getDvar("mapname") == "zm_highrise" || getDvar("mapname") == "zm_prison")
	{
		self thread onPlayerDowned(); //takes perks and perk icons when you go down
	}
	else if(getDvar("mapname") != "zm_tomb" && level.disableAllCustomPerks == 0 && level.enablePHDFlopper == 1)
	{
		self.hasPHD = true; //gives phd on maps like town (i think. i actually never tested on any maps besides the ones provided)
		self thread drawCustomPerkHUD("specialty_doubletap_zombies", 0, (1, 0.25, 1));
	}
}

startCustomPerkMachines()
{
	if(level.disableAllCustomPerks == 0)
	{
		self thread doPHDdive(); //self.hasPHD needs to be defined in order for this to work (after you pickup perk)
		if(getDvar("mapname") == "zm_prison") //mob of the dead
		{
			if(level.enablePHDFlopper == 1)
				self thread CustomPerkMachine( "zombie_perk_bottle_deadshot", "p6_zm_al_vending_nuke_on", "PHD Flopper", 3000, (2427.45, 10048.4, 1704.13), "PHD_FLOPPER", (0, 0, 0) );
			if(level.enableStaminUp == 1)
				self thread CustomPerkMachine( "zombie_perk_bottle_deadshot", "p6_zm_al_vending_doubletap2_on", "Stamin-Up", 2000, (-339.642, -3915.84, -8447.88), "specialty_longersprint", (0, 270, 0) );
		}
		else if(getDvar("mapname") == "zm_highrise") //die rise
		{
			if(level.enablePHDFlopper == 1)
				self thread CustomPerkMachine( "zombie_perk_bottle_whoswho", "zombie_vending_nuke_on_lo", "PHD Flopper", 3000, (1260.3, 2736.36, 3047.49), "PHD_FLOPPER", (0, 0, 0) );
			if(level.enableDeadshot == 1)
				self thread CustomPerkMachine( "zombie_perk_bottle_whoswho", "zombie_vending_revive", "Deadshot Daiquiri", 1500, (3690.54, 1932.36, 1420), "specialty_deadshot", (-15, 0, 0) );
			if(level.enableStaminUp == 1)
				self thread CustomPerkMachine( "zombie_perk_bottle_revive", "zombie_vending_doubletap2", "Stamin-Up", 2000, (1704, -35, 1120.13), "specialty_longersprint", (0, -30, 0) );
		}
		else if(getDvar("mapname") == "zm_buried") //buried
		{
			if(level.enablePHDFlopper == 1)
				self thread CustomPerkMachine( "zombie_perk_bottle_marathon", "zombie_vending_jugg", "PHD Flopper", 3000, (2631.73, 304.165, 240.125), "PHD_FLOPPER", (5, 0, 0) );
			if(level.enableDeadshot == 1)
				self thread CustomPerkMachine( "zombie_perk_bottle_marathon", "zombie_vending_revive", "Deadshot Daiquiri", 1500, (1055.18, -1055.55, 201), "specialty_deadshot", (3, 270, 0) );
		}
		else if(getDvar("mapname") == "zm_nuked") //nuketown
		{
			if(level.enablePHDFlopper == 1)
				self thread CustomPerkMachine( "zombie_perk_bottle_revive", "zombie_vending_jugg", "PHD Flopper", 3000, (683, 727, -56), "PHD_FLOPPER", (5, 250, 0) );
			if(level.enableDeadshot == 1)
				self thread CustomPerkMachine( "zombie_perk_bottle_jugg", "zombie_vending_revive", "Deadshot Daiquiri", 1500, (747, 356, 91), "specialty_deadshot", (0, 330, 0) );
			if(level.enableStaminUp == 1)
				self thread CustomPerkMachine( "zombie_perk_bottle_revive", "zombie_vending_doubletap2", "Stamin-Up", 2000, (-638, 268, -54), "specialty_longersprint", (0, 165, 0) );
			if(level.enableMuleKick == 1)
				self thread CustomPerkMachine( "zombie_perk_bottle_jugg", "zombie_vending_sleight", "Mule Kick", 3000, (-953, 715, 83), "specialty_additionalprimaryweapon", (0, 75, 0) );
		}
		else if(getDvar("mapname") == "zm_transit") //transit
		{
			if(level.enablePHDFlopper == 1)
				self thread CustomPerkMachine( "zombie_perk_bottle_revive", "zombie_vending_jugg", "PHD Flopper", 3000, (-6304, 5430, -55), "PHD_FLOPPER", (0, 90, 0) );
			if(level.enableDeadshot == 1)
				self thread CustomPerkMachine( "zombie_perk_bottle_jugg", "zombie_vending_revive", "Deadshot Daiquiri", 1500, (-6088, -7419, 0), "specialty_deadshot", (0, 90, 0) );
			if(level.enableMuleKick == 1)
				self thread CustomPerkMachine( "zombie_perk_bottle_jugg", "zombie_vending_sleight", "Mule Kick", 3000, (1149, -215, -304), "specialty_additionalprimaryweapon", (0, 180, 0) );
		}
	}
}

doPHDdive() //credit to extinct. just edited to add self.hasPHD variable
{
	self endon("disconnect");
	level endon("end_game");
	
	for(;;)
	{
		if(isDefined(self.divetoprone) && self.divetoprone)
		{
			if(self isOnGround() && isDefined(self.hasPHD))
			{
				if(level.script == "zm_tomb" || level.script == "zm_buried")	
					explosionfx = level._effect["divetonuke_groundhit"];
				else
					explosionfx = loadfx("explosions/fx_default_explosion");
				self playSound("zmb_phdflop_explo");
				playfx(explosionfx, self.origin);
				self damageZombiesInRange(310, self, "kill");
				wait .3;
			}
		}
		wait .05;
	}
}

damageZombiesInRange(range, what, amount) //damage zombies for phd flopper
{
	enemy = getAiArray(level.zombie_team);
	foreach(zombie in enemy)
	{
		if(distance(zombie.origin, what.origin) < range)
		{
			if(amount == "kill")
				zombie doDamage(zombie.health * 2, zombie.origin, self);
			else
				zombie doDamage(amount, zombie.origin, self);
		}
	}
}

CustomPerkMachine( bottle, model, perkname, cost, origin, perk, angles ) //custom perk system. orginal code from ZeiiKeN. edited to work for all maps and custom phd perk
{
	self endon( "disconnect" );
	level endon( "end_game" );
	if(!isDefined(level.customPerksAreSpawned))
		level.customPerksAreSpawned = true;
	if(!isDefined(self.customPerkNum))
		self.customPerkNum = 1;
	else
		self.customPerkNum += 1;
	collision = spawn("script_model", origin);
    collision setModel("collision_geo_cylinder_32x128_standard");
    collision rotateTo(angles, .1);
	RPerks = spawn( "script_model", origin );
	RPerks setModel( model );
	RPerks rotateTo(angles, .1);
	level thread LowerMessage( "Custom Perks", "Hold ^3F ^7for "+perkname+" [Cost: "+cost+"]" );
	trig = spawn("trigger_radius", origin, 1, 25, 25);
	trig SetCursorHint( "HINT_NOICON" );
	trig setLowerMessage( trig, "Custom Perks" );
	for(;;)
	{
		trig waittill("trigger", self);
		if(self useButtonPressed() && self.score >= cost)
		{
			wait .25;
			if(self useButtonPressed())
			{
				if(perk != "PHD_FLOPPER" && !self hasPerk(perk) || perk == "PHD_FLOPPER" && !isDefined(self.hasPHD))
				{
					self playsound( "zmb_cha_ching" ); //money shot
					self.score -= cost; //take points
					level.trig hide();
					self thread GivePerk( bottle, perk, perkname ); //give perk
					wait 2;
					level.trig show();
				}
				else
					self iprintln("You Already Have "+perkname+"!");
			}
		}
	}
}

GivePerk( model, perk, perkname )
{
	self DisableOffhandWeapons();
	self DisableWeaponCycling();
	weaponA = self getCurrentWeapon();
	weaponB = model;
	self GiveWeapon( weaponB );
	self SwitchToWeapon( weaponB );
	self waittill( "weapon_change_complete" );
	self EnableOffhandWeapons();
	self EnableWeaponCycling();
	self TakeWeapon( weaponB );
	self SwitchToWeapon( weaponA );
	self setperk( perk );
	self maps/mp/zombies/_zm_audio::playerexert( "burp" );
	self setblur( 4, 0.1 );
	wait 0.1;
	self setblur( 0, 0.1 );
	if(perk == "PHD_FLOPPER")
	{
		self.hasPHD = true;
		self thread drawCustomPerkHUD("specialty_doubletap_zombies", 0, (1, 0.25, 1));
	}
	else if(perk == "specialty_additionalprimaryweapon")
	{
		self.hasMuleKick = true;
		self thread drawCustomPerkHUD("specialty_fastreload_zombies", 0, (0, 0.7, 0));
	}
	else if(perk == "specialty_longersprint")
	{
		self.hasStaminUp = true;
		self thread drawCustomPerkHUD("specialty_juggernaut_zombies", 0, (1, 1, 0));
	}
	else if(perk == "specialty_deadshot")
	{
		self.hasDeadshot = true;
		self thread drawCustomPerkHUD("specialty_quickrevive_zombies", 0, (0.125, 0.125, 0.125));
	}
}

LowerMessage( ref, text )
{
	if( !IsDefined( level.zombie_hints ) )
		level.zombie_hints = [];
	PrecacheString( text );
	level.zombie_hints[ref] = text;
}
setLowerMessage( ent, default_ref )
{
	if( IsDefined( ent.script_hint ) )
		self SetHintString( get_zombie_hint( ent.script_hint ) );
	else
		self SetHintString( get_zombie_hint( default_ref ) );
}

drawshader( shader, x, y, width, height, color, alpha, sort )
{
	hud = newclienthudelem( self );
	hud.elemtype = "icon";
	hud.color = color;
	hud.alpha = alpha;
	hud.sort = sort;
	hud.children = [];
	hud setparent( level.uiparent );
	hud setshader( shader, width, height );
	hud.x = x;
	hud.y = y;
	return hud;
}

drawCustomPerkHUD(perk, x, color, perkname) //perk hud thinking or whatever. probably not the best method but whatever lol
{
    if(!isDefined(self.icon1))
    {
    	x = -408;
    	if(getDvar("mapname") == "zm_buried")
    		self.icon1 = self drawshader( perk, x, 293, 24, 25, color, 100, 0 );
    	else
    		self.icon1 = self drawshader( perk, x, 320, 24, 25, color, 100, 0 );
    }
    else if(!isDefined(self.icon2))
    {
    	x = -378;
    	if(getDvar("mapname") == "zm_buried")
    		self.icon2 = self drawshader( perk, x, 293, 24, 25, color, 100, 0 );
    	else
    		self.icon2 = self drawshader( perk, x, 320, 24, 25, color, 100, 0 );
    }
    else if(!isDefined(self.icon3))
    {
    	x = -348;
    	if(getDvar("mapname") == "zm_buried")
    		self.icon3 = self drawshader( perk, x, 293, 24, 25, color, 100, 0 );
    	else
    		self.icon3 = self drawshader( perk, x, 320, 24, 25, color, 100, 0 );
    }
    else if(!isDefined(self.icon4))
    {
    	x = -318;
    	if(getDvar("mapname") == "zm_buried")
    		self.icon4 = self drawshader( perk, x, 293, 24, 25, color, 100, 0 );
    	else
    		self.icon4 = self drawshader( perk, x, 320, 24, 25, color, 100, 0 );
    }
}

LowerMessage( ref, text )
{
	if( !IsDefined( level.zombie_hints ) )
		level.zombie_hints = [];
	PrecacheString( text );
	level.zombie_hints[ref] = text;
}
setLowerMessage( ent, default_ref )
{
	if( IsDefined( ent.script_hint ) )
		self SetHintString( get_zombie_hint( ent.script_hint ) );
	else
		self SetHintString( get_zombie_hint( default_ref ) );
}