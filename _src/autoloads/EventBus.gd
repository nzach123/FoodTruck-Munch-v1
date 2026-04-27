extends Node

# quality: 0 = perfect, 1 = sloppy
signal order_accepted(customer_id: int, recipe: Resource)
signal order_step_completed(ingredient: StringName, quality: int)
signal order_completed(payment: float, tip: float)
signal order_rejected(food_cost: float)
signal customer_left_angry(penalty: float)
signal balance_changed(new_balance: float, delta: float)
signal upgrade_purchased(upgrade_id: StringName)
signal day_started(day_number: int)
signal day_ended(summary: Dictionary)
signal station_locked_attempt(station_id: StringName, reason: String)
