/obj/structure/poddoor_assembly
	name = "blast door assembly"
	icon = 'icons/obj/doors/blastdoor.dmi'
	icon_state = "open"
	anchored = 0
	density = 1
	obj_integrity = 200
	max_integrity = 200
	var/state = 0
	var/obj/item/device/assembly/control/electronics = null
	var/created_name = null
	var/id = null

/obj/structure/poddoor_assembly/attackby(var/obj/item/W, mob/user, params)
	if(istype(W, /obj/item/weapon/pen))
		var/t = stripped_input(user, "Enter the name for the blast door.", src.name, src.created_name,MAX_NAME_LEN)
		if(!t)
			return
		if(!in_range(src, usr) && src.loc != usr)
			return
		created_name = t
	else if(istype(W, /obj/item/weapon/weldingtool) && !anchored )
		var/obj/item/weapon/weldingtool/WT = W
		if(WT.remove_fuel(0,user))
			user.visible_message("<span class='warning'>[user] disassembles the blast door assembly.</span>", \
								"You start to disassemble the blast door assembly...")
			playsound(src.loc, 'sound/items/Welder2.ogg', 50, 1)

			if(do_after(user, 40*W.toolspeed, target = src))
				if(!WT.isOn())
					return
				to_chat(user, "<span class='notice'>You disassemble the blast door assembly.</span>")
				deconstruct(TRUE)

	else if(istype(W, /obj/item/weapon/wrench))
		if(!anchored)
			var/blastdoor_check = 1
			for(var/obj/machinery/door/poddoor/D in loc)
				blastdoor_check = 0
				break
			if(blastdoor_check)
				playsound(src.loc, W.usesound, 100, 1)
				user.visible_message("[user] secures the blast door assembly to the floor.", \
									 "<span class='notice'>You start to secure the blast door assembly to the floor...</span>", \
									 "<span class='italics'>You hear wrenching.</span>")

				if(do_after(user, 40*W.toolspeed, target = src))
					if(src.anchored)
						return
					to_chat(user, "<span class='notice'>You secure the blast door assembly.</span>")
					src.name = "secured blast door assembly"
					src.anchored = 1
			else
				to_chat(user, "There is another blast door here!")

		else
			playsound(src.loc, W.usesound, 100, 1)
			user.visible_message("[user] unsecures the blast door assembly from the floor.", \
								 "<span class='notice'>You start to unsecure the blast door assembly from the floor...</span>", \
								 "<span class='italics'>You hear wrenching.</span>")
			if(do_after(user, 40*W.toolspeed, target = src))
				if(!anchored )
					return
				to_chat(user, "<span class='notice'>You unsecure the blast door assembly.</span>")
				name = "airlock assembly"
				anchored = 0

	else if(istype(W, /obj/item/stack/cable_coil) && state == 0 && anchored)
		var/obj/item/stack/cable_coil/C = W
		if (C.get_amount() < 5)
			to_chat(user, "<span class='warning'>You need five length of cable to wire the blast door assembly!</span>")
			return
		user.visible_message("[user] wires the blast door assembly.", \
							"<span class='notice'>You start to wire the blast door assembly...</span>")
		if(do_after(user, 40, target = src))
			if(C.get_amount() < 5 || state != 0) return
			C.use(5)
			src.state = 1
			to_chat(user, "<span class='notice'>You wire the blast door assembly.</span>")
			src.name = "wired blast door assembly"

	else if(istype(W, /obj/item/weapon/wirecutters) && state == 1 )
		playsound(src.loc, W.usesound, 100, 1)
		user.visible_message("[user] cuts the wires from the blast door assembly.", \
							"<span class='notice'>You start to cut the wires from the blast door assembly...</span>")

		if(do_after(user, 40*W.toolspeed, target = src))
			if(src.state != 1)
				return
			to_chat(user, "<span class='notice'>You cut the wires from the blast door assembly.</span>")
			new/obj/item/stack/cable_coil(get_turf(user), 1)
			src.state = 0
			src.name = "secured blast door assembly"

	else if(istype(W, /obj/item/device/assembly/control) && state == 1 )
		var/obj/item/device/assembly/control/SUKAKURWA = W
		user.visible_message("[user] installs the electronics into the blast door assembly.", \
							"<span class='notice'>You start to install electronics into the blast door assembly...</span>")
		if(do_after(user, 40, target = src))
			if(src.state != 1)
				return
			if(!user.drop_item())
				return
			SUKAKURWA.loc = src
			to_chat(user, "<span class='notice'>You install the blast door electronics.</span>")
			src.state = 2
			src.name = "near finished blast door assembly"
			src.id = SUKAKURWA.id
			src.electronics = SUKAKURWA

	else if(istype(W, /obj/item/weapon/crowbar) && state == 2 )
		playsound(src.loc, W.usesound, 100, 1)
		user.visible_message("[user] removes the electronics from the blast door assembly.", \
								"<span class='notice'>You start to remove electronics from the blast door assembly...</span>")

		if(do_after(user, 40*W.toolspeed, target = src))
			if( src.state != 2 )
				return
			to_chat(user, "<span class='notice'>You remove the blast door electronics.</span>")
			src.state = 1
			src.name = "wired blast door assembly"
			var/obj/item/device/assembly/control/ae
			if (!electronics)
				ae = new/obj/item/device/assembly/control(src.loc)
			else
				ae = electronics
				electronics = null
				ae.loc = src.loc

	else if(istype(W, /obj/item/weapon/screwdriver) && state == 2 )
		playsound(src.loc, W.usesound, 100, 1)
		user.visible_message("[user] finishes the blast door.", \
							 "<span class='notice'>You start finishing the blast door...</span>")

		if(do_after(user, 40*W.toolspeed, target = src))
			if(src.loc && state == 2)
				to_chat(user, "<span class='notice'>You finish the blast door.</span>")
				var/obj/machinery/door/poddoor/door = new/obj/machinery/door/poddoor
				door.id = src.id
				if(created_name)
					door.name = created_name
				src.electronics.loc = door
				door.loc = src.loc
				qdel(src)
	else
		return ..()