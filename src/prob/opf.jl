

"""
Build a GOC1 base case opf with hard constraints
"""
function build_opf(network_model, kwargs...)
	variable_bus_voltage(network_model)
	variable_gen_power(network_model)
	variable_shunt_adjustment(network_model)

	constraint_power_balance(network_model)
	constraint_power_flow_limits(network_model)
	constraint_reference_bus(network_model)

	objective_generator_cost(network_model)
end

s
"""
Build a GOC1 base case opf with soft constraints in
power balance and branch flow limits
"""
function build_opf_soft(network_model, kwargs...)
	variable_bus_voltage(network_model)
	variable_gen_power(network_model)
	variable_shunt_adjustment(network_model)

	constraint_power_balance_soft(network_model)
	constraint_power_flow_limits_soft(network_model)
	constraint_reference_bus(network_model)

	objective_generator_cost_plus_penalties(network_model, kwargs...)
end
