

"""
Build a JuMP model to solve the PF problem
"""
function build_pf(network_model, scenario=1; kwargs...)
    if scenario > 1
		contingency = apply_contingency(network_model, scenario)
	end

    variable_bus_voltage(network_model, scenario; kwargs...)
    variable_gen_power(network_model, scenario; kwargs...)
	variable_shunt_adjustment(network_model, scenario; kwargs...)

    constraint_gen_pv(network_model, scenario; kwargs...)

    constraint_power_balance(network_model, scenario; kwargs...)
    constraint_reference_bus(network_model, scenario; kwargs...)

    if scenario > 1
		clear_contingency(network_model, contingency)
	end
end


"""
Build a PF problem with generator response
"""
function build_contingency_pf(network_model, scenario=1; kwargs...)
    if scenario > 1
		contingency = apply_contingency(network_model, scenario)
	end

    variable_bus_voltage(network_model, scenario; kwargs...)
    variable_gen_power(network_model, scenario; kwargs...)
	variable_shunt_adjustment(network_model, scenario; kwargs...)

    constraint_gen_pv(network_model, scenario; kwargs...)
    #constraint_gen_response(network_model)

    constraint_power_balance(network_model, scenario; kwargs...)
    constraint_reference_bus(network_model, scenario; kwargs...)

    if scenario > 1
		clear_contingency(network_model, contingency)
	end
end