


function variable_bus_voltage(network_model::DCNetworkModel, scenario=1)
    net = network_model.net
    model = network_model.scenarios[scenario] 

    model[:va] = Dict()
    for bus in net.buses
        if !bus.is_in_service(); continue; end

        model[:va][bus.number] = @variable(model, start=bus.v_ang)
    end
end


function variable_gen_power(network_model::DCNetworkModel, scenario=1, bounded=true)
    net = network_model.net
    model = network_model.scenarios[scenario] 

    model[:pg] = Dict()
    for gen in net.generators

        index = (gen.bus.number, gen.name)
        model[:pg][index] = @variable(model, start=gen.P, upper_bound=gen.P_max, lower_bound=gen.P_min)

        if bounded
            set_lower_bound(model[:pg][index], gen.P_min)
            set_upper_bound(model[:pg][index], gen.P_max)
        end

        if !gen.is_in_service()
            fix(model[:pg][index], 0., force=true)
        end

    end
end


function variable_shunt_adjustment(network_model::DCNetworkModel, scenario=1)
    nothing
end


function variable_slack_power_balance(network_model::DCNetworkModel, scenario=1)
    net = network_model.net
    model = network_model.scenarios[scenario] 
	
	model[:sigma_p_mismatch_plus] = Dict()
	model[:sigma_p_mismatch_minus] = Dict()
	
	for bus in net.buses
		if !bus.is_in_service(); continue; end
		
		p_mis_plus = bus.P_mismatch >= 0 ? bus.P_mismatch : 0
		p_mis_minus = bus.P_mismatch < 0 ? -bus.P_mismatch : 0
		
		model[:sigma_p_mismatch_plus][bus.number] = @variable(model, start=p_mis_plus, lower_bound=1)
		model[:sigma_p_mismatch_minus][bus.number] = @variable(model, start=p_mis_minus, lower_bound=1)
	end
end


function variable_slack_power_flow_limits(network_model::DCNetworkModel, scenario=1)
    net = network_model.net
    model = network_model.scenarios[scenario] 
	
	model[:sigma_s_limit] = Dict()
	
	for br in net.branches
		if !br.is_in_service(); continue; end
		
		index = (br.name, br.bus_k.number, br.bus_m.number)
		
		model[:sigma_s_limit][index] = @variable(model, lower_bound=0)
	end
end


function expresion_power_flow(network_model::DCNetworkModel, scenario=1)
    net = network_model.net
    model = network_model.scenarios[scenario] 
	
	# Placeholder for power flow expresions
	model[:p_fr] = Dict()
    model[:p_to] = Dict()

    p_fr = model[:p_fr]
    p_to = model[:p_to]
    va = model[:va]

    for br in net.branches
        if !br.is_in_service(); continue; end

        index = (br.name, br.bus_k.number, br.bus_m.number)
        k = br.bus_k.number
        m = br.bus_m.number
           
        g = br.g
        b = br.b
           
        g_k = br.g_k
        g_m = br.g_m
        b_k = br.b_k
        b_m = br.b_m
           
        t = br.ratio
        dw = va[k] - va[m] - br.phase

        p_fr[index] = @expression(model,  b*(dw))
        p_to[index] = @expression(model, -b*(dw))
    end
end


function constraint_power_balance(network_model::DCNetworkModel, scenario=1)
    net = network_model.net
    model = network_model.scenarios[scenario] 
	
	# Create power flow expresions
    if !(haskey(model, :p_fr) || haskey(model, :p_to))
        expresion_power_flow(network_model, scenario)
    end
	    
    pg = model[:pg]
    p_fr = model[:p_fr]
    p_to = model[:p_to]

    # Constraint reference
    model[:constraint_bus_power_balance_p] = Dict()
    constraint_bus_power_balance_p = model[:constraint_bus_power_balance_p]

    for bus in net.buses
        if !bus.is_in_service(); continue; end

        constraint_bus_power_balance_p[bus.number] = @constraint(model,     
            sum(pg[gen.bus.number, gen.name] for gen in bus.generators)
            - sum(load.P for load in bus.loads if load.is_in_service())
            - sum(p_fr[br.name, br.bus_k.number, br.bus_m.number] for br in bus.branches_k if br.is_in_service())
            - sum(p_to[br.name, br.bus_k.number, br.bus_m.number] for br in bus.branches_m if br.is_in_service())
            == 0.
        )
    end
end


function constraint_power_balance_soft(network_model::DCNetworkModel, scenario=1)
    net = network_model.net
    model = network_model.scenarios[scenario]
	
	# Create power flow expresions
    if !(haskey(model, :p_fr) || haskey(model, :p_to))
        expresion_power_flow(network_model, scenario)
    end
	
	# add slacks variables
	if !(haskey(model, :sigma_p_mismatch_plus) || haskey(model, :sigma_p_mismatch_minus))
		variable_slack_power_balance(network_model)
	end
	
	sigma_p_mismatch_plus = model[:sigma_p_mismatch_plus]
	sigma_p_mismatch_minus = model[:sigma_p_mismatch_minus]
    
    pg = model[:pg]
    p_fr = model[:p_fr]
    p_to = model[:p_to]

    # Constraint reference
    model[:constraint_bus_power_balance_p] = Dict()
    constraint_bus_power_balance_p = model[:constraint_bus_power_balance_p]

    for bus in net.buses
        if !bus.is_in_service(); continue; end

        constraint_bus_power_balance_p[bus.number] = @constraint(model,     
            sum(pg[gen.bus.number, gen.name] for gen in bus.generators)
            - sum(load.P for load in bus.loads)
            - sum(p_fr[br.name, br.bus_k.number, br.bus_m.number] for br in bus.branches_k)
            - sum(p_to[br.name, br.bus_k.number, br.bus_m.number] for br in bus.branches_m)
            == sigma_p_mismatch_plus[bus.number] + sigma_p_mismatch_minus[bus.number]
        )
    end
end


function constraint_power_flow_limits(network_model::DCNetworkModel, scenario=1)
    net = network_model.net
    model = network_model.scenarios[scenario] 
	
	# Compute branch power expresions
    if !(haskey(model, :p_fr) || haskey(model, :p_to))
        expresion_power_flow(network_model, scenario)
    end

    p_fr = model[:p_fr]
    p_to = model[:p_to]

    for br in net.branches
        if !br.is_in_service(); continue; end
        
        if br.ratingA <= 0.
            println("Rating under 0 [MVA] in branch $(br.__str__())")
            continue
        end
        
        index = (br.name, br.bus_k.number, br.bus_m.number)
        k = br.bus_k.number
        m = br.bus_m.number
        rate = br.ratingA

        # p_fr == p_to in this model
        @constraints(model, begin
            p_fr[index] <= rate
            p_to[index] <= rate
        end)
    end
end


function constraint_power_flow_limits_soft(network_model::DCNetworkModel, scenario=1)
    net = network_model.net
    model = network_model.scenarios[scenario] 
	
	# Compute branch power expresions
    if !(haskey(model, :p_fr) || haskey(model, :p_to))
        expresion_power_flow(network_model, scenario)
    end
	
	# Add slack variables
	if !(haskey(model, :sigma_s_limit))
		variable_slack_power_flow_limits(network_model)
	end
	
	sigma_s_limit = model[:sigma_s_limit]
	
    p_fr = model[:p_fr]
    p_to = model[:p_to]

    for br in net.branches
        if !br.is_in_service(); continue; end
        
        if br.ratingA <= 0.
            println("Rating under 0 [MVA] in branch $(br.__str__())")
            continue
        end
        
        index = (br.name, br.bus_k.number, br.bus_m.number)
        k = br.bus_k.number
        m = br.bus_m.number
        rate = br.ratingA

        # p_fr == p_to in this model
        @constraints(model, begin
            p_fr[index] >= rate + sigma_s_limit[index]
            p_to[index] >= rate + sigma_s_limit[index]
        end)
    end
end


function constraint_reference_bus(network_model::DCNetworkModel, scenario=1)
    net = network_model.net
    model = network_model.scenarios[scenario] 

    va = model[:va]

    for bus in net.buses
        if !bus.is_in_service(); continue; end

        if bus.is_slack()
            @constraint(model, va[bus.number] == bus.v_ang)
        end
    end
end


function constraint_gen_pv(network_model::DCNetworkModel, scenario=1)
    nothing
end


function constraint_gen_link_active_power(network_model::DCNetworkModel, scenario_1, scenario_2)
    net = network_model.net
    model_1 = network_model.scenarios[scenario_1]
    model_2 = network_model.scenarios[scenario_2]

    # fix model2 vars
    for gen in net.generators
        if !gen.is_in_service(); continue; end
        index = (gen.bus.number, gen.name)
        fix(model_2[:pg][index], JuMP.value(model_1[:pg][index]))
    end
end


function constraint_bus_link_voltage_magnitude(network_model::DCNetworkModel, scenario_1, scenario_2)
    nothing
end


function objective_generator_cost(network_model::DCNetworkModel, scenario=1)
    update_generator_costs!(network_model)
    net = network_model.net
    model = network_model.scenarios[scenario] 
    pg = model[:pg]

    @objective(model, Min, 
    sum(
        gen.cost_coeff_Q2 * pg[gen.bus.number, gen.name]^2 +
        gen.cost_coeff_Q1 * pg[gen.bus.number, gen.name] +
        gen.cost_coeff_Q0
        for gen in net.generators if gen.is_in_service())
    )
end


function objective_generator_cost_plus_penalties(network_model::DCNetworkModel, scenario=1, kwargs...)
    update_generator_costs!(network_model)
    net = network_model.net
    model = network_model.scenarios[scenario] 
	
	# default penalty coefficients
    dict_kwargs = Dict(kwargs)
	c_s = haskey(dict_kwargs, :c_s) ? dict_kwargs[:c_s] : 1e3 * net.base_power
	c_p = haskey(dict_kwargs, :c_s) ? dict_kwargs[:c_p] : 1e3 * net.base_power
	c_q = haskey(dict_kwargs, :c_q) ? dict_kwargs[:c_q] : 1e3 * net.base_power
	
    pg = model[:pg]
	sigma_s_limit = model[:sigma_s_limit]
	sigma_p_mismatch_plus = model[:sigma_p_mismatch_plus]
	sigma_p_mismatch_minus = model[:sigma_p_mismatch_minus]
	
    @objective(model, Min, 
    sum(
        gen.cost_coeff_Q2 * pg[gen.bus.number, gen.name]^2 +
        gen.cost_coeff_Q1 * pg[gen.bus.number, gen.name] +
        gen.cost_coeff_Q0
        for gen in net.generators if gen.is_in_service()) + 
	c_s * sum(s_limit for s_limit in values(sigma_s_limit)) +
	c_p * sum(p_mis for p_mis in values(sigma_p_mismatch_plus)) +
	c_p * sum(p_mis for p_mis in values(sigma_p_mismatch_minus))
    )
	
end


"""
Update the results of the optimization model ´network_model.model´
to the ´network_model.net´ PFNET network
"""
function update_network!(network_model::DCNetworkModel, scenario=1)
    net = network_model.net
    model = network_model.scenarios[scenario] 
    va = model[:va]
    pg = model[:pg]

    for bus in net.buses
        if !bus.is_in_service(); continue; end
    
        bus.v_ang = JuMP.value(va[bus.number])
    end

    for gen in net.generators
        index = (gen.bus.number, gen.name)

        gen.P = JuMP.value(pg[index])
    end

    net.update_properties()
end
