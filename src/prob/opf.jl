

"""
Build a GOC1 base case opf with hard constraints
"""
function build_opf(network_model, scenario=1; kwargs...)
	if scenario > 1
		contingency = apply_contingency(network_model, scenario)
	end

	variable_bus_voltage(network_model, scenario; kwargs...)
	variable_gen_power(network_model, scenario; kwargs...)
	variable_shunt_adjustment(network_model, scenario; kwargs...)

	constraint_power_balance(network_model, scenario; kwargs...)
	constraint_power_flow_limits(network_model, scenario; kwargs...)
	constraint_reference_bus(network_model, scenario; kwargs...)

	objective_generator_cost(network_model, scenario; kwargs...)

	if scenario > 1
		clear_contingency(network_model, contingency)
	end
end


"""
Build a GOC1 base case opf with soft constraints in
power balance and branch flow limits
"""
function build_opf_soft(network_model, scenario=1; kwargs...)
	if scenario > 1
		contingency = apply_contingency(network_model, scenario)
	end
	
	variable_bus_voltage(network_model, scenario; kwargs...)
	variable_gen_power(network_model, scenario; kwargs...)
	variable_shunt_adjustment(network_model, scenario; kwargs...)

	constraint_power_balance_soft(network_model, scenario; kwargs...)
	constraint_power_flow_limits_soft(network_model, scenario; kwargs...)
	constraint_reference_bus(network_model, scenario; kwargs...)

	objective_generator_cost_plus_penalties(network_model, scenario; kwargs...)

	if scenario > 1
		clear_contingency(network_model, contingency)
	end
end
