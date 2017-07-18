/*********************************
For the main html chat area
*********************************/

//Precaching a bunch of shit
GLOBAL_DATUM_INIT(iconCache, /savefile, new("data/iconCache.sav")) //Cache of icons for the browser output

//On client, created on login
/datum/chatOutput
	var/client/owner	 //client ref
	var/loaded       = FALSE // Has the client loaded the browser output area?
	var/list/messageQueue //If they haven't loaded chat, this is where messages will go until they do
	var/cookieSent   = FALSE // Has the client sent a cookie for analysis
	var/broken       = FALSE
	var/list/connectionHistory //Contains the connection history passed from chat cookie

/datum/chatOutput/New(client/C)
	owner = C
	messageQueue = list()
	connectionHistory = list()

/datum/chatOutput/proc/start()
	//Check for existing chat
	if(!owner)
		return FALSE

	if(!winexists(owner, "browseroutput")) // Oh goddamnit.
		set waitfor = FALSE
		broken = TRUE
		message_admins("Couldn't start chat for [key_name_admin(owner)]!")
		. = FALSE
		alert(owner.mob, "Updated chat window does not exist. If you are using a custom skin file please allow the game to update.")
		return

	if(winget(owner, "browseroutput", "is-visible") == "true") //Already setup
		doneLoading()

	else //Not setup
		load()

	return TRUE

/datum/chatOutput/proc/load()
	set waitfor = FALSE
	if(!owner)
		return

	var/datum/asset/stuff = get_asset_datum(/datum/asset/simple/goonchat)
	stuff.register()
	stuff.send(owner)

	owner << browse(file('code/modules/goonchat/browserassets/html/browserOutput.html'), "window=browseroutput")

/datum/chatOutput/Topic(href, list/href_list)
	if(usr.client != owner)
		return TRUE

	// Build arguments.
	// Arguments are in the form "param[paramname]=thing"
	var/list/params = list()
	for(var/key in href_list)
		if(length(key) > 7 && findtext(key, "param")) // 7 is the amount of characters in the basic param key template.
			var/param_name = copytext(key, 7, -1)
			var/item       = href_list[key]

			params[param_name] = item

	var/data // Data to be sent back to the chat.
	switch(href_list["proc"])
		if("doneLoading")
			data = doneLoading(arglist(params))

		if("debug")
			data = debug(arglist(params))

		if("ping")
			data = ping(arglist(params))

		if("analyzeClientData")
			data = analyzeClientData(arglist(params))

	if(data)
		ehjax_send(data = data)


//Called on chat output done-loading by JS.
/datum/chatOutput/proc/doneLoading()
	if(loaded)
		return

	testing("Chat loaded for [owner.ckey]")
	loaded = TRUE
	showChat()


	for(var/message in messageQueue)
		to_chat(owner, message)

	messageQueue = null
	sendClientData()

	//do not convert to to_chat()
	owner << {"<span class="userdanger">If you can see this, update byond.</span>"}

	pingLoop()

/datum/chatOutput/proc/showChat()
	winset(owner, "output", "is-visible=false")
	winset(owner, "browseroutput", "is-disabled=false;is-visible=true")

/datum/chatOutput/proc/pingLoop()
	set waitfor = FALSE

	while (owner)
		ehjax_send(data = owner.is_afk(29) ? "softPang" : "pang") // SoftPang isn't handled anywhere but it'll always reset the opts.lastPang.
		sleep(30)

/datum/chatOutput/proc/ehjax_send(client/C = owner, window = "browseroutput", data)
	if(islist(data))
		data = json_encode(data)
	C << output("[data]", "[window]:ehjaxCallback")

//Sends client connection details to the chat to handle and save
/datum/chatOutput/proc/sendClientData()
	//Get dem deets
	var/list/deets = list("clientData" = list())
	deets["clientData"]["ckey"] = owner.ckey
	deets["clientData"]["ip"] = owner.address
	deets["clientData"]["compid"] = owner.computer_id
	var/data = json_encode(deets)
	ehjax_send(data = data)

//Called by client, sent data to investigate (cookie history so far)
/datum/chatOutput/proc/analyzeClientData(cookie = "")
	if(!cookie)
		return

	if(cookie != "none")
		var/list/connData = json_decode(cookie)
		if (connData && islist(connData) && connData.len > 0 && connData["connData"])
			connectionHistory = connData["connData"] //lol fuck
			var/list/found = new()
			for(var/i in connectionHistory.len to 1 step -1)
				var/list/row = src.connectionHistory[i]
				if (!row || row.len < 3 || (!row["ckey"] || !row["compid"] || !row["ip"])) //Passed malformed history object
					return
				if (world.IsBanned(row["ckey"], row["compid"], row["ip"]))
					found = row
					break

			//Uh oh this fucker has a history of playing on a banned account!!
			if (found.len > 0)
				//TODO: add a new evasion ban for the CURRENT client details, using the matched row details
				message_admins("[key_name(src.owner)] has a cookie from a banned account! (Matched: [found["ckey"]], [found["ip"]], [found["compid"]])")
				log_admin_private("[key_name(owner)] has a cookie from a banned account! (Matched: [found["ckey"]], [found["ip"]], [found["compid"]])")

	cookieSent = TRUE

//Called by js client every 60 seconds
/datum/chatOutput/proc/ping()
	return "pong"

//Called by js client on js error
/datum/chatOutput/proc/debug(error)
	log_world("\[[time2text(world.realtime, "YYYY-MM-DD hh:mm:ss")]\] Client: [(src.owner.key ? src.owner.key : src.owner)] triggered JS error: [error]")

//Global chat procs

//Converts an icon to base64. Operates by putting the icon in the iconCache savefile,
// exporting it as text, and then parsing the base64 from that.
// (This relies on byond automatically storing icons in savefiles as base64)
/proc/icon2base64(icon/icon, iconKey = "misc")
	if (!isicon(icon))
		return FALSE
	GLOB.iconCache[iconKey] << icon
	var/iconData = GLOB.iconCache.ExportText(iconKey)
	var/list/partial = splittext(iconData, "{")
	return replacetext(copytext(partial[2], 3, -5), "\n", "")

/proc/bicon(thing)
	if (!thing)
		return

	if (isicon(thing))
		//Icons get pooled constantly, references are no good here.
		/*if (!bicon_cache["\ref[obj]"]) // Doesn't exist yet, make it.
			bicon_cache["\ref[obj]"] = icon2base64(obj)
		return "<img class='icon misc' src='data:image/png;base64,[bicon_cache["\ref[obj]"]]'>"*/
		return "<img class='icon misc' src='data:image/png;base64,[icon2base64(thing)]'>"

	// Either an atom or somebody fucked up and is gonna get a runtime, which I'm fine with.
	var/atom/A = thing
	var/key = "[istype(A.icon, /icon) ? "\ref[A.icon]" : A.icon]:[A.icon_state]"

	var/static/list/bicon_cache = list()
	if (!bicon_cache[key]) // Doesn't exist, make it.
		var/icon/I = icon(A.icon, A.icon_state, SOUTH, 1)
		if (ishuman(thing)) // Shitty workaround for a BYOND issue.
			var/icon/temp = I
			I = icon()
			I.Insert(temp, dir = SOUTH)
		bicon_cache[key] = icon2base64(I, key)

	return "<img class='icon [A.icon_state]' src='data:image/png;base64,[bicon_cache[key]]'>"

//Costlier version of bicon() that uses getFlatIcon() to account for overlays, underlays, etc. Use with extreme moderation, ESPECIALLY on mobs.
/proc/costly_bicon(thing)
	if (!thing)
		return

	if (isicon(thing))
		return bicon(thing)

	var/icon/I = getFlatIcon(thing)
	return bicon(I)

/proc/to_chat(target, message)
	if(!target)
		return

	//Ok so I did my best but I accept that some calls to this will be for shit like sound and images
	//It stands that we PROBABLY don't want to output those to the browser output so just handle them here
	if (istype(message, /image) || istype(message, /sound) || istype(target, /savefile))
		target << message
		CRASH("Invalid message! [message]")

	if(!istext(message))
		return

	if(target == world)
		target = GLOB.clients

	var/list/targets
	if(!islist(target))
		targets = list(target)
	else
		targets = target
		if(!targets.len)
			return
	var/original_message = message
	//Some macros remain in the string even after parsing and fuck up the eventual output
	message = replacetext(message, "\improper", "")
	message = replacetext(message, "\proper", "")
	message = replacetext(message, "\n", "<br>")
	message = replacetext(message, "\t", "[GLOB.TAB][GLOB.TAB]")
	message = replacetext(message, "À", "&#1040;")
	message = replacetext(message, "Á", "&#1041;")
	message = replacetext(message, "Â", "&#1042;")
	message = replacetext(message, "Ã", "&#1043;")
	message = replacetext(message, "Ä", "&#1044;")
	message = replacetext(message, "Å", "&#1045;")
	message = replacetext(message, "Æ", "&#1046;")
	message = replacetext(message, "Ç", "&#1047;")
	message = replacetext(message, "È", "&#1048;")
	message = replacetext(message, "É", "&#1049;")
	message = replacetext(message, "Ê", "&#1050;")
	message = replacetext(message, "Ë", "&#1051;")
	message = replacetext(message, "Ì", "&#1052;")
	message = replacetext(message, "Í", "&#1053;")
	message = replacetext(message, "Î", "&#1054;")
	message = replacetext(message, "Ï", "&#1055;")
	message = replacetext(message, "Ð", "&#1056;")
	message = replacetext(message, "Ñ", "&#1057;")
	message = replacetext(message, "Ò", "&#1058;")
	message = replacetext(message, "Ó", "&#1059;")
	message = replacetext(message, "Ô", "&#1060;")
	message = replacetext(message, "Õ", "&#1061;")
	message = replacetext(message, "Ö", "&#1062;")
	message = replacetext(message, "×", "&#1063;")
	message = replacetext(message, "Ø", "&#1064;")
	message = replacetext(message, "Ù", "&#1065;")
	message = replacetext(message, "Ú", "&#1066;")
	message = replacetext(message, "Û", "&#1067;")
	message = replacetext(message, "Ü", "&#1068;")
	message = replacetext(message, "Ý", "&#1069;")
	message = replacetext(message, "Þ", "&#1070;")
	message = replacetext(message, "ß", "&#1071;")
	message = replacetext(message, "à", "&#1072;")
	message = replacetext(message, "á", "&#1073;")
	message = replacetext(message, "â", "&#1074;")
	message = replacetext(message, "ã", "&#1075;")
	message = replacetext(message, "ä", "&#1076;")
	message = replacetext(message, "å", "&#1077;")
	message = replacetext(message, "æ", "&#1078;")
	message = replacetext(message, "ç", "&#1079;")
	message = replacetext(message, "è", "&#1080;")
	message = replacetext(message, "é", "&#1081;")
	message = replacetext(message, "ê", "&#1082;")
	message = replacetext(message, "ë", "&#1083;")
	message = replacetext(message, "ì", "&#1084;")
	message = replacetext(message, "í", "&#1085;")
	message = replacetext(message, "î", "&#1086;")
	message = replacetext(message, "ï", "&#1087;")
	message = replacetext(message, "ð", "&#1088;")
	message = replacetext(message, "ñ", "&#1089;")
	message = replacetext(message, "ò", "&#1090;")
	message = replacetext(message, "ó", "&#1091;")
	message = replacetext(message, "ô", "&#1092;")
	message = replacetext(message, "õ", "&#1093;")
	message = replacetext(message, "ö", "&#1094;")
	message = replacetext(message, "÷", "&#1095;")
	message = replacetext(message, "ø", "&#1096;")
	message = replacetext(message, "ù", "&#1097;")
	message = replacetext(message, "ú", "&#1098;")
	message = replacetext(message, "û", "&#1099;")
	message = replacetext(message, "ü", "&#1100;")
	message = replacetext(message, "ý", "&#1101;")
	message = replacetext(message, "þ", "&#1102;")
	message = replacetext(message, "¸", "&#1105;")
	message = replacetext(message, "¨", "&#1025;")

	for(var/I in targets)
		//Grab us a client if possible
		var/client/C = grab_client(I)

		if (!C)
			continue

		//Send it to the old style output window.
		C << original_message

		if(!C.chatOutput || C.chatOutput.broken) // A player who hasn't updated his skin file.
			continue

		if(!C.chatOutput.loaded)
			//Client still loading, put their messages in a queue
			C.chatOutput.messageQueue += message
			continue

		// url_encode it TWICE, this way any UTF-8 characters are able to be decoded by the Javascript.
		C << output(url_encode(url_encode(message)), "browseroutput:output")

/proc/grab_client(target)
	if(istype(target, /client))
		return target
	else if(ismob(target))
		var/mob/M = target
		if(M.client)
			return M.client
	else if(istype(target, /datum/mind))
		var/datum/mind/M = target
		if(M.current && M.current.client)
			return M.current.client
