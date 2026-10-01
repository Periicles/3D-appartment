class_name Shortcuts
extends RefCounted
## Single source for every control shown to the user (help overlay, panel hint).
## Keys are tokens: "cmd", "shift" and "alt" are rendered per platform, any
## other token is shown as is.

const MAC_MODIFIERS := {"cmd": "⌘", "shift": "⇧", "alt": "⌥"}
const OTHER_MODIFIERS := {"cmd": "Ctrl", "shift": "Maj", "alt": "Alt"}


static func is_mac() -> bool:
	return OS.get_name() == "macOS"


static func format_keys(keys: Array, mac: bool = is_mac()) -> String:
	var names := MAC_MODIFIERS if mac else OTHER_MODIFIERS
	var parts := PackedStringArray()
	for key in keys:
		parts.append(names.get(key, key))
	return " ".join(parts) if mac else " + ".join(parts)


static func groups() -> Array[Dictionary]:
	return [
		_group("Caméra (souris)", [
			_entry(["Clic droit + glisser"], "Tourner autour"),
			_entry(["Clic molette + glisser"], "Se déplacer"),
			_entry(["shift", "Clic droit + glisser"], "Se déplacer (sans clic molette)"),
			_entry(["Molette"], "Zoomer"),
			_entry(["Double-clic sur le sol"], "Centrer sur la pièce"),
		]),
		_group("Caméra (trackpad)", [
			_entry(["Deux doigts"], "Tourner autour"),
			_entry(["shift", "Deux doigts"], "Se déplacer"),
			_entry(["Pincer"], "Zoomer"),
		]),
		_group("Meubles", [
			_entry(["Clic sur le catalogue, puis clic dans la pièce"], "Ajouter un meuble"),
			_entry(["Clic"], "Sélectionner"),
			_entry(["Clic + glisser"], "Déplacer"),
			_entry(["alt"], "Placement libre, sans grille (en déplaçant)"),
			_entry(["R"], "Pivoter d'un quart de tour"),
			_entry(["shift", "Molette (souris)"], "Pivoter de ±15°"),
			_entry(["Suppr / ⌫"], "Supprimer"),
			_entry(["cmd", "D"], "Dupliquer"),
			_entry(["cmd", "Z"], "Annuler"),
			_entry(["cmd", "shift", "Z"], "Rétablir"),
			_entry(["Échap"], "Abandonner l'ajout ou désélectionner"),
		]),
		_group("Vue et mesures", [
			_entry(["Tab"], "Vue plan, ou retour à la vue orbitale"),
			_entry(["O"], "Vue orbitale"),
			_entry(["P"], "Calque du plan d'architecte (en vue plan)"),
			_entry(["M"], "Mesurer : cliquer deux points"),
			_entry(["Échap"], "Effacer toutes les mesures"),
		]),
		_group("Fichier", [
			_entry(["cmd", "shift", "O"], "Accueil : choisir un projet"),
			_entry(["cmd", "O"], "Ouvrir un projet"),
			_entry(["cmd", "S"], "Enregistrer"),
			_entry(["cmd", "shift", "S"], "Enregistrer sous"),
		]),
		_group("Interface", [
			_entry(["C"], "Afficher ou masquer le catalogue"),
			_entry(["I"], "Afficher ou masquer l'inspecteur"),
			_entry(["? / F1"], "Afficher cette aide"),
			_entry(["cmd", "+"], "Agrandir l'interface"),
			_entry(["cmd", "−"], "Réduire l'interface"),
			_entry(["cmd", "0"], "Taille d'interface par défaut"),
			_entry(["H"], "Masquage des murs : auto, complets, tous abaissés"),
		]),
	]


## The interface action a key press triggers: &"toggle_catalog",
## &"toggle_inspector", &"help", &"cutaway", &"zoom_in", &"zoom_out",
## &"zoom_reset", &"welcome", &"open", &"save", &"save_as", &"plan_view",
## &"orbit_view", &"underlay", &"measure", or &"" for none. Accepts the QWERTY and AZERTY variants.
static func action_for(event: InputEventKey) -> StringName:
	if not event.pressed or event.echo:
		return &""
	var character := char(event.unicode) if event.unicode > 0 else ""
	if event.is_command_or_control_pressed():
		if event.keycode == KEY_O:
			return &"welcome" if event.shift_pressed else &"open"
		if event.keycode == KEY_S:
			return &"save_as" if event.shift_pressed else &"save"
		if character in ["+", "="] or event.keycode in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD]:
			return &"zoom_in"
		if character == "-" or event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			return &"zoom_out"
		if character == "0" or event.keycode in [KEY_0, KEY_KP_0] or event.physical_keycode == KEY_0:
			return &"zoom_reset"
		return &""
	if event.alt_pressed:
		return &""
	if character == "?" or event.keycode == KEY_F1:
		return &"help"
	match event.keycode:
		KEY_TAB:
			return &"plan_view"
		KEY_O:
			return &"orbit_view"
		KEY_P:
			return &"underlay"
		KEY_M:
			return &"measure"
		KEY_C:
			return &"toggle_catalog"
		KEY_I:
			return &"toggle_inspector"
		KEY_H:
			return &"cutaway"
	return &""


## Short reminder shown under the properties panel.
static func furniture_hint(mac: bool = is_mac()) -> String:
	return "R : pivoter · %s : ±15°\nSuppr : supprimer · %s : dupliquer\n%s : annuler · ? : tous les raccourcis" % [
		format_keys(["shift", "Molette"], mac), format_keys(["cmd", "D"], mac), format_keys(["cmd", "Z"], mac)]


static func _group(title: String, entries: Array) -> Dictionary:
	return {"title": title, "entries": entries}


static func _entry(keys: Array, action: String) -> Dictionary:
	return {"keys": keys, "action": action}
