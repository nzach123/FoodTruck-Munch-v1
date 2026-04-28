extends Node

# quality: 0 = perfect, 1 = sloppy
# food_cost: ingredient cost deducted by EconomyManager on quality == 1 (0.0 for sauce stations — tip loss only)
signal order_accepted(customer_id: int, recipe: Recipe)
signal order_step_completed(ingredient: StringName, quality: int, food_cost: float)
signal order_completed(payment: float, tip: float)
signal order_rejected(food_cost: float)
signal customer_left_angry(penalty: float)
signal balance_changed(new_balance: float, delta: float)
signal upgrade_purchased(upgrade_id: StringName)
signal day_started(day_number: int)
signal day_ended(summary: Dictionary)
signal station_locked_attempt(station_id: StringName, reason: String)
# normalized_value: 0.0–1.0 fill level; emitted on each press and once on commit (0.0 = reset)
signal sauce_gauge_changed(station_id: StringName, normalized_value: float)
# normalized_radius: 0.0–1.0 shrink progress; -1.0 sentinel = hide circle (player looked away)
signal circle_radius_changed(station_id: StringName, normalized_radius: float)
