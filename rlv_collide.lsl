
// Code released to the public domain by Okie Heartsong @ OsGrid
//
// Written to avoid bugs with llVolumeDetect() on older OpenSim such as 0.8
// Of course fully working on modern OpenSim as well :)
//
// Doesn't use ossl functions so should work in SL too
// ===========================================================================

float   RELAY_DETECT_TIME = 5.0;

integer flip = FALSE;   // workaround
integer RLV_RC =-1812221819;
integer g_iHandle;

integer g_iNotecardLine;
key     g_kdsNotecard;

list    g_lCommands;
integer g_iCurrentCmd;

key     g_kVictim;

string  NOTECARD = "commands.config";
string  TRAPNAME = "plant";

Configure() {
    if (llGetInventoryKey(NOTECARD)==NULL_KEY) {
        llOwnerSay("Error: "+NOTECARD+" not found");
        return;
    }

    llSetText("Configuring", <1,1,1>, 1);
    
    integer sounds = llGetInventoryNumber(INVENTORY_SOUND);
    integer a;
    for (a = 0; a < sounds; a++)
    {
        llPreloadSound(llGetInventoryName(INVENTORY_SOUND, a));
        llSay(PUBLIC_CHANNEL, "Preloading sound " + llGetInventoryName(INVENTORY_SOUND, a) + ".");
    }

    g_lCommands = ["!version"];
    g_iNotecardLine = 0;
    g_kdsNotecard = llGetNotecardLine(NOTECARD, g_iNotecardLine);
}

CovertSay(string sText)
{
    string sObjectName = llGetObjectName();
    llSetObjectName(".");
    llSay(0, sText);
    llSetObjectName(sObjectName);
}

Init()
{
    g_kVictim = NULL_KEY;
    flip = FALSE;
    llSetStatus(STATUS_PHANTOM, FALSE); // workaround
    llSleep(0.4);
    llVolumeDetect(TRUE);
    llListenRemove(g_iHandle);
    g_iHandle = llListen(RLV_RC, "", "", "");
}

default
{
    state_entry()
    {
        if (llGetListLength(g_lCommands)<=1) Configure();
        Init();
    }
    
    on_rez(integer start_param)
    {
        llResetScript();
    }

    changed(integer iChange)
    {
        if(iChange & CHANGED_INVENTORY)
        {
            Configure();
        }
    } 
    
    collision_start(integer total_number)
    {
        if (flip == FALSE) {
            flip = TRUE;
            g_kVictim = llDetectedKey(0);
            if (g_kVictim==NULL_KEY) return;
            llSetTimerEvent(RELAY_DETECT_TIME);
            g_iCurrentCmd = 0; // !version
            llRegionSayTo((string)g_kVictim, RLV_RC,
                TRAPNAME+","+(string)g_kVictim+","+llList2String(g_lCommands, g_iCurrentCmd));
        }
    }
    
    listen (integer iChannel, string sName, key kID, string sMsg)
    {
        if (llGetOwnerKey(kID) != g_kVictim) return;
        list lResponse = llParseString2List(sMsg, [","], []);
        if (llList2String(lResponse, 0) != TRAPNAME) return;
        string sCmd = llList2String(lResponse, 2);
        if (llListFindList(g_lCommands, [sCmd]) != g_iCurrentCmd) {
            llOwnerSay("ERROR: RLV command response is not what was expected");
            Init();
            return;
        }
        if (g_iCurrentCmd == 0) {
            // Stop timer (which we used for detecting this relay), say something and play sounds
            llSetTimerEvent(0.0);
            CovertSay("Oh no! Your top has caught on the thorn of a bush!");
            integer i;
            for (i = 0; i < llGetInventoryNumber(INVENTORY_SOUND); i++)
                llTriggerSound(llGetInventoryName(INVENTORY_SOUND, i), 1.0);
        }
        if (g_iCurrentCmd < llGetListLength(g_lCommands)) {
            g_iCurrentCmd++;
            llRegionSayTo((string)g_kVictim, RLV_RC,
                TRAPNAME+","+(string)g_kVictim+","+llList2String(g_lCommands, g_iCurrentCmd));
        }
        if (g_iCurrentCmd == (llGetListLength(g_lCommands)-1)) {
            // Clean up after last command, suspend before re-arming
            CovertSay("Naughty bush! Time for the weedkiller!");
            Init();
        }
    }
    
    timer()
    {
        // This timer will be executed if no relay was found
        llSetTimerEvent(0.0);
        Init();
    }
    
    dataserver(key kID, string sData)
    {
        if (kID!=g_kdsNotecard) return;
        
        if (sData==EOF) {
            // notecard reading finished
            // trap all ready
            llSetText("", <1,1,1>, 1);
       } else {
            string sLine = llStringTrim(sData, STRING_TRIM);
            if (llGetSubString(sLine, 0, 0)!="#") g_lCommands += sData;
            g_kdsNotecard = llGetNotecardLine(NOTECARD, ++g_iNotecardLine);
        }
    }
}
