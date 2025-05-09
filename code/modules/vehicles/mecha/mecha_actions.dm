/***************** MECHA ACTIONS *****************/

/obj/vehicle/sealed/mecha/generate_action_type()
	. = ..()
	if(istype(., /datum/action/vehicle/sealed/mecha))
		var/datum/action/vehicle/sealed/mecha/mecha = .
		mecha.chassis = src

/datum/action/vehicle/sealed/mecha
	action_icon = 'icons/mob/actions/actions_mecha.dmi'
	///mech owner of this action
	var/obj/vehicle/sealed/mecha/chassis

/datum/action/vehicle/sealed/mecha/Destroy()
	chassis = null
	return ..()

/datum/action/vehicle/sealed/mecha/mech_eject
	name = "Eject From Mech"
	action_icon_state = "mech_eject"

/datum/action/vehicle/sealed/mecha/mech_eject/action_activate(trigger_flags)
	if(!owner)
		return
	if(!chassis || !(owner in chassis.occupants))
		return
	chassis.resisted_against(owner)

/datum/action/vehicle/sealed/mecha/mech_toggle_internals
	name = "Toggle Internal Airtank Usage"
	action_icon_state = "mech_internals_off"
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_MECHABILITY_TOGGLE_INTERNALS,
	)

/datum/action/vehicle/sealed/mecha/mech_toggle_internals/action_activate(trigger_flags)
	if(!owner || !chassis || !(owner in chassis.occupants))
		return

	if(!chassis.internal_tank) //Just in case.
		chassis.use_internal_tank = FALSE
		chassis.balloon_alert(owner, "no tank available!")
		chassis.log_message("Switch to internal tank failed. No tank available.", LOG_MECHA)
		return

	chassis.use_internal_tank = !chassis.use_internal_tank
	action_icon_state = "mech_internals_[chassis.use_internal_tank ? "on" : "off"]"
	chassis.balloon_alert(owner, "taking air from [chassis.use_internal_tank ? "internal airtank" : "environment"]")
	chassis.log_message("Now taking air from [chassis.use_internal_tank?"internal airtank":"environment"].", LOG_MECHA)
	update_button_icon()

/datum/action/vehicle/sealed/mecha/mech_toggle_lights
	name = "Toggle Lights"
	action_icon_state = "mech_lights_off"

/datum/action/vehicle/sealed/mecha/mech_toggle_lights/action_activate(trigger_flags)
	if(!owner || !chassis || !(owner in chassis.occupants))
		return

	if(!(chassis.mecha_flags & HAS_HEADLIGHTS))
		chassis.balloon_alert(owner, "the mech lights are broken!")
		return
	chassis.mecha_flags ^= LIGHTS_ON
	if(chassis.mecha_flags & LIGHTS_ON)
		action_icon_state = "mech_lights_on"
	else
		action_icon_state = "mech_lights_off"
	chassis.set_light_on(chassis.mecha_flags & LIGHTS_ON)
	chassis.balloon_alert(owner, "toggled lights [chassis.mecha_flags & LIGHTS_ON ? "on":"off"]")
	playsound(chassis,'sound/mecha/brass_skewer.ogg', 40, TRUE)
	chassis.log_message("Toggled lights [(chassis.mecha_flags & LIGHTS_ON)?"on":"off"].", LOG_MECHA)
	update_button_icon()

/datum/action/vehicle/sealed/mecha/mech_view_stats
	name = "View Stats"
	action_icon_state = "mech_view_stats"
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_MECHABILITY_VIEW_STATS,
	)
/datum/action/vehicle/sealed/mecha/mech_view_stats/action_activate(trigger_flags)
	if(!owner || !chassis || !(owner in chassis.occupants))
		return

	chassis.ui_interact(owner)

/datum/action/vehicle/sealed/mecha/strafe
	name = "Toggle Strafing. Disabled when Alt is held."
	action_icon_state = "strafe"
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_MECHABILITY_TOGGLE_STRAFE,
	)
/datum/action/vehicle/sealed/mecha/strafe/action_activate(trigger_flags)
	if(!owner || !chassis || !(owner in chassis.occupants))
		return

	chassis.toggle_strafe()

/obj/vehicle/sealed/mecha/AltClick(mob/living/user)
	if(!(user in occupants))
		return
	if(!(user in return_controllers_with_flag(VEHICLE_CONTROL_DRIVE)))
		to_chat(user, span_warning("You're in the wrong seat to control movement."))
		return

	toggle_strafe()

/obj/vehicle/sealed/mecha/proc/toggle_strafe()
	if(!(mecha_flags & CANSTRAFE))
		for(var/occupant in occupants)
			balloon_alert(occupant, "No strafing mode")
		return

	strafe = !strafe
	for(var/occupant in occupants)
		balloon_alert(occupant, "Strafing mode [strafe?"on":"off"].")
		var/datum/action/action = LAZYACCESSASSOC(occupant_actions, occupant, /datum/action/vehicle/sealed/mecha/strafe)
		action?.update_button_icon()

///swap seats, for two person mecha
/datum/action/vehicle/sealed/mecha/swap_seat
	name = "Switch Seats"
	action_icon_state = "mech_seat_swap"

/datum/action/vehicle/sealed/mecha/swap_seat/action_activate(trigger_flags)
	if(!owner || !chassis || !(owner in chassis.occupants))
		return

	if(length(chassis.occupants) == chassis.max_occupants)
		chassis.balloon_alert(owner, "other seat occupied!")
		return
	var/list/drivers = chassis.return_drivers()
	chassis.balloon_alert(owner, "moving to other seat...")
	chassis.is_currently_ejecting = TRUE
	if(!do_after(owner, chassis.exit_delay, target = chassis))
		chassis.balloon_alert(owner, "interrupted!")
		chassis.is_currently_ejecting = FALSE
		return
	chassis.is_currently_ejecting = FALSE
	if(owner in drivers)
		chassis.balloon_alert(owner, "controlling gunner seat")
		chassis.remove_control_flags(owner, VEHICLE_CONTROL_DRIVE|VEHICLE_CONTROL_SETTINGS)
		chassis.add_control_flags(owner, VEHICLE_CONTROL_MELEE|VEHICLE_CONTROL_EQUIPMENT)
	else
		chassis.balloon_alert(owner, "controlling pilot seat")
		chassis.remove_control_flags(owner, VEHICLE_CONTROL_MELEE|VEHICLE_CONTROL_EQUIPMENT)
		chassis.add_control_flags(owner, VEHICLE_CONTROL_DRIVE|VEHICLE_CONTROL_SETTINGS)
	chassis.update_appearance()

/datum/action/vehicle/sealed/mecha/reload
	name = "Reload equipped weapons"
	action_icon_state = "reload"
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_MECHABILITY_RELOAD,
	)

/datum/action/vehicle/sealed/mecha/reload/action_activate(trigger_flags)
	if(!owner || !chassis || !(owner in chassis.occupants))
		return

	for(var/i in chassis.equip_by_category)
		if(!istype(chassis.equip_by_category[i], /obj/item/mecha_parts/mecha_equipment))
			continue
		INVOKE_ASYNC(chassis.equip_by_category[i], TYPE_PROC_REF(/obj/item/mecha_parts/mecha_equipment, attempt_rearm), owner)

/datum/action/vehicle/sealed/mecha/repairpack
	name = "Use Repairpack"
	action_icon_state = "mech_damtype_toxin" // todo kuro needs to make an icon for this
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_MECHABILITY_REPAIRPACK,
	)

/datum/action/vehicle/sealed/mecha/repairpack/action_activate(trigger_flags)
	if(!can_repair())
		return

	chassis.balloon_alert(owner, "Repairing...")
	if(!do_after(owner, 10 SECONDS, NONE, chassis, extra_checks=CALLBACK(src, PROC_REF(can_repair))))
		return
	chassis.stored_repairpacks--
	// does not count as actual repairs for end of round because its annoying to decouple from normal repair and this isnt representative of a real repair
	chassis.repair_damage(chassis.max_integrity)
	var/obj/vehicle/sealed/mecha/combat/greyscale/greyscale = chassis
	if(!istype(greyscale))
		return
	for(var/limb_key in greyscale.limbs)
		var/datum/mech_limb/limb = greyscale.limbs[limb_key]
		limb?.do_repairs(initial(limb.part_health))

///checks whether we can still repair this mecha
/datum/action/vehicle/sealed/mecha/repairpack/proc/can_repair()
	if(!owner || !chassis || !(owner in chassis.occupants))
		return FALSE
	if(!chassis.stored_repairpacks)
		chassis.balloon_alert(owner, "No repairpacks")
		return FALSE
	return TRUE
