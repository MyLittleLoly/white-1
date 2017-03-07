/client/proc/edit_admin_permissions()
	set category = "Admin"
	set name = "Permissions Panel"
	set desc = "Edit admin permissions"
	if(!check_rights(R_PERMISSIONS))
		return
	usr.client.holder.edit_admin_permissions()

/datum/admins/proc/edit_admin_permissions()
	if(!check_rights(R_PERMISSIONS))
		return

	var/output = {"<!DOCTYPE html>
<html>
<head>
<title>Permissions Panel</title>
<script type='text/javascript' src='search.js'></script>
<link rel='stylesheet' type='text/css' href='panels.css'>
</head>
<body onload='selectTextField();updateSearch();'>
<div id='main'><table id='searchable' cellspacing='0'>
<tr class='title'>
<th style='width:125px;text-align:right;'>CKEY <a class='small' href='?src=\ref[src];editrights=add'>\[+\]</a></th>
<th style='width:125px;'>RANK</th>
<th style='width:375px;'>PERMISSIONS</th>
<th style='width:100%;'>VERB-OVERRIDES</th>
</tr>
"}

	for(var/adm_ckey in admin_datums)
		var/datum/admins/D = admin_datums[adm_ckey]
		if(!D)
			continue

		var/rights = rights2text(D.rights," ")
		if(!rights)	rights = "*none*"

		output += "<tr>"
		output += "<td style='text-align:right;'>[adm_ckey] <a class='small' href='?src=\ref[src];editrights=remove;ckey=[adm_ckey]'>\[-\]</a></td>"
		output += "<td><a href='?src=\ref[src];editrights=rank;ckey=[adm_ckey]'>[D.rank]</a></td>"
		output += "<td><a class='small' href='?src=\ref[src];editrights=permissions;ckey=[adm_ckey]'>[rights]</a></td>"
		//output += "<td><a class='small' href='?src=\ref[src];editrights=permissions;ckey=[adm_ckey]'>[rights2text(0," ",D.rank.adds,D.rank.subs)]</a></td>"
		output += "</tr>"

	output += {"
</table></div>
<div id='top'><b>Search:</b> <input type='text' id='filter' value='' style='width:70%;' onkeyup='updateSearch();'></div>
</body>
</html>"}

	usr << browse(output,"window=editrights;size=900x650")

/datum/admins/proc/log_admin_rank_modification(adm_ckey, new_rank)
	if(config.admin_legacy_system)
		return

	if(!usr.client)
		return

	if (!check_rights(R_PERMISSIONS))
		return

	if(!dbcon.Connect())
		usr << "<span class='danger'>Failed to establish database connection.</span>"
		return

	if(!adm_ckey || !new_rank)
		return

	adm_ckey = ckey(adm_ckey)

	if(!adm_ckey)
		return

	if(!istext(adm_ckey) || !istext(new_rank))
		return

	var/DBQuery/query_get_admin = dbcon.NewQuery("SELECT id FROM [format_table_name("erro_admin")] WHERE ckey = '[adm_ckey]'")
	if(!query_get_admin.warn_execute())
		return

	var/new_admin = 1
	var/admin_id
	while(query_get_admin.NextRow())
		new_admin = 0
		admin_id = text2num(query_get_admin.item[1])

	if(new_admin)
		var/DBQuery/query_add_admin = dbcon.NewQuery("INSERT INTO `[format_table_name("erro_admin")]` (`id`, `ckey`, `rank`, `level`, `flags`) VALUES (null, '[adm_ckey]', '[new_rank]', -1, 0)")
		if(!query_add_admin.warn_execute())
			return
		var/DBQuery/query_add_admin_log = dbcon.NewQuery("INSERT INTO `[format_table_name("admin_log")]` (`id` ,`datetime` ,`adminckey` ,`adminip` ,`log` ) VALUES (NULL , NOW( ) , '[usr.ckey]', '[usr.client.address]', 'Added new admin [adm_ckey] to rank [new_rank]');")
		if(!query_add_admin_log.warn_execute())
			return
		usr << "<span class='adminnotice'>New admin added.</span>"
	else
		if(!isnull(admin_id) && isnum(admin_id))
			var/DBQuery/query_change_admin = dbcon.NewQuery("UPDATE `[format_table_name("erro_admin")]` SET rank = '[new_rank]' WHERE id = [admin_id]")
			if(!query_change_admin.warn_execute())
				return
			var/DBQuery/query_change_admin_log = dbcon.NewQuery("INSERT INTO `[format_table_name("admin_log")]` (`id` ,`datetime` ,`adminckey` ,`adminip` ,`log` ) VALUES (NULL , NOW( ) , '[usr.ckey]', '[usr.client.address]', 'Edited the rank of [adm_ckey] to [new_rank]');")
			if(!query_change_admin_log.warn_execute())
				return
			usr << "<span class='adminnnotice'>Admin rank changed.</span>"


/datum/admins/proc/log_admin_permission_modification(adm_ckey, new_permission)
	if(config.admin_legacy_system)
		return
	if(!usr.client)
		return
	if(check_rights(R_PERMISSIONS))
		return

	if(!dbcon.Connect())
		usr << "<span class='danger'>Failed to establish database connection.</span>"
		return

	if(!adm_ckey || !istext(adm_ckey) || !isnum(new_permission))
		return

	var/DBQuery/query_get_perms = dbcon.NewQuery("SELECT id, flags FROM [format_table_name("erro_admin")] WHERE ckey = '[adm_ckey]'")
	if(!query_get_perms.warn_execute())
		return

	var/admin_id
	while(query_get_perms.NextRow())
		admin_id = text2num(query_get_perms.item[1])

	if(!admin_id)
		return

	var/DBQuery/query_change_perms = dbcon.NewQuery("UPDATE `[format_table_name("erro_admin")]` SET flags = [new_permission] WHERE id = [admin_id]")
	if(!query_change_perms.warn_execute())
		return
	var/DBQuery/query_change_perms_log = dbcon.NewQuery("INSERT INTO `[format_table_name("admin_log")]` (`id` ,`datetime` ,`adminckey` ,`adminip` ,`log` ) VALUES (NULL , NOW( ) , '[usr.ckey]', '[usr.client.address]', 'Edit permission [rights2text(new_permission)] (flag = [new_permission]) to admin [adm_ckey]');")
	query_change_perms_log.warn_execute()
