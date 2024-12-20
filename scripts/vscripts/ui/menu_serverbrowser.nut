function main()
{
    // Global functions
    Globalize( InitServerBrowserMenu )
    Globalize( OnServerBrowserMenu )
    Globalize( RefreshServerList )
	Globalize( OpenDirectConnectDialog_Activate )
    Globalize(UpdateShownPage)
    Globalize(FilterAndUpdateList)
    Globalize(FilterServerList)
    
    // File-level variables
    file.menu <- null
    file.buttons <- null
    file.serversName <- null
    file.playerCountLabels <- null
    file.serversMap <- null
    file.serversGamemode <- null
    file.currentChoice <- 0
    file.serverList <- []
    file.scrollOffset <- 0 
    file.serversArrayFiltered <- []
    file.searchBox <- null
    file.hideFullBox <- null
    file.hideEmptyBox <- null
    
    // Search/filter state
    file.searchTerm <- ""
    file.useSearch <- false
    file.hideFull <- false
    file.hideEmpty <- false
    
    // Direction for sorting
    file.sortDirection <- {
        serverName = true,
        serverPlayers = true,
        serverMap = true,
        serverGamemode = true
    }
}

function OpenDirectConnectDialog_Activate( button )
{
	if ( uiGlobal.activeDialog )
		return

	local dialogData = {}
	dialogData.header <- "Connect To Address..."
    dialogData.detailsMessage <- "R1Delta multiplayer is currently not finished, but there is some buggy early testing going on.\n ^1 Do not connect to servers you do not trust."

	OpenChoiceDialog( dialogData, GetMenu( "DirectConnectDialog" ) )
	// local inputs = []
	// 	// Gamepad
	// inputs.append( BUTTON_A )
	// inputs.append( BUTTON_START )

	// // Keyboard/Mouse
	// inputs.append( KEY_ENTER )

	// foreach ( input in inputs )
	// 	RegisterButtonPressedCallback( input, ConnectToDirectServer )
}

function ConnectToDirectServer( button )
{
	if ( !uiGlobal.activeDialog )
		return

    local str = uiGlobal.activeDialog.GetChild( "LblConnectTo" ).GetTextEntryUTF8Text()

	if(str == "")
		return

	ClientCommand( "connect " + str )
	CloseDialog( true )
}

function InitServerBrowserMenu( menu )
{
    file.menu = menu
    uiGlobal.menu <- menu
    file.dialog <- GetMenu( "DirectConnectDialog" )
    file.lblConnectTo <- file.dialog.GetChild( "LblConnectTo" )
    // Get menu elements 
    file.buttons = GetElementsByClassname( menu, "ServerButton" )
    printt("buttons: " + file.buttons)
    file.serversName = GetElementsByClassname( menu, "ServerName" )
    file.playerCountLabels = GetElementsByClassname( menu, "PlayerCount" ) 
    file.serversMap = GetElementsByClassname( menu, "ServerMap" )
    file.serversGamemode = GetElementsByClassname( menu, "ServerGamemode" )
   	file.serverList <- []
	uiGlobal.serverList <- []
    uiGlobal.serversArrayFiltered <- []
    // Setup buttons
    AddEventHandlerToButtonClass( menu, "ServerButton", UIE_CLICK, OnServerButtonClicked )
    AddEventHandlerToButtonClass( menu, "ServerButton", UIE_GET_FOCUS, OnServerButtonFocused )

    // Add handlers for filtering
    AddEventHandlerToButtonClass( menu, "BtnServerNameTab", UIE_CLICK, SortServerListByName )
    AddEventHandlerToButtonClass( menu, "BtnServerPlayersTab", UIE_CLICK, SortServerListByPlayers )
    AddEventHandlerToButtonClass( menu, "BtnServerMapTab", UIE_CLICK, SortServerListByMap )
    AddEventHandlerToButtonClass( menu, "BtnServerGamemodeTab", UIE_CLICK, SortServerListByGamemode )
    
    // Scroll buttons
    AddEventHandlerToButtonClass( menu, "BtnServerListUpArrow", UIE_CLICK, OnScrollUp )
    AddEventHandlerToButtonClass( menu, "BtnServerListDownArrow", UIE_CLICK, OnScrollDown )
    // Get other UI elements
    // In InitServerBrowserMenu:
    file.hideFullBox = menu.GetChild( "SwtBtnHideFull" )
    file.hideEmptyBox = menu.GetChild( "SwtBtnHideEmpty" )
    AddEventHandlerToButtonClass(menu , "SwtBtnHideFull",UIE_CLICK, HideFullHandler )
    AddEventHandlerToButtonClass(menu , "SwtBtnHideEmpty",UIE_CLICK, HideEmptyHandler )

    AddEventHandlerToButton( GetMenu( "DirectConnectDialog" ), "BtnConnect", UIE_CLICK, OnDirectConnectDialogButtonConnect_Activate )
    AddEventHandlerToButton( GetMenu( "DirectConnectDialog" ), "BtnCancel", UIE_CLICK, OnDirectConnectDialogButtonCancel_Activate )

    file.searchBox = menu.GetChild( "BtnServerSearch" )
    file.buttons = GetElementsByClassname( menu, "ServerButton" )

    // Initialize mouse wheel handlers
    RegisterButtonPressedCallback( MOUSE_WHEEL_UP, OnMouseWheelUp )
    RegisterButtonPressedCallback( MOUSE_WHEEL_DOWN, OnMouseWheelDown )
    // Initialize filter state
    RefreshServerList(null)
}



function Threaded_GetServerList()
{
	local retries = 0

	while(file.serverList.len() <= 0 && retries < 5) {

		local list = GetServerList()

		if(list == null)
		{
			WaitFrame()
			continue
		}

		file.serverList <- GetServerList()
		retries += 1
		wait 1
	}

    printt("serverList: " + file.serverList.len())

	uiGlobal.serverList <- file.serverList
}


function RefreshServerList(_button)
{
    local list = GetServerList()
    if(list == null) {
        printl("No servers found")  
        list = []
    }
    file.serverList = list

    foreach(names in file.serversName)
    {
        names.SetVisible(false)
    }

    foreach(playerCount in file.playerCountLabels)
    {
        playerCount.SetVisible(false)
    }

    foreach(map in file.serversMap)
    {
        map.SetVisible(false)
    }

    foreach(gamemode in file.serversGamemode)
    {
        gamemode.SetVisible(false)
    }
    
    FilterAndUpdateList()
}

function FilterAndUpdateList()
{
    file.searchTerm = "" //file.searchBox.GetText()
    file.useSearch = file.searchTerm != ""
    file.hideFull = file.hideFullBox.IsSelected() //file.hideFullBox.IsSelected()
    file.hideEmpty = file.hideEmptyBox.IsSelected()
    
    file.scrollOffset = 0
    FilterServerList()
    
    UpdateShownPage()
}

function FilterServerList()
{
    file.serversArrayFiltered.clear()
    uiGlobal.serversArrayFiltered.clear()
    foreach ( server in file.serverList )
    {
        printt("server: " + server)
        // Skip if filters don't match
        if (file.hideEmpty && server.players.len() == 0)
            continue
            
        if (file.hideFull && server.players.len() >= server.max_players)
            continue
            
        if (file.useSearch)
        {
            if (server.host_name.tolower().find(file.searchTerm.tolower()) == null)
                continue
        }
        
        file.serversArrayFiltered.append(server)
        uiGlobal.serversArrayFiltered.append(server)
    }

    printt("serversArrayFiltered: " + file.serversArrayFiltered.len())
}

function UpdateShownPage()
{
    local BUTTONS_PER_PAGE = 10
    
    // Reset all buttons first
    for ( local i = 0; i < BUTTONS_PER_PAGE; i++ )
    {
        file.buttons[i].Hide()
        file.serversName[i].SetVisible(false)
        file.playerCountLabels[i].SetVisible(false)
        file.serversMap[i].SetVisible(false)
        file.serversGamemode[i].SetVisible(false)

    }
    
    // Show server info for current page
    local endIndex = file.serversArrayFiltered.len() > 10 ? 10 : file.serversArrayFiltered.len()
    
    printt(file.serverList.len())
    for ( local i = 0; i < endIndex; i++ )
    {
        local buttonIndex = file.scrollOffset + i
        local server = file.serversArrayFiltered[buttonIndex]
        printt("server: " + server)
        file.buttons[i].Show()
        file.serversName[i].SetText( server.host_name )
        file.playerCountLabels[i].SetText( format( "%i/%i", server.players.len(), server.max_players ) )
        if(server.map_name == "mp_lobby") {
            file.serversMap[i].SetText("Lobby")
        } else {
        file.serversMap[i].SetText("#" +  server.map_name )
        }
        file.serversGamemode[i].SetText( "#GAMEMODE_" + server.game_mode )
        file.serversName[i].SetVisible(true)
        file.playerCountLabels[i].SetVisible(true)
        file.serversMap[i].SetVisible(true)
        file.serversGamemode[i].SetVisible(true)
    }
}

function OnServerButtonClicked(button)
{
    local scriptID = button.GetScriptID().tointeger()
    local serverIndex = scriptID
    
    if (serverIndex >= uiGlobal.serversArrayFiltered.len())
        return
        
    local server = uiGlobal.serversArrayFiltered[serverIndex]

    ClientCommand( "connect " + server.ip + ":" + server.port )

}

function DisplayFocusedServerInfo(scriptID)
{
    local menu = file.menu
    local serverIndex = scriptID + file.scrollOffset
    
    if (serverIndex >= file.serversArrayFiltered.len())
        return
        
    local server = file.serversArrayFiltered[serverIndex]
    
    // Update info panel
    menu.GetChild("ServerName").SetText( server.host_name )
    menu.GetChild("NextMapName").SetText( GetMapDisplayName( server.map_name ) )
    menu.GetChild("NextMapImage").SetImage( "../ui/menu/lobby/lobby_image_" + server.map_name )
    
    // Show join button
    menu.GetChild("BtnServerJoin").Show()
}

function OnServerSelected()
{
    ConnectToServer()
}

function ConnectToServer()
{
    if (file.currentChoice >= file.serversArrayFiltered.len())
        return
        
    local server = file.serversArrayFiltered[file.currentChoice]
    ClientCommand( "connect " + server.ip + ":" + server.port )
}

function OnScrollDown()
{
    if (file.serversArrayFiltered.len() <= 15) return
    file.scrollOffset += 1
    if (file.scrollOffset + 15 > file.serversArrayFiltered.len())
        file.scrollOffset = file.serversArrayFiltered.len() - 15
        
    UpdateShownPage()
}

function OnScrollUp() 
{
    file.scrollOffset -= 1
    if (file.scrollOffset < 0)
        file.scrollOffset = 0
        
    UpdateShownPage()
}
// Add these functions to the previous server browser code:

function OnServerButtonFocused( button )
{
    local scriptID =  button.GetScriptID().tointeger()
    // local serverIndex = file.scrollOffset + scriptID
    local serverIndex = scriptID
    if ( serverIndex >= uiGlobal.serversArrayFiltered.len() )
        return
        
    local menu = uiGlobal.menu
    local server = uiGlobal.serversArrayFiltered[serverIndex]
    
    // Update preview panel
    menu.GetChild( "NextMapName" ).SetText( server.host_name )
    menu.GetChild( "NextMapDesc" ).SetText( "#GAMEMODE_" + server.game_mode )
    menu.GetChild( "StarsLabel" ).SetText( "#"+ server.map_name  )
    local players = server.players
    local maxPlayers = server.max_players || 12
    menu.GetChild("VersionLabel").SetText( players.len() + "/" + maxPlayers +  " players")

    menu.GetChild( "NextMapImage" ).SetImage( "../ui/menu/lobby/lobby_image_" + server.map_name )
    if(server.map_name == "mp_lobby") {
        menu.GetChild("StarsLabel").SetText( "Lobby")
		menu.GetChild("NextMapImage").SetImage("../ui/menu/common/menu_background_neutral")
    } 
    // Player info
    local playerCount = server.players.len()
    local maxPlayers = server.max_players
    menu.GetChild( "VersionLabel" ).SetText( playerCount + "/" + maxPlayers + " players" )
}

function OnServerBrowserMenu(menu)
{
    // Called when the menu is opened
    if ( !( "menu" in file ) )
        return
        
    local list = GetServerList()
    file.serverList = list

    thread Threaded_GetServerList()

    uiGlobal.menu <- menu
    file.menu = menu
    
    // Reset scroll and current selection
    file.scrollOffset = 0
    file.currentChoice = 0
    
    // Clear any previous filter settings
    file.searchTerm = ""
    // printt(file.searchBox.GetTextEntryUTF8Text())
    // if ( file.searchBox != null )
    //     file.searchBox.SetText( "" )
    
    // Update UI
    FilterAndUpdateList()
}

function SortServerListByName( button )
{
    file.sortDirection.serverName = !file.sortDirection.serverName
    
    file.serversArrayFiltered.sort(function(a, b) {
        if ( file.sortDirection.serverName )
            return a.host_name > b.host_name
        return a.host_name < b.host_name
    })
    
    UpdateShownPage()
}

function SortServerListByPlayers( button )
{
    file.sortDirection.serverPlayers = !file.sortDirection.serverPlayers
    
    file.serversArrayFiltered.sort(function(a, b) {
        if ( file.sortDirection.serverPlayers )
            return a.players.len() > b.players.len()
        return a.players.len() < b.players.len()
    })
    
    UpdateShownPage()
}

function SortServerListByMap( button )
{
    file.sortDirection.serverMap = !file.sortDirection.serverMap
    
    file.serversArrayFiltered.sort(function(a, b) {
        if ( file.sortDirection.serverMap )
            return GetMapDisplayName(a.map_name) > GetMapDisplayName(b.map_name)
        return GetMapDisplayName(a.map_name) < GetMapDisplayName(b.map_name)
    })
    
    UpdateShownPage()
}

function SortServerListByGamemode( button )
{
    file.sortDirection.serverGamemode = !file.sortDirection.serverGamemode
    
    file.serversArrayFiltered.sort(function(a, b) {
        if ( file.sortDirection.serverGamemode )
            return a.game_mode > b.game_mode
        return a.game_mode < b.game_mode
    })
    
    UpdateShownPage()
}

// Utility functions for mouse wheel scrolling
function OnMouseWheelUp(...)
{
    OnScrollUp()
}

function OnMouseWheelDown(...)
{
    OnScrollDown() 
}

// Register/deregister mouse wheel callbacks when menu opens/closes
function RegisterMouseWheelCallbacks()
{
    RegisterButtonPressedCallback( MOUSE_WHEEL_UP, OnMouseWheelUp )
    RegisterButtonPressedCallback( MOUSE_WHEEL_DOWN, OnMouseWheelDown )
}

function DeregisterMouseWheelCallbacks()
{
    DeregisterButtonPressedCallback( MOUSE_WHEEL_UP, OnMouseWheelUp )
    DeregisterButtonPressedCallback( MOUSE_WHEEL_DOWN, OnMouseWheelDown )
}

function HideFullHandler(button) {

    button.SetSelected( !button.IsSelected() )
    button.SetText( button.IsSelected() ? "ON" : "OFF" )
    FilterAndUpdateList()
    UpdateShownPage()
}

function HideEmptyHandler(button) {

    button.SetSelected( !button.IsSelected() )
    button.SetText( button.IsSelected() ? "ON" : "OFF" )
    FilterAndUpdateList()
    UpdateShownPage()
}

function OnDirectConnectDialogButtonConnect_Activate( button )
{
    local str = button.GetParent().GetChild( "LblConnectTo" ).GetTextEntryUTF8Text()

	if(str == "")
		return

    ClientCommand( "connect " + str )
	local input = []



	CloseDialog( true )
}

function OnDirectConnectDialogButtonCancel_Activate( button )
{
    CloseDialog( true )
}