class_name ShopLogic
## Règles de la Roue de la Fortune et du Marché Noir (sans interface, testables).

## Segments de la roue : récompense, poids de tirage, couleur, icône, libellé court.
const WHEEL := [
	{"reward": {"coins": 150}, "w": 20.0, "color": "c89a20", "icon": "coin", "label": "150"},
	{"reward": {"dust": 200}, "w": 18.0, "color": "6a5ad8", "icon": "dust", "label": "200"},
	{"reward": {"booster": "mini"}, "w": 18.0, "color": "d0508a", "icon": "ui_gift", "label": "MINI"},
	{"reward": {"crystals": 15}, "w": 12.0, "color": "2a7ad8", "icon": "crystal", "label": "15"},
	{"reward": {"coins": 400}, "w": 12.0, "color": "e0a020", "icon": "coin", "label": "400"},
	{"reward": {"tokens": 1}, "w": 8.0, "color": "2ab890", "icon": "token", "label": "1"},
	{"reward": {"random_card": {"rarity": "E"}}, "w": 6.0, "color": "8a2ad8", "icon": "ui_star", "label": "ÉPIQUE"},
	{"reward": {"booster": "prestige"}, "w": 3.0, "color": "1a1408", "icon": "ui_gift", "label": "PRESTIGE"},
	{"reward": {"crystals": 60}, "w": 3.0, "color": "0a3a9a", "icon": "crystal", "label": "60"},
]
const EXTRA_SPIN_PRICE := {"crystals": 25}
const EXTRA_SPINS_PER_DAY := 3

## Tire un segment de la roue (index).
static func wheel_roll(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for s in WHEEL:
		total += float(s.w)
	var x := rng.randf() * total
	for i in WHEEL.size():
		x -= float(WHEEL[i].w)
		if x <= 0.0:
			return i
	return WHEEL.size() - 1

static func wheel_chance(i: int) -> float:
	var total := 0.0
	for s in WHEEL:
		total += float(s.w)
	return float(WHEEL[i].w) / total * 100.0

## État du jour : {"date", "free_used", "extra"} (remis à zéro chaque jour).
static func wheel_state(d: Dictionary, today: String) -> Dictionary:
	var w: Dictionary = d.get("wheel", {})
	if w.get("date", "") != today:
		w = {"date": today, "free_used": false, "extra": 0}
		d["wheel"] = w
	return w

# ---------------------------------------------------------------- Marché Noir
const MARKET_RARITIES := ["E", "NE", "L", "IN", "M"]
const MARKET_DUST := {"E": 450, "NE": 400, "L": 1200, "IN": 1800, "M": 3200}
const MARKET_HOURS := 6
const MARKET_SIZE := 4

## Période courante du marché (change toutes les 6 heures).
static func market_period(unix: float) -> int:
	return int(unix / (3600.0 * MARKET_HOURS))

static func market_seconds_left(unix: float) -> int:
	var p := MARKET_HOURS * 3600
	return p - int(unix) % p

## Offres d'une période : [{id, dust, crystals}], toujours les mêmes pour une période donnée.
static func market_offers(period: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("market%d" % period)
	var pools := {}
	for id in DB.card_order:
		var r: String = DB.card(id).rarity
		if r in MARKET_RARITIES:
			if not pools.has(r):
				pools[r] = []
			pools[r].append(id)
	# au moins une Légendaire ou mieux dans chaque rotation
	var wanted := ["L" if rng.randf() < 0.6 else ["IN", "M"][rng.randi_range(0, 1)]]
	while wanted.size() < MARKET_SIZE:
		wanted.append(["E", "E", "NE", "NE", "L", "IN"][rng.randi_range(0, 5)])
	var out := []
	var used := []
	for r in wanted:
		var pool: Array = pools.get(r, [])
		if pool.is_empty():
			continue
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		if id in used:
			continue
		used.append(id)
		var dust := int(MARKET_DUST[r])
		out.append({"id": id, "dust": dust, "crystals": int(round(dust / 9.0 / 5.0)) * 5})
	return out
