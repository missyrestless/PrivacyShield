///////////////////////////////////////////////////////////////////////////////////
//     Toggle Transparency & Phantom with Touch or Message on Listen Channel     //
//                                                                               //
// Message or Touch by owner of object toggles Face 0 transparency               //
// Listens on channel 0 for trigger messages to shield or become invisible       //
// Messages other objects in region with same owner to trigger toggle command    //
// When the shield is up the prim is solid, when invisible the prim is phantom   //
///////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////
// Copyright (c) 2026 Truth & Beauty Lab          //
// License: GPLv3                                 //
// All rights reserved.                           //
//                                                //
// Author: Missy Restless missyrestless@gmail.com //
////////////////////////////////////////////////////

////////////////////////////////////////////////////
//            Modification History                //
//            --------------------                //
// 2026-Aug-10 Created                            //
// 2026-Aug-11 Gesture controls                   //
// 2026-Aug-12 Multiple textured faces            //
// 2026-Aug-13 Add timers to lock state changes   //
// 2026-Aug-16 Add dialog menu management         //
// 2026-Aug-17 Add texture menu management        //
// 2026-Aug-18 Support for one and two sided      //
// 2026-Aug-19 Use linkset datastore for config   //
// 2026-Aug-27 Support for texturing all shields  //
// 2026-Aug-29 Support Position & Rotation menus  //
// 2026-Aug-31 Support for Media on a Prim TV     //
//                                                //
////////////////////////////////////////////////////

string  VERSION = "2.0.1";

integer ALL     = TRUE;      // Set to TRUE to effect all shields, FALSE for single shield
integer DOUBLE  = FALSE;     // Set to TRUE for double sided shield, FALSE for single sided
integer FLASH   = FALSE;     // Set to TRUE to flash when shield activates, FALSE to disable
integer GROUP   = FALSE;     // Set to TRUE to allow group members to manage, FALSE for owner only
integer SOLID   = TRUE;      // Set to FALSE for always phantom shields, TRUE phantom when invisible
integer TOUCH   = FALSE;     // Set to TRUE to enable touch toggles, FALSE to disable
integer listenerID;          // Not yet used
integer objListenID;         // Not yet used
integer dialogHandle;        // Dialog Menu listener handle, channel, boolean
integer warnHandle;
integer dialogChannel;
integer pageNumber    = 1;   // Dialog Menu page number
integer defaultState  = TRUE;
integer isTransparent = FALSE;
integer selected_face = -1;
integer side_one      = 0;   // Face number for front of shield
integer side_two      = 5;   // Face number for back of shield
integer listenChannel = 0;   // Channel for chat and gestures
integer objChannel;          // Channel for communication between screens, based on owner
integer shieldStatus;        // TRUE if screen active, FALSE if screen is transparent
integer total_faces;         // Number of textured faces

key     owner = NULL_KEY;
key     tcher = NULL_KEY;
list    faces = [];          // Faces with screen texture, all other faces will be transparent
list    texts = [];          // Face & Texture of faces with screen texture, for use as strided list
list    origt = [];          // Original Textures of faces, used by menu restore
float   cloakSpeed =  0.1;
float   def_size_x = -1.0;
float   def_size_y = -1.0;
vector  orig_pos   = ZERO_VECTOR;
vector  orig_size  = ZERO_VECTOR;
vector  prim_size  = ZERO_VECTOR;
string  BLANK      = "5b53359e-59dd-d8a2-04c3-9e65134da47a";
vector  curr_position;
string  HomePage   = "https://www.youtube.com/@missyrestless/playlists";
string  front_texture;
string  back_texture;
string  linksetValue;
string  menuMessage;
string  selected_dir  = "";
string  shape = "Box";

// Linkset Data Keys
//
// All or Solo linkset data key
string  SOLO_LSD_KEY      = "solo";
// Prim Size linkset data key
string  SIZE_LSD_KEY      = "size";
// Original Prim Size linkset data key
string  ORIGSIZE_LSD_KEY  = "original_size";
//  Prim Position linkset data key
string  POSITION_LSD_KEY  = "position";
// Original Prim Textures linkset data key
string  ORIGTEXT_LSD_KEY  = "original_textures";
// Prim Textures linkset data key
string  TEXTURES_LSD_KEY  = "textures";
// Group access linkset data key
string  GROUP_LSD_KEY     = "group";
// Double/Single sided linkset data key
string  DOUBLE_LSD_KEY    = "double_sided";
// Front face texture linkset data key
string  ZERO_LSD_KEY      = "front_texture";
// Back face texture linkset data key
string  FIVE_LSD_KEY      = "back_texture";
// Opaque/Transparent linkset data key
string  STATUS_LSD_KEY    = "status";

setFacesAlpha(float trans) {
    integer i;
    for (i = 0; i < total_faces; ++i)
    {
        llSetAlpha(trans, llList2Integer(faces, i));
    }
}

set_faces() {
    string currentTex;
    string DEFAULT_PLYWOOD     = "89556747-24cb-43ed-920b-47caed15465f";
    string TTRANSPARENT        = "8dcd4a48-2d37-4909-9f78-f7a9eb4ef903";
    string WHITE_TEXTURE       = "5748decc-f629-461c-9a36-a35a221fe21f";

    integer numOfSides = llGetNumberOfSides();
    integer i;
    // Find which faces are textured with non-default textures
    faces = [];
    texts = [];
    for (i = 0; i < numOfSides; ++i) {
        currentTex = llGetTexture(i);
        if ((currentTex != DEFAULT_PLYWOOD) &&
            (currentTex != TTRANSPARENT) &&
            (currentTex != BLANK) &&
            (currentTex != WHITE_TEXTURE) &&
            (currentTex != "*Default Transparent Texture") &&
            (currentTex != NULL_KEY)) {
            faces += i;
            texts += [i, currentTex];
        }
    }
    total_faces  = llGetListLength(faces);
}

lowerShield() {
    float alpha = 1.0;
    while(alpha > 0.0) {
        alpha -= 0.1;
        setFacesAlpha(alpha);
        llSleep(cloakSpeed);
    }
    llSetAlpha(0.0, ALL_SIDES);
    llSetStatus(STATUS_PHANTOM, TRUE);
    shieldStatus = FALSE;
}

raiseShield() {
    float alpha = 0.0;
    integer count = 0;

    if (FLASH) {
        while (count < 4) {
            count += 1;
            if (alpha == 0.0) {
                alpha = 1.0;
            } else {
                alpha = 0.0;
            }
            llSetAlpha(alpha, ALL_SIDES);
            llSleep(1.0);
        }
    }
    alpha = 0.0;
    llSetAlpha(alpha, ALL_SIDES);
    while (alpha < 1.0) {
        alpha += 0.1;
        setFacesAlpha(alpha);
        llSleep(cloakSpeed);
    }
    if (SOLID) {
        llSetStatus(STATUS_PHANTOM, FALSE);
    } else {
        llSetStatus(STATUS_PHANTOM, TRUE);
    }
    shieldStatus = TRUE;
}

move_shield(string dir, float amt) {
    if (dir == "X") {
        curr_position.x += amt;
    } else if (dir == "Y") {
        curr_position.y += amt;
    } else if (dir == "Z") {
        curr_position.z += amt;
    }
    llSetRegionPos(curr_position);
}

string getShieldSlurl() {
    vector currentPos = llGetPos();
    string regionName = llGetRegionName();

    // Round coordinates to whole integers
    integer x = (integer)currentPos.x;
    integer y = (integer)currentPos.y;
    integer z = (integer)currentPos.z;
    string coords = (string)x + "/" + (string)y + "/" + (string)z;

    // Return the constructed Slurl, escape region name as it may have spaces
    return "https://maps.secondlife.com/secondlife/" + llEscapeURL(regionName) + "/" + coords;
}

sidedShield() {
    string prefix = "Truth & Beauty Privacy Shield version " + VERSION;
    string slurl = getShieldSlurl();
    string location = " at " + slurl;
    string msg;

    if (DOUBLE) {
        llSetTexture(llGetTexture(side_one), side_two);
        if (shieldStatus) {
            llSetAlpha(1.0, side_two);
        }
        msg = prefix + location + " is set to DOUBLE SIDED";
    } else {
        llSetTexture(BLANK, side_two);
        llSetAlpha(0.0, side_two);
        msg = prefix + location + " is set to SINGLE SIDED";
    }
    // Reset the faces list with newly set faces
    set_faces();
    // If shield is up reset the alpha on the textured faces
    if (tcher == owner) {
        llOwnerSay(msg);
    } else {
        if (tcher) {
            llRegionSayTo(tcher, 0, msg);
        } else {
            llOwnerSay(msg);
        }
    }
    linksetDataWrite(NULL_KEY, DOUBLE_LSD_KEY, (string)DOUBLE, "Double/Single Sided");
}

stateShield() {
    string prefix = "Truth & Beauty Privacy Shield version " + VERSION;
    string slurl = getShieldSlurl();
    string location = " at " + slurl;
    string msg;
    string phantom;

    if (llGetStatus(STATUS_PHANTOM)) {
        phantom = "PHANTOM";
    } else {
        phantom = "SOLID";
    }
    if (shieldStatus) {
        msg = prefix + location + " is UP and " + phantom;
    } else {
        msg = prefix + location + " is DOWN and " + phantom;
    }

    if (tcher == owner) {
        llOwnerSay(msg);
    } else {
        if (tcher) {
            llRegionSayTo(tcher, 0, msg);
        } else {
            llOwnerSay(msg);
        }
    }
}

string getPrimType() {
    // Query the primitive parameters for the prim type
    list primParams = llGetPrimitiveParams([PRIM_TYPE]);
    // The first element in the returned list is always the type flag
    integer primType = llList2Integer(primParams, 0);
        
    // Identify the shape type
    if (primType == PRIM_TYPE_BOX)             return "Box";
    else if (primType == PRIM_TYPE_CYLINDER)   return "Cylinder";
    else if (primType == PRIM_TYPE_PRISM)      return "Prism";
    else if (primType == PRIM_TYPE_SPHERE)     return "Sphere";
    else if (primType == PRIM_TYPE_TORUS)      return "Torus";
    else if (primType == PRIM_TYPE_TUBE)       return "Tube";
    else if (primType == PRIM_TYPE_RING)       return "Ring";
    else if (primType == PRIM_TYPE_SCULPT)     return "Sculpt";
    else                                       return "Unknown";
}

list get_Textures() {
    list texture_list = [];
    integer count = llGetInventoryNumber(INVENTORY_TEXTURE);

    // Populate list of inventory texture names
    integer i;
    for (i = 0; i < count; ++i) {
        texture_list += llGetInventoryName(INVENTORY_TEXTURE, i);
    }
    return texture_list;
}

list arrange(list l) {
    list outl = [];
    integer n = llGetListLength(l);
    do {
        if (n < 3) return outl + l;
        n = n - 3;
        outl = outl + llList2List(l, -3, -1);
        if (n == 0) return outl;
        l = llList2List(l, 0, -4);
    } while (TRUE);
    return [];
}

displayConfMenu() {
    llListenRemove(dialogHandle);
    dialogHandle = llListen(dialogChannel, "", tcher, "");
    list conf_menu = [];

    menuMessage = "\nTruth & Beauty Privacy Shield " + VERSION + "\n";
    if (GROUP) {
        menuMessage += "\nOWNER = Owner only access";
    } else {
        menuMessage += "\nGROUP = Allow group members to manage";
    }
    if (FLASH) {
        menuMessage += "\nNO FLASH = Do not flash when activating shield";
    } else {
        menuMessage += "\nFLASH = Flash 3 times when activating shield";
    }
    if (SOLID) {
        menuMessage += "\nPHANTOM = Shields always phantom";
    } else {
        menuMessage += "\nSOLID = Active shields are solid";
    }
    if (TOUCH) {
        menuMessage += "\nTOUCH OFF = Touch opens dialog menu\n";
    } else {
        menuMessage += "\nTOUCH ON = Touch to raise/lower shields\n";
    }
    conf_menu = ["UP", "DOWN", "INFO"];
    if (GROUP) {
        conf_menu += ["OWNER"];
    } else {
        conf_menu += ["GROUP"];
    }
    if (FLASH) {
        conf_menu += ["NO FLASH"];
    } else {
        conf_menu += ["FLASH"];
    }
    if (SOLID) {
        conf_menu += ["PHANTOM"];
    } else {
        conf_menu += ["SOLID"];
    }
    if (TOUCH) {
        conf_menu += ["TOUCH OFF"];
    } else {
        conf_menu += ["TOUCH ON"];
    }
    conf_menu += ["BACK", "EXIT"];
    ShowMenu(menuMessage, conf_menu);
}

displayMainMenu() {
    llListenRemove(dialogHandle);
    dialogHandle = llListen(dialogChannel, "", tcher, "");
    list main_menu = [];

    menuMessage = "\nTruth & Beauty Privacy Shield " + VERSION;
    if (ALL) {
        menuMessage += "\nMenu actions effect ALL SHIELDS IN REGION\n";
        menuMessage += "\nSOLO = Menu actions effect only this shield";
    } else {
        menuMessage += "\nMenu actions effect ONLY THIS SHIELD\n";
        menuMessage += "\nALL = Menu actions effect all shields in region";
    }
    // 1-Sided Shield or 2-Sided
    if (DOUBLE) {
        menuMessage += "\nONE SIDE = Sets Single Sided texturing";
    } else {
        menuMessage += "\nTWO SIDES = Sets Double Sided texturing";
    }
    menuMessage += "\nSETTINGS = Open the Shield settings menu";
    menuMessage += "\nSIZE = Open the Shield resize menu";
    menuMessage += "\nTEXTURE = Open the Shield texture menu";
    main_menu = ["UP", "DOWN", "INFO"];
    if (ALL) {
        main_menu += ["SOLO"];
    } else {
        main_menu += ["ALL"];
    }
    if (DOUBLE) {
        main_menu += ["ONE SIDE"];
    } else {
        main_menu += ["TWO SIDES"];
    }
    main_menu += ["POSITiON", "ROTATION", "SETTINGS", "SIZE", "TEXTURE", "TV"];
    main_menu += ["EXIT"];
    ShowMenu(menuMessage, main_menu);
}

displayPosMenu() {
    llListenRemove(dialogHandle);
    dialogHandle = llListen(dialogChannel, "", tcher, "");
    list pos_menu = [];

    curr_position = llGetPos();
    menuMessage = "\nTruth & Beauty Privacy Shield Position Menu";
    menuMessage = "\nPosition this shield only\n";
    menuMessage += "\nCurrent shield position:";
    menuMessage += "\n\tX: " + (string) ( curr_position.x );
    menuMessage += "\n\tY: " + (string) ( curr_position.y );
    menuMessage += "\n\tZ: " + (string) ( curr_position.z );
    if (selected_dir == "") {
        menuMessage += "\nSelect a direction to position\n";
        pos_menu = ["X", "Y", "Z"];
    } else {
        menuMessage += "\nSelected direction: "  + selected_dir;
        menuMessage += "\nSelect an amount (in meters) to move in the " + selected_dir + " direction";
        menuMessage += " or change direction\n";
        if (selected_dir == "X") {
            pos_menu = ["X ✓", "Y", "Z"];
        } else if (selected_dir == "Y") {
            pos_menu = ["X", "Y ✓", "Z"];
        } else if (selected_dir == "Z") {
            pos_menu = ["X", "Y", "Z ✓"];
        }
        pos_menu += ["+0.1m", "-0.1m", "+1m", "-1m", "+5m", "-5m"];
    }
    pos_menu += ["BACK", "RESTORE", "EXIT"];
    ShowMenu(menuMessage, pos_menu);
}

displayRotMenu() {
    llListenRemove(dialogHandle);
    dialogHandle = llListen(dialogChannel, "", tcher, "");
    list rot_menu = [];

    rotation rot = llGetRot();
    menuMessage = "\nTruth & Beauty Privacy Shield Rotation Menu";
    menuMessage = "\nRotate this shield only\n";
    menuMessage += "\nCurrent shield rotation:";
    menuMessage += "\n\tX: " + (string) ( rot.x );
    menuMessage += "\n\tY: " + (string) ( rot.y );
    menuMessage += "\n\tZ: " + (string) ( rot.z );
    rot_menu = ["X", "Y", "Z", "ALIGN", "+45", "+90", "+180", "+270", "ZERO"];
    rot_menu += ["BACK", "RESTORE", "EXIT"];
    ShowMenu(menuMessage, rot_menu);
}

displayTvMenu() {
    llListenRemove(dialogHandle);
    dialogHandle = llListen(dialogChannel, "", tcher, "");
    list tv_menu = [];

    menuMessage = "\nTruth & Beauty Privacy Shield TV Menu\n";
    menuMessage += "\nCurrent TV Home: " + HomePage;
    tv_menu = ["TV ON", "TV OFF", "INPUT URL"];
    tv_menu += ["SET HOME", "BACK", "EXIT"];
    ShowMenu(menuMessage, tv_menu);
}

displaySizeMenu() {
    llListenRemove(dialogHandle);
    dialogHandle = llListen(dialogChannel, "", tcher, "");
    list size_menu = [];

    menuMessage = "\nTruth & Beauty Privacy Shield Resize Menu";
    menuMessage = "\nResize this shield only\n";
    menuMessage += "\nCurrent shield size (X=Width, Y=Height):";
    menuMessage += "\n\tX: " + (string) ( prim_size.x );
    menuMessage += "\n\tY: " + (string) ( prim_size.y );
    menuMessage += "\n\tZ: " + (string) ( prim_size.z );
    size_menu = ["24x12", "32x16", "40x20", "48x24", "56x28", "64x32"];
    size_menu += ["BACK", "RESTORE", "EXIT"];
    ShowMenu(menuMessage, size_menu);
}

displayTextMenu() {
    integer total = llGetListLength(faces);
    list face_menu = [];
    list text_menu = [];

    llListenRemove(dialogHandle);
    dialogHandle = llListen(dialogChannel, "", tcher, "");

    menuMessage = "\nTruth & Beauty Privacy Shield Texture Menu";

    // Populate the Face menu entries, if only one textured face set selected face
    integer i;
    if (total > 1) {
        for (i = 0; i < total; ++i) {
            face_menu += "Face " + llList2String(faces, i);
        }
    } else {
        selected_face = llList2Integer(faces, 0);
        llSetPrimitiveParams([PRIM_GLOW, selected_face, 0.3]);
    }

    // Populate the inventory textures menu entries
    text_menu = get_Textures();
    if (text_menu) {
        if (selected_face == -1) {
            menuMessage += "\nSelect a face to retexture\n";
        } else {
            if (ALL) {
                menuMessage += "\nTexture ALL SHIELDS IN REGION\n";
                menuMessage += "\nSOLO = Apply selected texture to only this shield";
            } else {
                menuMessage += "\nTexture THIS SHIELD ONLY\n";
                menuMessage += "\nALL = Apply selected texture to all shields";
            }
            menuMessage += "\nFLIP HORIZ = Flip texture horizontally";
            menuMessage += "\nFLIP VERT  = Flip texture vertically\n";
            menuMessage += "\nCurrent texture: " + llGetTexture(selected_face) + "\n";
            menuMessage += "\nSelect the texture to use on face " + (string)selected_face + "\n";
            face_menu = ["BACK", "RESTORE", "EXIT"];
            if (ALL) {
                face_menu += ["SOLO"];
            } else {
                face_menu += ["ALL"];
            }
            face_menu += ["FLIP HORIZ", "FLIP VERT"];
            if (isTransparent) {
                face_menu += ["OPAQUE"];
            } else {
                face_menu += ["TRANSPARENT"];
            }
            face_menu += text_menu;
        }
        face_menu += ["BACK", "RESTORE", "EXIT"];
    } else {
        menuMessage += "\nNO TEXTURES FOUND\n";
    }
    ShowMenu(menuMessage, face_menu);
}

// Show the specific menu page
// Pass in the full menu list
ShowMenu(string msg, list fm) {
    integer list_length = llGetListLength(fm);
    if (list_length > 12) {
        integer totalPages = (list_length / 10) + (list_length % 10 != 0);

        // Safety check: bound page numbers
        if (pageNumber < 1) pageNumber = 1;
        if (pageNumber > totalPages) pageNumber = totalPages;

        integer nump = 12;
        if (pageNumber > 1) nump--;
        if (pageNumber < totalPages) nump--;

        // Calculate slice indices
        integer start = (pageNumber - 1) * nump;
        integer end = start + (nump -1);

        // Grab the 10 (or fewer) items for this page
        list displayList = llList2List(fm, start, end);

        // Add navigation buttons to the bottom of the list
        if (totalPages > 1) {
            if (pageNumber > 1) displayList += ["<<< Prev"];
            if (pageNumber < totalPages) displayList += ["Next >>>"];
        }

        // Send the dialog page
        llDialog(tcher, msg + " (Page " + (string)pageNumber + " of " +
                (string)totalPages + "):", arrange(displayList), dialogChannel);
    } else {
        // Send the dialog
        llDialog(tcher, msg, arrange(fm), dialogChannel);
    }
    llSetTimerEvent(120);   // If no response in time, return to previous state
}

GetDatastoreValues() {
    //
    // Retrieve any configuration values stored in the linkset datastore
    //
    // All or Solo linkset data key
    linksetValue = llLinksetDataRead(SOLO_LSD_KEY);
    if (linksetValue != "") {
        ALL = (integer)linksetValue;
    }
    // Prim Size linkset data key
    linksetValue = llLinksetDataRead(SIZE_LSD_KEY);
    if (linksetValue != "") {
        prim_size = (vector)linksetValue;
    }
    // Original Prim Size linkset data key
    linksetValue = llLinksetDataRead(ORIGSIZE_LSD_KEY);
    if (linksetValue != "") {
        orig_size = (vector)linksetValue;
    }
    //  Prim Position linkset data key
    linksetValue = llLinksetDataRead(POSITION_LSD_KEY);
    if (linksetValue != "") {
        curr_position = (vector)linksetValue;
    }
    // Original Prim Textures linkset data key
    linksetValue = llLinksetDataRead(ORIGTEXT_LSD_KEY);
    if (linksetValue != "") {
        origt = llCSV2List(linksetValue);
    }
    // Prim Textures linkset data key
    linksetValue = llLinksetDataRead(TEXTURES_LSD_KEY);
    if (linksetValue != "") {
        texts = llCSV2List(linksetValue);
    }
    // Group access linkset data key
    linksetValue = llLinksetDataRead(GROUP_LSD_KEY);
    if (linksetValue != "") {
        GROUP = (integer)linksetValue;
    }
    // Double/Single sided linkset data key
    linksetValue = llLinksetDataRead(DOUBLE_LSD_KEY);
    if (linksetValue != "") {
        DOUBLE = (integer)linksetValue;
    }
    // Front texture (Face 0)
    linksetValue = llLinksetDataRead(ZERO_LSD_KEY);
    if ((linksetValue != "") && (llGetInventoryType(linksetValue) == INVENTORY_TEXTURE)) {
        front_texture = linksetValue;
    }
    // Back texture (Face 5)
    linksetValue = llLinksetDataRead(FIVE_LSD_KEY);
    if ((linksetValue != "") && (llGetInventoryType(linksetValue) == INVENTORY_TEXTURE)) {
        back_texture = linksetValue;
    }
    // Transparency
    linksetValue = llLinksetDataRead(STATUS_LSD_KEY);
    if (linksetValue != "") {
        shieldStatus = (integer)linksetValue;
    }
}

SetDatastoreValues(key id) {
    //
    // Set all configuration values stored in the linkset datastore
    // Called from on_rez and when Save button is clicked
    //
    // All or Solo linkset data key
    linksetDataWrite(id, SOLO_LSD_KEY, (string)ALL, "All or Solo Shield");
    // Prim Size linkset data key
    linksetDataWrite(id, SIZE_LSD_KEY, (string)prim_size, "Shield Size");
    //  Prim Position linkset data key
    linksetDataWrite(id, POSITION_LSD_KEY, (string)curr_position, "Shield Position");
    // Prim Textures linkset data key
    linksetDataWrite(id, TEXTURES_LSD_KEY, llList2CSV(texts), "Shield Textures");
    // Group access linkset data key
    linksetDataWrite(id, GROUP_LSD_KEY, (string)GROUP, "Group Access");
    // Double/Single sided linkset data key
    linksetDataWrite(id, DOUBLE_LSD_KEY, (string)DOUBLE, "Double/Single Sided");
    // Front texture (Face 0)
    linksetDataWrite(id, ZERO_LSD_KEY, (string)front_texture, "Front Side Texture");
    // Back texture (Face 5)
    linksetDataWrite(id, FIVE_LSD_KEY, (string)back_texture, "Back Side Texture");
    // Transparency
    linksetDataWrite(id, STATUS_LSD_KEY, (string)shieldStatus, "Shield Status");
}

// Writes the provided key/value pair to the prim's linkset datastore
integer linksetDataWrite(key id, string lsdKey, string value, string cfg) {
    string val = llStringTrim(value, STRING_TRIM);
    integer returnCode = llLinksetDataWrite(lsdKey, val);
    if (returnCode == LINKSETDATA_OK) {
        if (id) {
            llRegionSayTo(id, 0, "[Privacy Shield] " + cfg + " saved.");
        }
    } else if (returnCode != LINKSETDATA_NOUPDATE) {
        if (id) {
            llRegionSayTo(id, 0, "[Privacy Shield] " + cfg + " save failed (code " + (string)returnCode + ").");
        }
    }
    return returnCode;
}

processMessage(integer chn, string msg) {
    string cmd = llToLower(msg);
    if (chn == listenChannel) {
        if (cmd == "shields down") {
            // Send the message to other objects in region with same owner listening on this channel
            llRegionSay(objChannel, "Shields Down");
            lowerShield();
        } else if (cmd == "shields up") {
            // Send the message to other objects in region with same owner listening on this channel
            llRegionSay(objChannel, "Shields Up");
            raiseShield();
        } else if (cmd == "shields info") {
            // Send the message to other objects in region with same owner listening on this channel
            llRegionSay(objChannel, "Shields Info");
            stateShield();
        }
    } else if (chn == objChannel) {
        // Don't resend the message if we are receiving a message on this channel
        if (cmd == "shields down") {
            lowerShield();
        } else if (cmd == "shields up") {
            raiseShield();
        } else if (cmd == "shields info") {
            stateShield();
        } else if (cmd == "shields one") {
            DOUBLE = FALSE;
            sidedShield();
        } else if (cmd == "shields two") {
            DOUBLE = TRUE;
            sidedShield();
        } else if (cmd == "group") {
            GROUP = TRUE;
            linksetDataWrite(NULL_KEY, GROUP_LSD_KEY, (string)GROUP, "Group Access");
        } else if (cmd == "owner") {
            GROUP = FALSE;
            linksetDataWrite(NULL_KEY, GROUP_LSD_KEY, (string)GROUP, "Group Access");
        } else if (cmd == "flash off") {
            FLASH = FALSE;
        } else if (cmd == "flash on") {
            FLASH = TRUE;
        } else if (cmd == "phantom") {
            SOLID = FALSE;
            llSetStatus(STATUS_PHANTOM, TRUE);
        } else if (cmd == "solid") {
            SOLID = TRUE;
            llSetStatus(STATUS_PHANTOM, FALSE);
        } else if (cmd == "touch off") {
            TOUCH = FALSE;
        } else if (cmd == "touch on") {
            TOUCH = TRUE;
        } else if (llJsonValueType(msg, []) != JSON_INVALID) {
            string txt = llJsonGetValue(msg, ["texture"]);
            string fce = llJsonGetValue(msg, ["face"]);
            if (llGetInventoryType(txt) == INVENTORY_TEXTURE) {
                llSetTexture(txt, (integer)fce);
            } else {
                llRegionSayTo(tcher, 0, "The texture is missing or not a texture: " + txt);
            }
        }
    }
}


default {
    state_entry() {
        owner        = llGetOwner();
        tcher        = NULL_KEY;
        defaultState = TRUE;

        // Only support Box and Tube currently
        shape = getPrimType();
        if (shape == "Tube") {
            side_two = 2;
        } else {
            side_two = 5;
        }
        front_texture = llGetTexture(side_one);
        back_texture = llGetTexture(side_two);

        GetDatastoreValues();
        if (llGetAlpha(ALL_SIDES) > 0.0) {
            shieldStatus = TRUE;
        } else {
            shieldStatus = FALSE;
        }
        // Set default prim size if not yet set
        if (prim_size != ZERO_VECTOR) {
            prim_size = llGetScale();
        }
        if ((def_size_x == -1.0) || (def_size_y == -1.0)) {
            def_size_x = prim_size.x;
            def_size_y = prim_size.y;
        }
        // If the original size list did not get initialized in on_rez()
        if (orig_size != ZERO_VECTOR) {
            orig_size = llGetScale();
            // Original Prim Size linkset data key
            linksetDataWrite(owner, ORIGSIZE_LSD_KEY, (string)orig_size, "Original Shield Size");
        }

        set_faces();
        // If the original textures list did not get initialized in on_rez()
        if (!llGetListLength(origt)) {
            origt = texts;
            // Original Prim Textures linkset data key
            linksetDataWrite(owner, ORIGTEXT_LSD_KEY, llList2CSV(origt), "Original Shield Textures");
        }
        // Compute a large negative channel number based on the object owner
        // All screens owned by the same owner will use the same channel
        objChannel = 0x80000000 | (integer) ( "0x" + (string) owner );
        llListenRemove(listenerID);
        listenerID = llListen(listenChannel, "", owner, "");
        llListenRemove(objListenID);
        objListenID = llListen(objChannel, "", NULL_KEY, "");
        // Compute a negative communications channel based on prim UUID
        dialogChannel = 0x80000000 | (integer) ( "0x" + (string) llGetKey() );
        // Alternatively, generate a negative non-zero number from the last 7 digits of the prim UUID
        // dialogChannel = -1 - (integer)("0x" + llGetSubString( (string) llGetKey(), -7, -1) );
    }

    listen(integer channel, string name, key id, string message) {
        processMessage(channel, message);
        string cmd = llToLower(message);

        if (cmd == "shields down") {
            state cloaked;
        }
    }

    moving_end() {
        curr_position = llGetPos();
        linksetDataWrite(owner, POSITION_LSD_KEY, (string)curr_position, "Shield Position");
    }

    timer() {
        llSetTimerEvent(0.0);
    }

    touch_start(integer num_detected) {
        tcher = llDetectedKey(0);
        // Ensure only the owner or group members triggers the timer start check
        if (GROUP) {
            if ((llDetectedGroup(0)) || (tcher == owner)) {
                llResetTime(); // Starts tracking duration
            } else {
                tcher = NULL_KEY;
            }
        } else {
            if (tcher == owner) {
                llResetTime(); // Starts tracking duration
            } else {
                tcher = NULL_KEY;
            }
        }
    }

    touch_end(integer num_detected) {
        float holdTime = llGetTime();
        if (GROUP) {
            if ((llDetectedGroup(0)) || (tcher == owner)) {
                if (TOUCH) {
                    if (holdTime >= 1.0) {
                        // Long press for dialog menu
                        // Handle dialog menu in its own state
                        state menu;
                    } else {
                        if (llGetAlpha(ALL_SIDES) > 0.0) {
                            llRegionSay(objChannel, "Shields Down");
                            lowerShield();
                            state cloaked;
                        } else {
                            llRegionSay(objChannel, "Shields Up");
                            raiseShield();
                            state default;
                        }
                    }
                } else {
                    // If shield touch is disabled, display dialog menu on clicks as well
                    state menu;
                }
            }
        } else {
            if (tcher == owner) {
                if (TOUCH) {
                    if (holdTime >= 1.0) {
                        // Long press for dialog menu
                        // Handle dialog menu in its own state
                        state menu;
                    } else {
                        if (llGetAlpha(ALL_SIDES) > 0.0) {
                            llRegionSay(objChannel, "Shields Down");
                            lowerShield();
                            state cloaked;
                        } else {
                            llRegionSay(objChannel, "Shields Up");
                            raiseShield();
                            state default;
                        }
                    }
                } else {
                    // If shield touch is disabled, display dialog menu on clicks as well
                    state menu;
                }
            }
        }
    }

    on_rez(integer num) {
        llResetScript();
        owner = llGetOwner();
        // Only support Box and Tube currently
        shape = getPrimType();
        if (shape == "Tube") {
            side_two = 2;
        } else {
            side_two = 5;
        }
        raiseShield();
        string slurl = getShieldSlurl();
        llOwnerSay("The Truth & Beauty Privacy Shield located at " + slurl + " is now active.");
        llOwnerSay("Activate the 'Shields Up', 'Shields Down', and 'Shields Info' gestures in your inventory");
        llOwnerSay("Once activated, saying '/up' in public chat will enable all sheilds you own in this region");
        llOwnerSay("Saying '/down' will disable the shields and make them phantom");
        llOwnerSay("Saying '/info' will report their status, version, and locations");
        llOwnerSay("Privacy Shield updates are free for life and will be available at:");
        llOwnerSay("    https://github.com/missyrestless/PrivacyShield/releases");
        llOwnerSay("The latest Truth & Beauty Privacy Shield documentation can be found at:");
        llOwnerSay("    https://github.com/missyrestless/PrivacyShield#readme");

        prim_size = llGetScale();
        def_size_x = prim_size.x;
        def_size_y = prim_size.y;
        linksetDataWrite(owner, ORIGSIZE_LSD_KEY, (string)prim_size, "Original Shield Size");

        linksetValue = llLinksetDataRead(POSITION_LSD_KEY);
        if (linksetValue != "") {
            curr_position = (vector)linksetValue;
            llSetRegionPos(curr_position);
        } else {
            curr_position = llGetPos();
        }
        set_faces();
        origt = texts;
        // Original Prim Textures linkset data key
        linksetDataWrite(owner, ORIGTEXT_LSD_KEY, llList2CSV(origt), "Original Shield Textures");

        linksetValue = llLinksetDataRead(SOLO_LSD_KEY);
        if (linksetValue != "") {
            ALL = (integer)linksetValue;
        } else {
            ALL = TRUE;
        }
        linksetValue = llLinksetDataRead(GROUP_LSD_KEY);
        if (linksetValue != "") {
            GROUP = (integer)linksetValue;
        } else {
            GROUP = FALSE;
        }
        linksetValue = llLinksetDataRead(DOUBLE_LSD_KEY);
        if (linksetValue != "") {
            DOUBLE = (integer)linksetValue;
        } else {
            DOUBLE = FALSE;
        }
        front_texture = llGetTexture(side_one);
        back_texture = llGetTexture(side_two);
        SetDatastoreValues(owner);
    }

    changed(integer change) {
        // Check if the change event was caused by an owner change
        if (change & CHANGED_OWNER) {
            // Reset/wipe all key-value pairs in the linkset data store
            llLinksetDataReset();
            llResetScript();
        } else if (change & CHANGED_INVENTORY) {
            llResetScript();
        }
    }
}

state cloaked {
    state_entry() {
        defaultState = FALSE;
        tcher = NULL_KEY;
        llListenRemove(listenerID);
        listenerID = llListen(listenChannel, "", owner, "");
        llListenRemove(objListenID);
        objListenID = llListen(objChannel, "", NULL_KEY, "");
    }

    listen(integer channel, string name, key id, string message) {
        processMessage(channel, message);

        string cmd = llToLower(message);
        if (cmd == "shields up") {
            state default;
        }
    }

    timer() {
        llSetTimerEvent(0.0);
    }

    touch_start(integer num_detected) {
        tcher = llDetectedKey(0);
        // Ensure only the owner or group members triggers the timer start check
        if (GROUP) {
            if ((llDetectedGroup(0)) || (tcher == owner)) {
                llResetTime(); // Starts tracking duration
            } else {
                tcher = NULL_KEY;
            }
        } else {
            if (tcher == owner) {
                llResetTime(); // Starts tracking duration
            } else {
                tcher = NULL_KEY;
            }
        }
    }

    touch_end(integer num_detected) {
        float holdTime = llGetTime();
        if (GROUP) {
            if ((llDetectedGroup(0)) || (tcher == owner)) {
                if (TOUCH) {
                    if (holdTime >= 1.0) {
                        // Long press for dialog menu
                        state menu;
                    } else {
                        if (llGetAlpha(ALL_SIDES) > 0.0) {
                            llRegionSay(objChannel, "Shields Down");
                            lowerShield();
                            state cloaked;
                        } else {
                            llRegionSay(objChannel, "Shields Up");
                            raiseShield();
                            state default;
                        }
                    }
                } else {
                    // If shield touch is disabled, click gets dialog menu too
                    state menu;
                }
            }
        } else {
            if (tcher == owner) {
                if (TOUCH) {
                    if (holdTime >= 1.0) {
                        // Long press for dialog menu
                        state menu;
                    } else {
                        if (llGetAlpha(ALL_SIDES) > 0.0) {
                            llRegionSay(objChannel, "Shields Down");
                            lowerShield();
                            state cloaked;
                        } else {
                            llRegionSay(objChannel, "Shields Up");
                            raiseShield();
                            state default;
                        }
                    }
                } else {
                    // If shield touch is disabled, click gets dialog menu too
                    state menu;
                }
            }
        }
    }
}

state menu
{
    state_entry() {
        displayMainMenu();
    }

    listen(integer channel, string name, key id, string message) {
        if (message == "UP") {
            if (ALL) {
                // Send the message to other objects in region with same owner listening on this channel
                llRegionSay(objChannel, "Shields Up");
            }
            raiseShield();
            defaultState = TRUE;
        } else if (message == "DOWN") {
            if (ALL) {
                // Send the message to other objects in region with same owner
                llRegionSay(objChannel, "Shields Down");
            }
            lowerShield();
            defaultState = FALSE;
        } else if (message == "INFO") {
            if (ALL) {
                // Send the message to other objects in region with same owner listening on this channel
                llRegionSay(objChannel, "Shields Info");
            }
            stateShield();
        } else if (message == "ONE SIDE") {
            DOUBLE = FALSE;
            if (ALL) {
                // Send the message to other objects in region with same owner listening on this channel
                llRegionSay(objChannel, "Shields One");
            }
            sidedShield();
        } else if (message == "TWO SIDES") {
            DOUBLE = TRUE;
            if (ALL) {
                // Send the message to other objects in region with same owner listening on this channel
                llRegionSay(objChannel, "Shields Two");
            }
            sidedShield();
        } else if (message == "ALL") {
            ALL = TRUE;
            linksetDataWrite(tcher, SOLO_LSD_KEY, (string)ALL, "All or Solo Shield");
        } else if (message == "SOLO") {
            ALL = FALSE;
            linksetDataWrite(tcher, SOLO_LSD_KEY, (string)ALL, "All or Solo Shield");
        } else if (message == "SIZE") {
            state size;
        } else if (message == "TEXTURE") {
            state text;
        } else if (message == "GROUP") {
            if (id == owner) {
                if (ALL) {
                    // Send the message to other objects in region with same owner listening on this channel
                    llRegionSay(objChannel, "Group");
                }
                GROUP = TRUE;
                linksetDataWrite(NULL_KEY, GROUP_LSD_KEY, (string)GROUP, "Group Access");
            } else {
                if (id) llRegionSayTo(id, 0, "Only the owner can set the shields to group access");
            }
        } else if (message == "OWNER") {
            if (id == owner) {
                if (ALL) {
                    // Send the message to other objects in region with same owner listening on this channel
                    llRegionSay(objChannel, "Owner");
                }
                GROUP = FALSE;
                linksetDataWrite(NULL_KEY, GROUP_LSD_KEY, (string)GROUP, "Group Access");
            } else {
                if (id) llRegionSayTo(id, 0, "Only the owner can set the shields to owner only");
            }
        } else if (message == "POSITION") {
            state pos;
        } else if (message == "ROTATION") {
            state rot;
        } else if (message == "SETTINGS") {
            state tv;
        } else if (message == "TV") {
            state settings;
        } else if (message == "EXIT") {
            // Return to the previous state
            if (defaultState) {
                state default;
            } else {
                state cloaked;
            }
        }
        // Re-send the dialog to keep the menu open
        displayMainMenu();
    }

    timer() {
        // Return to the previous state
        if (defaultState) {
            state default;
        } else {
            state cloaked;
        }
    }

    state_exit() {
        SetDatastoreValues(tcher);
        llSetTimerEvent(0);
    }
}

state pos
{
    state_entry() {
        orig_pos = curr_position;
        displayPosMenu();
    }

    listen(integer channel, string name, key id, string message) {
        if ((message == "X") || (message == "Y") || (message == "Z")) {
            selected_dir = message;
        } else if (message == "+0.1m") {
            move_shield(selected_dir, 0.1);
        } else if (message == "-0.1m") {
            move_shield(selected_dir, -0.1);
        } else if (message == "+1m") {
            move_shield(selected_dir, 1.0);
        } else if (message == "-1m") {
            move_shield(selected_dir, -1.0);
        } else if (message == "+5m") {
            move_shield(selected_dir, 5.0);
        } else if (message == "-5m") {
            move_shield(selected_dir, -5.0);
        } else if (message == "RESTORE") {
            llSetRegionPos(orig_pos);
        } else if (message == "BACK") {
            state menu;
        } else if (message == "EXIT") {
            // Return to the previous state
            if (defaultState) {
                state default;
            } else {
                state cloaked;
            }
        }
        // Re-send the dialog to keep the menu open
        displayPosMenu();
    }

    timer() {
        // Return to the previous state
        if (defaultState) {
            state default;
        } else {
            state cloaked;
        }
    }

    state_exit() {
        SetDatastoreValues(tcher);
        llSetTimerEvent(0);
    }
}

state rot
{
    state_entry() {
        displayRotMenu();
    }

    listen(integer channel, string name, key id, string message) {
        if (message == "24x12") {
        } else if (message == "32x16") {
        } else if (message == "RESTORE") {
            linksetValue = llLinksetDataRead(ORIGSIZE_LSD_KEY);
            if (linksetValue != "") {
            } else {
                linksetDataWrite(owner, ORIGSIZE_LSD_KEY, (string)prim_size, "Original Shield Size");
            }
        } else if (message == "BACK") {
            state menu;
        } else if (message == "EXIT") {
            // Return to the previous state
            if (defaultState) {
                state default;
            } else {
                state cloaked;
            }
        }
        if (shape == "Tube") {
            // Tube size reverses X & Y, Z is same as Y
            prim_size.y = prim_size.x;
        }
        // Re-send the dialog to keep the menu open
        displayRotMenu();
    }

    timer() {
        // Return to the previous state
        if (defaultState) {
            state default;
        } else {
            state cloaked;
        }
    }

    state_exit() {
        SetDatastoreValues(tcher);
        llSetTimerEvent(0);
    }
}

state tv
{
    state_entry() {
        displayTvMenu();
    }

    listen(integer channel, string name, key id, string message) {
        if (message == "24x12") {
        } else if (message == "32x16") {
        } else if (message == "RESTORE") {
            linksetValue = llLinksetDataRead(ORIGSIZE_LSD_KEY);
            if (linksetValue != "") {
            } else {
                linksetDataWrite(owner, ORIGSIZE_LSD_KEY, (string)prim_size, "Original Shield Size");
            }
        } else if (message == "BACK") {
            state menu;
        } else if (message == "EXIT") {
            // Return to the previous state
            if (defaultState) {
                state default;
            } else {
                state cloaked;
            }
        }
        if (shape == "Tube") {
            // Tube size reverses X & Y, Z is same as Y
            prim_size.y = prim_size.x;
        }
        // Re-send the dialog to keep the menu open
        displayTvMenu();
    }

    timer() {
        // Return to the previous state
        if (defaultState) {
            state default;
        } else {
            state cloaked;
        }
    }

    state_exit() {
        SetDatastoreValues(tcher);
        llSetTimerEvent(0);
    }
}

state settings
{
    state_entry() {
        displayConfMenu();
    }

    listen(integer channel, string name, key id, string message) {
        if (message == "UP") {
            if (ALL) {
                // Send the message to other objects in region with same owner listening on this channel
                llRegionSay(objChannel, "Shields Up");
            }
            raiseShield();
            defaultState = TRUE;
        } else if (message == "DOWN") {
            if (ALL) {
                // Send the message to other objects in region with same owner
                llRegionSay(objChannel, "Shields Down");
            }
            lowerShield();
            defaultState = FALSE;
        } else if (message == "INFO") {
            if (ALL) {
                // Send the message to other objects in region with same owner listening on this channel
                llRegionSay(objChannel, "Shields Info");
            }
            stateShield();
        } else if (message == "NO FLASH") {
            if (ALL) {
                // Send the message to other objects in region with same owner listening on this channel
                llRegionSay(objChannel, "Flash Off");
            }
            FLASH = FALSE;
        } else if (message == "FLASH") {
            if (ALL) {
                // Send the message to other objects in region with same owner listening on this channel
                llRegionSay(objChannel, "Flash On");
            }
            FLASH = TRUE;
        } else if (message == "SOLID") {
            if (ALL) {
                // Send the message to other objects in region with same owner listening on this channel
                llRegionSay(objChannel, "Solid");
            }
            SOLID = TRUE;
            llSetStatus(STATUS_PHANTOM, FALSE);
        } else if (message == "PHANTOM") {
            if (ALL) {
                // Send the message to other objects in region with same owner listening on this channel
                llRegionSay(objChannel, "Phantom");
            }
            SOLID = FALSE;
            llSetStatus(STATUS_PHANTOM, TRUE);
        } else if (message == "TOUCH OFF") {
            if (ALL) {
                // Send the message to other objects in region with same owner listening on this channel
                llRegionSay(objChannel, "Touch Off");
            }
            TOUCH = FALSE;
        } else if (message == "TOUCH ON") {
            if (ALL) {
                // Send the message to other objects in region with same owner listening on this channel
                llRegionSay(objChannel, "Touch On");
            }
            TOUCH = TRUE;
        } else if (message == "BACK") {
            state menu;
        } else if (message == "EXIT") {
            // Return to the previous state
            if (defaultState) {
                state default;
            } else {
                state cloaked;
            }
        }
        // Re-send the dialog to keep the menu open
        displayConfMenu();
    }

    timer() {
        // Return to the previous state
        if (defaultState) {
            state default;
        } else {
            state cloaked;
        }
    }

    state_exit() {
        SetDatastoreValues(tcher);
        llSetTimerEvent(0);
    }
}

state size
{
    state_entry() {
        prim_size = llGetScale();
        displaySizeMenu();
    }

    listen(integer channel, string name, key id, string message) {
        if (message == "24x12") {
            prim_size.x = 24.0;
            prim_size.y = 12.0;
        } else if (message == "32x16") {
            prim_size.x = 32.0;
            prim_size.y = 16.0;
        } else if (message == "40x20") {
            prim_size.x = 40.0;
            prim_size.y = 20.0;
        } else if (message == "48x24") {
            prim_size.x = 48.0;
            prim_size.y = 24.0;
        } else if (message == "56x28") {
            prim_size.x = 56.0;
            prim_size.y = 28.0;
        } else if (message == "64x32") {
            prim_size.x = 64.0;
            prim_size.y = 32.0;
        } else if (message == "RESTORE") {
            linksetValue = llLinksetDataRead(ORIGSIZE_LSD_KEY);
            if (linksetValue != "") {
                orig_size = (vector)linksetValue;
                prim_size = orig_size;
            } else {
                prim_size.x = def_size_x;
                prim_size.y = def_size_y;
                linksetDataWrite(owner, ORIGSIZE_LSD_KEY, (string)prim_size, "Original Shield Size");
            }
        } else if (message == "BACK") {
            state menu;
        } else if (message == "EXIT") {
            // Return to the previous state
            if (defaultState) {
                state default;
            } else {
                state cloaked;
            }
        }
        if (shape == "Tube") {
            // Tube size reverses X & Y, Z is same as Y
            prim_size.z = prim_size.y;
            prim_size.y = prim_size.x;
            prim_size.x = prim_size.z;
            prim_size.z = prim_size.y;
        }
        llSetScale(prim_size);
        // Re-send the dialog to keep the menu open
        displaySizeMenu();
    }

    timer() {
        // Return to the previous state
        if (defaultState) {
            state default;
        } else {
            state cloaked;
        }
    }

    state_exit() {
        SetDatastoreValues(tcher);
        llSetTimerEvent(0);
    }
}

state text
{
    state_entry() {
        selected_face = -1;
        displayTextMenu();
    }

    listen(integer channel, string name, key id, string message) {
        vector scale_vector;
        if ("Face " == llGetSubString(message, 0, 4)) {
            // Face #
            selected_face = (integer)(llGetSubString(message, 5, -1));
            llSetPrimitiveParams([PRIM_GLOW, ALL_SIDES, 0.0]);
            llSetPrimitiveParams([PRIM_GLOW, selected_face, 0.3]);
        } else if (message == "ALL") {
            ALL = TRUE;
            linksetDataWrite(tcher, SOLO_LSD_KEY, (string)ALL, "All or Solo Shield");
        } else if (message == "SOLO") {
            ALL = FALSE;
            linksetDataWrite(tcher, SOLO_LSD_KEY, (string)ALL, "All or Solo Shield");
        } else if (message == "FLIP HORIZ") {
            // Flips the texture horizontally on selected face, keeping vertical scale
            scale_vector = llGetTextureScale(selected_face);
            llScaleTexture(-(scale_vector.x), scale_vector.y, selected_face);
        } else if (message == "FLIP VERT") {
            // Flips the texture vertically on selected face, keeping horizontal scale
            scale_vector = llGetTextureScale(selected_face);
            llScaleTexture(scale_vector.x, -(scale_vector.y), selected_face);
        } else if (message == "OPAQUE") {
            llSetAlpha(1.0, selected_face);
            isTransparent = FALSE;
        } else if (message == "TRANSPARENT") {
            llSetAlpha(0.0, selected_face);
            isTransparent = TRUE;
        } else if (message == "RESTORE") {
            linksetValue = llLinksetDataRead(ORIGTEXT_LSD_KEY);
            if (linksetValue != "") {
                origt = llCSV2List(linksetValue);
                texts = origt;
            } else {
                linksetDataWrite(owner, ORIGTEXT_LSD_KEY, llList2CSV(texts), "Original Shield Textures");
                origt = texts;
            }
            integer len = llGetListLength(origt);
            if (len == 0) {
                origt = texts;
                len = llGetListLength(origt);
            }
            integer i = 0;
            while (i < len) {
                llSetTexture(llList2String(origt, i + 1), llList2Integer(origt, i));
                i += 2; // Jump to the next stride
            }
        } else if (message == "BACK") {
            state menu;
        // Handle pagination for multi page menus
        } else if (message == "<<< Prev") {
            pageNumber--;
        } else if (message == "Next >>>") {
            pageNumber++;
        } else if (message == "EXIT") {
            // Return to the previous state
            if (defaultState) {
                state default;
            } else {
                state cloaked;
            }
        } else {
            if (llGetInventoryType(message) == INVENTORY_TEXTURE) {
                if (selected_face == -1) {
                    llRegionSayTo(tcher, 0, "Select a face to texture first");
                    state warn;
                } else {
                    llSetTexture(message, selected_face);
                    if (ALL) {
                        // Pack the 2 key/value pairs as a JSON string
                        llRegionSay(objChannel, llList2Json(JSON_OBJECT, ["texture", message, "face", (string)selected_face]));
                    }
                }
            } else {
                llRegionSayTo(tcher, 0, "The texture is missing or not a texture: " + message);
            }
        }
        // Re-send the dialog to keep the menu open
        displayTextMenu();
    }

    timer() {
        // Return to the previous state
        if (defaultState) {
            state default;
        } else {
            state cloaked;
        }
    }

    state_exit() {
        llSetPrimitiveParams([PRIM_GLOW, ALL_SIDES, 0.0]);
        front_texture = llGetTexture(side_one);
        back_texture = llGetTexture(side_two);
        SetDatastoreValues(tcher);
        llSetTimerEvent(0);
    }
}

state warn
{
    state_entry() {
        integer warnChannel = -999999;
        llListenRemove(warnHandle);
        warnHandle = llListen(warnChannel, "", tcher, "");

        llDialog(tcher, "\nSelect a face to texture first\n", ["OK"], warnChannel);
        llSetTimerEvent(30.0); // 30-second timer
    }

    listen(integer channel, string name, key id, string message) {
        llSetTimerEvent(0.0);       // Stop timer
        llListenRemove(warnHandle); // Remove listener
        state text;
    }

    timer() {
        llSetTimerEvent(0.0);       // Stop timer
        llListenRemove(warnHandle); // Remove listener
        state text;
    }
}
