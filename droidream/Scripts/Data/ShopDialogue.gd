extends RefCounted
class_name ShopDialogue

# Tuh-U's lines in the shop: how he greets you, and how he reacts when you buy or cannot afford something; every line has a mood face

const FIRST_VISIT := [
	{ "text": "Found some cool stuff! And I just might share..!", "mood": "happy" },
	{ "text": "Nice! I'd do our signature handshake if I had hands.", "mood": "happy" },
	{ "text": "That looked fun! ..Or at least I hope it was!", "mood": "happy" },
	{ "text": "Wow-ow, Droid of the jungle! Droid of the jungle!", "mood": "happy" }
]
const LOW_HP := [
	{ "text": "..Hey, you good?", "mood": "sad" },
	{ "text": "Hope your insurance covers that damage..", "mood": "sad" },
	{ "text": "Some heals would be real convenient right about now...", "mood": "sad" },
	{ "text": "I wonder if they have a hospital for droids here..", "mood": "happy" }
]
const RICH := [
	{ "text": "Yeesh, talk about loaded!", "mood": "happy" },
	{ "text": "Man, what'd you invest in? Junglecoin?", "mood": "happy" },
	{ "text": "Dividends sure pay well, huh?", "mood": "happy" },
]
const BROKE := [
	{ "text": "Rough economy, eh?", "mood": "happy" },
	{ "text": "Hope you're applying for a job soon..", "mood": "sad" },
	{ "text": "I wonder what's the best way to build steady revenue.", "mood": "normal" },
]
const DEFAULT := [
	{ "text": "We should make a podcast after all this!", "mood": "happy" },
	{ "text": "Hey, can you help me solve this? 3^3 + log10(10000) + (108 / 3)", "mood": "normal" },
	{ "text": "I don't know who keeps making everything so dark.", "mood": "sad" },
	{ "text": "These creatures sure are something, huh?", "mood": "happy" },
	{ "text": "The caverns system is still a ways to go!", "mood": "happy" }
]
const BUY := [
	{ "text": "Nice! Big thanks!", "mood": "happy" },
	{ "text": "Wow! Great! Perfect! That's me hyping your purchase!", "mood": "happy" },
	{ "text": "You're sure to like that, yup!", "mood": "happy" },
	{ "text": "That'll probably be useful.", "mood": "happy" },
]
const DENY := [
	{ "text": "Yeah.. sorry but you ain't cut for this.", "mood": "sad" },
	{ "text": "What happens between encounters stays between encounters.", "mood": "sad" },
	{ "text": "Sorry, no.", "mood": "sad" },
	{ "text": "You'll be fine! ..Probably.", "mood": "sad" },
]

const LOW_HP_RATIO := 0.4
const RICH_BOLTS := 15
const BROKE_BOLTS := 2

static var visits := 0 # Shops visited in this run
static var last_text := "" # Never the same line twice in a row

# A new run starts with a first visit again
static func reset() -> void:
	visits = 0
	last_text = ""

# The greeting: first visit, low health, lots of or few bolts, otherwise a general one
static func arrival() -> Dictionary:
	visits += 1
	if visits == 1:
		return _pick(FIRST_VISIT)
	if PlayerData.hp <= PlayerData.max_hp * LOW_HP_RATIO:
		return _pick(LOW_HP)
	if PlayerData.currency >= RICH_BOLTS:
		return _pick(RICH)
	if PlayerData.currency <= BROKE_BOLTS:
		return _pick(BROKE)
	return _pick(DEFAULT)

static func buy() -> Dictionary:
	return _pick(BUY)

static func deny() -> Dictionary:
	return _pick(DENY)

static func _pick(lines: Array) -> Dictionary:
	var options := lines.filter(func(line): return line["text"] != last_text)
	if options.is_empty():
		options = lines
	var line: Dictionary = options.pick_random()
	last_text = line["text"]
	return line
