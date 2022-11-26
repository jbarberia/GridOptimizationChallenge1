

"""
Build a JuMP model to solve the PF problem
"""
function build_pf(network_model, kwargs...)
    variable_bus_voltage(network_model)
    variable_gen_power(network_model)
	variable_shunt_adjustment(network_model)

    constraint_gen_pv(network_model)

    constraint_power_balance(network_model)
    constraint_reference_bus(network_model)
end


"""
Build a PF problem with generator response
"""
function build_contingency_pf(network_model, contingency)
    variable_bus_voltage(network_model)
    variable_gen_power(network_model)
	variable_shunt_adjustment(network_model)

    constraint_gen_pv(network_model)
    #constraint_gen_response(network_model)

    constraint_power_balance(network_model)
    constraint_reference_bus(network_model)
end