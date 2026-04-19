extends Node
class_name TechSystem

# We structure the technology as a deck of cards. 
# Each tech has a weight (how likely it is to be drawn), a cost, and optional prerequisites.
# We also include dynamic weight modifiers (e.g. knowing Prerequisite A might increase the weight of drawing B).

var discovered_techs: Dictionary = {}
var current_research: String = ""
var research_progress: float = 0.0

var tech_deck = {
	"plasma_weapons_1": {
		"name": "Basic Plasma Projection",
		"category": "Physics",
		"base_weight": 100,
		"cost": 1500,
		"prerequisites": [],
		"description": "Unlocks basic plasma weaponry for ship design."
	},
	"plasma_weapons_2": {
		"name": "High-Energy Plasma Coils",
		"category": "Physics",
		"base_weight": 50,
		"cost": 3000,
		"prerequisites": ["plasma_weapons_1"],
		"description": "Higher damage output plasma weapons."
	},
	"zero_point_energy_1": {
		"name": "Zero-Point Extraction",
		"category": "Engineering",
		"base_weight": 10,  # Rare late game tech
		"cost": 10000,
		"prerequisites": [],
		"description": "Vastly increases ship power capacities."
	},
	"dark_matter_plants": {
		"name": "Dark Matter Harvesting",
		"category": "Engineering",
		"base_weight": 5, # Extremely rare without modifiers
		"cost": 25000,
		"prerequisites": ["zero_point_energy_1"],
		"description": "The ultimate power source."
	},
	"wormhole_generator": {
		"name": "Wormhole Stabilization",
		"category": "Physics",
		"base_weight": 20, 
		"cost": 12000,
		"prerequisites": [],
		"description": "Allows ships to bypass hyperlanes entirely over a fixed radius."
	},
	"ship_health_iterative": {
		"name": "Hull Reinforcement Techniques",
		"category": "Engineering",
		"base_weight": 200, # Very common
		"cost": 1000,
		"prerequisites": [],
		"is_infinite": true, # Can be researched forever
		"level": 0,
		"description": "Iteratively improves hull strength by 5%."
	}
}

func _ready():
	# For testing purposes, when this node loads, let's draw a few cards.
	print("--- Tech System Initialized ---")
	var drawn_cards = draw_tech_cards(3)
	print("Initial Tech Options Drawn:")
	for card in drawn_cards:
		print("- ", tech_deck[card]["name"], " (Cost: ", tech_deck[card]["cost"], ")")

func draw_tech_cards(amount: int) -> Array[String]:
	var valid_techs = _get_valid_techs()
	var drawn: Array[String] = []
	
	for i in range(amount):
		if valid_techs.is_empty():
			break
			
		var total_weight = 0
		for tech_id in valid_techs:
			total_weight += _calculate_weight(tech_id)
			
		var roll = randf() * total_weight
		var current_weight = 0
		
		for tech_id in valid_techs:
			current_weight += _calculate_weight(tech_id)
			if roll <= current_weight:
				drawn.append(tech_id)
				valid_techs.erase(tech_id) # Prevent drawing duplicates in the same hand
				break
				
	return drawn
	
func reroll_cards(amount: int) -> Array[String]:
	print("Rerolling tech options... (Costs a penalty to research normally!)")
	return draw_tech_cards(amount)

func start_research(tech_id: String):
	if not tech_deck.has(tech_id):
		return
	current_research = tech_id
	research_progress = 0.0
	print("Started researching: ", tech_deck[tech_id]["name"])

func add_research_points(amount: float):
	if current_research == "":
		return
		
	research_progress += amount
	var required = tech_deck[current_research]["cost"]
	if research_progress >= required:
		_complete_research()

func _complete_research():
	var completed = current_research
	print("Research Complete: ", tech_deck[completed]["name"])
	
	if tech_deck[completed].has("is_infinite") and tech_deck[completed]["is_infinite"]:
		tech_deck[completed]["level"] += 1
		tech_deck[completed]["cost"] *= 1.25 # Scale cost infinitely
	else:
		discovered_techs[completed] = true
		
	current_research = ""
	research_progress = 0.0
	
	# Draw next hand
	var new_hand = draw_tech_cards(3)
	print("New Tech Options Drawn:")
	for card in new_hand:
		print("- ", tech_deck[card]["name"], " (Wait weight: ", _calculate_weight(card), ")")

# --- Internal Logic ---

func _get_valid_techs() -> Array[String]:
	var valid = []
	for tech_id in tech_deck.keys():
		# Skip already discovered tech unless it's infinite
		if discovered_techs.has(tech_id) and not tech_deck[tech_id].get("is_infinite", false):
			continue
			
		# Check prerequisites
		var prerequisites_met = true
		for req in tech_deck[tech_id]["prerequisites"]:
			if not discovered_techs.has(req):
				prerequisites_met = false
				break
				
		if prerequisites_met:
			valid.append(tech_id)
	return valid

func _calculate_weight(tech_id: String) -> float:
	var base = tech_deck[tech_id]["base_weight"]
	var multiplier = 1.0
	
	# Future logic: Check scientist traits. If scientist is "Voidcraft", increase wormhole weight.
	if tech_id == "wormhole_generator" and discovered_techs.has("zero_point_energy_1"):
		multiplier += 2.0 # Knowing zero point energy makes pulling the wormhole tech 3x more likely!
		
	return base * multiplier
