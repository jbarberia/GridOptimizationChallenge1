

"""
Given a dict data format network performs all the set-up to run a model for that case
- Set up rating
- Set up voltages bounds
- Set up initial values
"""
function set_up_network_to_contingency!(network::Dict{String, Any})

    for (i,bus) in network["bus"]
        bus["vmax"] = get(bus, "evhi", bus["vmax"])
        bus["vmin"] = get(bus, "evlo", bus["vmin"])
    end

    for (i,branch) in network["branch"]
        branch["rate_a"] = get(branch, "rate_c", branch["rate_a"])
    end

    network["delta"] = 0.0

    for (i,bus) in network["bus"]
        bus["vm_base"] = bus["vm"]
        bus["vm_start"] = bus["vm"]
        bus["va_start"] = bus["va"]
        bus["vm_fixed"] = bus["bus_type"] == 2
    end

    for (i,gen) in network["gen"]
        gen["pg_base"] = gen["pg"]
        gen["pg_start"] = gen["pg"]
        gen["qg_start"] = gen["qg"]
        gen["pg_fixed"] = false
        gen["qg_fixed"] = false
    end
    
end

"""
Compute the `pg_loss` of the contingency.
Apply generator response flags.
"""
function apply_gen_contingency!(network::Dict{String, Any}, contingency::NamedTuple)
    network["cont_label"] = contingency.label

    # Set generator status
    contingency_gen = network["gen"]["$(contingency.idx)"]
    contingency_gen["contingency"] = true
    contingency_gen["gen_status"] = 0
    
    # Set area response flags
    gen_bus = network["bus"]["$(contingency_gen["gen_bus"])"]
    network["response_gens"] = network["area_gens"][gen_bus["area"]]
    
    # Compute the pg loss (not set `pg` to zero because gen is already o.o.s.)
    pg_loss = contingency_gen["pg"]
    return pg_loss
end

"""
Add some status mapping to results and correct the contingency solution
"""
function apply_contingency_post_processor!(network, result, contingency)
    result["solution"]["label"] = contingency.label
    result["solution"]["feasible"] = result["termination_status"] == LOCALLY_SOLVED
    result["solution"]["cont_type"] = contingency.type
    result["solution"]["cont_comp_id"] = contingency.idx

    PMSC.correct_c1_contingency_solution!(network, result["solution"])
end


"""
Compute the `pg_loss` of the contingency.
Apply generator response flags.
"""
function apply_branch_contingency!(network::Dict{String, Any}, contingency::NamedTuple)
    network["cont_label"] = contingency.label

    # Set branch status
    contingency_branch = network["branch"]["$(contingency.idx)"]
    contingency_branch["contingency"] = true
    contingency_branch["br_status"] = 0

    # Set area response flags
    fr_bus = network["bus"]["$(contingency_branch["f_bus"])"]
    to_bus = network["bus"]["$(contingency_branch["t_bus"])"]
    
    network["response_gens"] = Set()
    if haskey(network["area_gens"], fr_bus["area"])
        network["response_gens"] = network["area_gens"][fr_bus["area"]]
    end
    if haskey(network["area_gens"], to_bus["area"])
        network["response_gens"] = union(network["response_gens"], network["area_gens"][to_bus["area"]])
    end

    # Compute `pg_loss`
    pg_loss = 0
    return pg_loss
end