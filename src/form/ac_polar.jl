


function variable_bus_voltage(network_model::ACPolarNetworkModel)
    net = network_model.net
    model = network_model.model
    variable = network_model.variable

    variable["vm"] = Dict()
    variable["va"] = Dict()
    for bus in net.buses
        if !bus.is_in_service(); continue; end

        variable["vm"][bus.number] = @variable(model, start=bus.v_mag, lower_bound=bus.v_min, upper_bound=bus.v_max)
        variable["va"][bus.number] = @variable(model, start=bus.v_ang)
    end
end


function variable_gen_power(network_model::ACPolarNetworkModel)
    net = network_model.net
    model = network_model.model
    variable = network_model.variable

    variable["pg"] = Dict()
    variable["qg"] = Dict()
    for gen in net.generators
        if !gen.is_in_service(); continue; end

        index = (gen.bus.number, gen.name)
        variable["pg"][index] = @variable(model, start=gen.P, upper_bound=gen.P_max, lower_bound=gen.P_min)
        variable["qg"][index] = @variable(model, start=gen.Q, upper_bound=gen.Q_max, lower_bound=gen.Q_min)
    end
end


function variable_shunt_adjustment(network_model::ACPolarNetworkModel)
    net = network_model.net
    model = network_model.model
    variable = network_model.variable

    variable["b_sh"] = Dict()
    for sh in net.shunts
        index = (sh.bus.number, sh.name)
        if !sh.is_in_service(); continue; end

        if sh.is_fixed()
            variable["b_sh"][index] = sh.b
        else
            variable["b_sh"][index] = @variable(model, start=sh.b, lower_bound=sh.b_min, upper_bound=sh.b_max)
        end
    end
end


function variable_slack_power_balance(network_model::ACPolarNetworkModel)
    net = network_model.net
    model = network_model.model
    variable = network_model.variable
	
	variable["sigma_p_mismatch_plus"] = Dict()
	variable["sigma_p_mismatch_minus"] = Dict()
	variable["sigma_q_mismatch_plus"] = Dict()
	variable["sigma_q_mismatch_minus"] = Dict()
	
	for bus in net.buses
		if !bus.is_in_service(); continue; end
		
		p_mis_plus = bus.P_mismatch >= 0 ? bus.P_mismatch : 0
		p_mis_minus = bus.P_mismatch < 0 ? -bus.P_mismatch : 0
		q_mis_plus = bus.Q_mismatch >= 0 ? bus.Q_mismatch : 0
		q_mis_minus = bus.Q_mismatch < 0 ? -bus.Q_mismatch : 0
		
		variable["sigma_p_mismatch_plus"][bus.number] = @variable(model, start=p_mis_plus, lower_bound=0)
		variable["sigma_p_mismatch_minus"][bus.number] = @variable(model, start=p_mis_minus, lower_bound=0)
		variable["sigma_q_mismatch_plus"][bus.number] = @variable(model, start=q_mis_plus, lower_bound=0)
		variable["sigma_q_mismatch_minus"][bus.number] = @variable(model, start=q_mis_minus, lower_bound=0)
	end
end


function variable_slack_power_flow_limits(network_model::ACPolarNetworkModel)
    net = network_model.net
    model = network_model.model
    variable = network_model.variable
	
	variable["sigma_s_limit"] = Dict()
	
	for br in net.branches
		if !br.is_in_service(); continue; end
		
		index = (br.name, br.bus_k.number, br.bus_m.number)
		
		variable["sigma_s_limit"][index] = @variable(model, lower_bound=0)
	end
end


function expresion_power_flow(network_model::ACPolarNetworkModel)
    net = network_model.net
    model = network_model.model
    variable = network_model.variable
	
	# Placeholder for power flow expresions
	variable["p_fr"] = Dict()
    variable["p_to"] = Dict()
    variable["q_fr"] = Dict()
    variable["q_to"] = Dict()

    p_fr = variable["p_fr"]
    p_to = variable["p_to"]
    q_fr = variable["q_fr"]
    q_to = variable["q_to"]
    vm = variable["vm"]
    va = variable["va"]

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

        p_fr[index] = @NLexpression(model, (g_k+g)*(vm[k]*t)^2 - vm[k]*vm[m]*t*(g*cos(dw) + b*sin(dw)))
        q_fr[index] = @NLexpression(model, -(b_k+b)*(vm[k]*t)^2 - vm[k]*vm[m]*t*(g*sin(dw) - b*cos(dw)))
        p_to[index] = @NLexpression(model, (g_m+g)*(vm[m])^2 - vm[k]*vm[m]*t*(g*cos(dw) - b*sin(dw)))
        q_to[index] = @NLexpression(model, -(b_m+b)*(vm[m])^2 + vm[k]*vm[m]*t*(g*sin(dw) + b*cos(dw)))
    end
end


function constraint_power_balance(network_model::ACPolarNetworkModel)
    net = network_model.net
    model = network_model.model
    variable = network_model.variable
	
	# Create power flow expresions
    if !(haskey(variable, "p_fr") || haskey(variable, "p_to") || haskey(variable, "q_fr") || haskey(variable, "q_to"))
        expresion_power_flow(network_model)
    end
	
	# Using fixed sh.b if shunts are not variables
    if !(haskey(variable, "b_sh"))
        variable["b_sh"] = Dict()
        for sh in net.shunts
            index = (sh.bus.number, sh.name)
            variable["b_sh"][index] = sh.b
        end
    end
    
    pg = variable["pg"]
    qg = variable["qg"]
    b_sh = variable["b_sh"]
    p_fr = variable["p_fr"]
    p_to = variable["p_to"]
    q_fr = variable["q_fr"]
    q_to = variable["q_to"]
    vm = variable["vm"]

    for bus in net.buses
        if !bus.is_in_service(); continue; end

        @NLconstraint(model,     
            sum(pg[gen.bus.number, gen.name] for gen in bus.generators if gen.is_in_service())
            - sum(load.P for load in bus.loads if load.is_in_service())
            - sum(sh.g * vm[bus.number]^2 for sh in bus.shunts if sh.is_in_service())
            - sum(p_fr[br.name, br.bus_k.number, br.bus_m.number] for br in bus.branches_k if br.is_in_service())
            - sum(p_to[br.name, br.bus_k.number, br.bus_m.number] for br in bus.branches_m if br.is_in_service())
            == 0.
        )

        @NLconstraint(model,     
            sum(qg[gen.bus.number, gen.name] for gen in bus.generators if gen.is_in_service()) 
            - sum(load.Q for load in bus.loads if load.is_in_service())
            + sum(b_sh[sh.bus.number, sh.name] * vm[bus.number]^2 for sh in bus.shunts if sh.is_in_service())
            - sum(q_fr[br.name, br.bus_k.number, br.bus_m.number] for br in bus.branches_k if br.is_in_service())
            - sum(q_to[br.name, br.bus_k.number, br.bus_m.number] for br in bus.branches_m if br.is_in_service())
            == 0.
        )
    end
end


function constraint_power_balance_soft(network_model::ACPolarNetworkModel)
    net = network_model.net
    model = network_model.model
    variable = network_model.variable
	
	# Create power flow expresions
    if !(haskey(variable, "p_fr") || haskey(variable, "p_to") || haskey(variable, "q_fr") || haskey(variable, "q_to"))
        expresion_power_flow(network_model)
    end
	
	# Using fixed sh.b if shunts are not variables
    if !(haskey(variable, "b_sh"))
        variable["b_sh"] = Dict()
        for sh in net.shunts
            index = (sh.bus.number, sh.name)
            variable["b_sh"][index] = sh.b
        end
    end
	
	# add slacks variables
	if !(haskey(variable, "sigma_p_mismatch_plus") || haskey(variable, "sigma_p_mismatch_minus") || haskey(variable, "sigma_q_mismatch_plus") || haskey(variable, "sigma_q_mismatch_minus"))
		variable_slack_power_balance(network_model)
	end
	
	sigma_p_mismatch_plus = variable["sigma_p_mismatch_plus"]
	sigma_p_mismatch_minus = variable["sigma_p_mismatch_minus"]
	sigma_q_mismatch_plus = variable["sigma_q_mismatch_plus"]
	sigma_q_mismatch_minus = variable["sigma_q_mismatch_minus"]
    
    pg = variable["pg"]
    qg = variable["qg"]
    b_sh = variable["b_sh"]
    p_fr = variable["p_fr"]
    p_to = variable["p_to"]
    q_fr = variable["q_fr"]
    q_to = variable["q_to"]
    vm = variable["vm"]
	
    for bus in net.buses
        if !bus.is_in_service(); continue; end

        @NLconstraint(model,     
            sum(pg[gen.bus.number, gen.name] for gen in bus.generators)
            - sum(load.P for load in bus.loads)
            - sum(sh.g * vm[bus.number]^2 for sh in bus.shunts)
            - sum(p_fr[br.name, br.bus_k.number, br.bus_m.number] for br in bus.branches_k)
            - sum(p_to[br.name, br.bus_k.number, br.bus_m.number] for br in bus.branches_m)
            == sigma_p_mismatch_plus[bus.number] + sigma_p_mismatch_minus[bus.number]
        )

        @NLconstraint(model,     
            sum(qg[gen.bus.number, gen.name] for gen in bus.generators) 
            - sum(load.Q for load in bus.loads)
            + sum(b_sh[sh.bus.number, sh.name] * vm[bus.number]^2 for sh in bus.shunts)
            - sum(q_fr[br.name, br.bus_k.number, br.bus_m.number] for br in bus.branches_k)
            - sum(q_to[br.name, br.bus_k.number, br.bus_m.number] for br in bus.branches_m)
            == sigma_q_mismatch_plus[bus.number] + sigma_q_mismatch_minus[bus.number]
        )
    end
end


function constraint_power_flow_limits(network_model::ACPolarNetworkModel)
    net = network_model.net
    model = network_model.model
    variable = network_model.variable
	
	# Compute branch power expresions
    if !(haskey(variable, "p_fr") || haskey(variable, "p_to") || haskey(variable, "q_fr") || haskey(variable, "q_to"))
        expresion_power_flow(network_model)
    end

    p_fr = variable["p_fr"]
    p_to = variable["p_to"]
    q_fr = variable["q_fr"]
    q_to = variable["q_to"]
    vm = variable["vm"]

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

        if br.is_line()
            @NLconstraints(model, begin
                p_fr[index]^2 + q_fr[index]^2 <= (rate * vm[k])^2
                p_to[index]^2 + q_to[index]^2 <= (rate * vm[m])^2
            end)
        else
            @NLconstraints(model, begin
                p_fr[index]^2 + q_fr[index]^2 <= rate^2
                p_to[index]^2 + q_to[index]^2 <= rate^2
            end)
        end
    end
end


function constraint_power_flow_limits_soft(network_model::ACPolarNetworkModel)
    net = network_model.net
    model = network_model.model
    variable = network_model.variable
	
	# Compute branch power expresions
    if !(haskey(variable, "p_fr") || haskey(variable, "p_to") || haskey(variable, "q_fr") || haskey(variable, "q_to"))
        expresion_power_flow(network_model)
    end
	
	# Add slack variables
	if !(haskey(variable, "sigma_s_limit"))
		variable_slack_power_flow_limits(network_model)
	end
	
	sigma_s_limit = variable["sigma_s_limit"]
	
    p_fr = variable["p_fr"]
    p_to = variable["p_to"]
    q_fr = variable["q_fr"]
    q_to = variable["q_to"]
    vm = variable["vm"]
	
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

        if br.is_line()
            @NLconstraints(model, begin
                p_fr[index]^2 + q_fr[index]^2 <= (rate * vm[k] + sigma_s_limit[index])^2
                p_to[index]^2 + q_to[index]^2 <= (rate * vm[m] + sigma_s_limit[index])^2
            end)
        else
            @NLconstraints(model, begin
                p_fr[index]^2 + q_fr[index]^2 <= (rate + sigma_s_limit[index])^2
                p_to[index]^2 + q_to[index]^2 <= (rate + sigma_s_limit[index])^2
            end)
        end
    end
end


function constraint_reference_bus(network_model::ACPolarNetworkModel)
    net = network_model.net
    model = network_model.model
    variable = network_model.variable

    va = variable["va"]

    for bus in net.buses
        if !bus.is_in_service(); continue; end

        if bus.is_slack()
            @constraint(model, va[bus.number] == bus.v_ang)
        end
    end
end


function constraint_gen_pv(network_model::ACPolarNetworkModel)
    net = network_model.net
    model = network_model.model
    variable = network_model.variable

    for bus in net.buses
        if !!bus.is_in_service(); continue; end
        if !bus.is_regulated_by_gen(); continue; end

        fix(variable["vm"][bus.number], bus.v_mag)

        # Get generator vars free to slack bus
        if bus.is_slack(); continue; end

        for gen in bus.generators
            index = (gen.bus.number, gen.name)
            fix(variable["pg"][index], gen.P)
        end
    end
end


function objective_generator_cost(network_model::ACPolarNetworkModel)
    update_generator_costs!(network_model)
    net = network_model.net
    model = network_model.model
    pg = network_model.variable["pg"]

    @objective(model, Min, 
    sum(
        gen.cost_coeff_Q2 * pg[gen.bus.number, gen.name]^2 +
        gen.cost_coeff_Q1 * pg[gen.bus.number, gen.name] +
        gen.cost_coeff_Q0
        for gen in net.generators)
    )
end


function objective_generator_cost_plus_penalties(network_model::ACPolarNetworkModel, kwargs...)
    update_generator_costs!(network_model)
    net = network_model.net
    model = network_model.model
	variable = network_model.variable
	
	# default penalty coefficients
    dict_kwargs = Dict(kwargs)
	c_s = haskey(dict_kwargs, :c_s) ? dict_kwargs[:c_s] : 1e3 * net.base_power
	c_p = haskey(dict_kwargs, :c_s) ? dict_kwargs[:c_p] : 1e3 * net.base_power
	c_q = haskey(dict_kwargs, :c_q) ? dict_kwargs[:c_q] : 1e3 * net.base_power
	
    pg = variable["pg"]
	sigma_s_limit = variable["sigma_s_limit"]
	sigma_p_mismatch_plus = variable["sigma_p_mismatch_plus"]
	sigma_p_mismatch_minus = variable["sigma_p_mismatch_minus"]
	sigma_q_mismatch_plus = variable["sigma_q_mismatch_plus"]
	sigma_q_mismatch_minus = variable["sigma_q_mismatch_minus"]
	
    @objective(model, Min, 
    sum(
        gen.cost_coeff_Q2 * pg[gen.bus.number, gen.name]^2 +
        gen.cost_coeff_Q1 * pg[gen.bus.number, gen.name] +
        gen.cost_coeff_Q0
        for gen in net.generators) + 
	c_s * sum(s_limit for s_limit in values(sigma_s_limit)) +
	c_p * sum(p_mis for p_mis in values(sigma_p_mismatch_plus)) +
	c_p * sum(p_mis for p_mis in values(sigma_p_mismatch_minus)) +
	c_q * sum(q_mis for q_mis in values(sigma_q_mismatch_plus)) +
	c_q * sum(q_mis for q_mis in values(sigma_q_mismatch_minus))
    )
	
end


"""
Update the results of the optimization model ´network_model.model´
to the ´network_model.net´ PFNET network
"""
function update_network!(network_model::ACPolarNetworkModel)
    net = network_model.net
    variable = network_model.variable
    vm = variable["vm"]
    va = variable["va"]
    pg = variable["pg"]
    qg = variable["qg"]
    b_sh = variable["b_sh"]

    for bus in net.buses
        if !bus.is_in_service(); continue; end
    
        bus.v_mag = JuMP.value(vm[bus.number])
        bus.v_ang = JuMP.value(va[bus.number])
    end

    for gen in net.generators
        if !gen.is_in_service(); continue; end

        index = (gen.bus.number, gen.name)

        gen.P = JuMP.value(pg[index])
        gen.Q = JuMP.value(qg[index])
        gen.bus.v_set = JuMP.value(vm[gen.bus.number])

    end

    for sh in net.shunts
        if !sh.is_in_service(); continue; end
        
        index = (sh.bus.number, sh.name)
        sh.b = JuMP.value(b_sh[index])
    end

    net.update_properties()
end
