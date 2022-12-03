

"""
Returns a `network_model` of the given type
"""
function create_network(directory::String, type::DataType, optimizer)
    raw_data = read_directory(directory)

    network_model = type(
        raw_data["raw"],
        raw_data["rop"],
        raw_data["inl"],
        raw_data["con"],
        [JuMP.Model(optimizer) for con in 1:(1+length(raw_data["con"]))] # 1 is base_case
    )

    return network_model
end

"""
Returns a mapping with a representation of the 4 input files for the GOC1.
Does not check duplicates.
"""
function read_directory(directory::String)

    py_parser_raw = pfnet.PyParserRAW()
    py_parser_raw.set("keep_all_out_of_service", true)

    parse_file_with_extension = Dict(
        "raw" => x -> py_parser_raw.parse(x),
        "rop" => x -> GOC_IO.parse_rop(x),
        "inl" => x -> GOC_IO.parse_inl(x),
        "con" => x -> GOC_IO.parse_con(x),
    )

    data = Dict()
    for file in readdir(directory)
        extension = split(file, ".")[end]
        data[extension] = parse_file_with_extension[extension]("$directory/$file")
    end

    !haskey(data, "raw") && error("`.raw` file not found in $(directory)")
    !haskey(data, "rop") && error("`.rop` file not found in $(directory)")
    !haskey(data, "inl") && error("`.inl` file not found in $(directory)")
    !haskey(data, "con") && error("`.con` file not found in $(directory)")

    return data
end


"""
Update ´cost_coeff_Q´ in the generators of the ´network_model.net´

Units of coefficients:
- cost_coeff_Q0 [\$/hr]
- cost_coeff_Q1 [\$/hr/pu]
- cost_coeff_Q2 [\$/hr/pu^2]
"""
function update_generator_costs!(network_model::AbstractNetworkModel)
    net = network_model.net
    rop = network_model.rop

    for gen in net.generators
        gen_name = gen.name
        index = (gen.bus.number, gen_name)
        Q2, Q1, Q0 = rop[index]["coefficients"]
    
        gen.cost_coeff_Q0 = Q0
        gen.cost_coeff_Q1 = Q1 * net.base_power
        gen.cost_coeff_Q2 = Q2 * net.base_power^2
    end
end


"""
Solves the JuMP optimization model
"""
function optimize!(network_model::AbstractNetworkModel, scenario=1)
    model = network_model.scenarios[scenario]
    JuMP.optimize!(model)
end


"""
Build, solves and update data for a given optimization problem
"""
function solve!(network_model, builder)
    builder(network_model)
    optimize!(network_model)
    update_network!(network_model)
end


"""
Apply a contingency to `network_model.net`
"""
function apply_contingency(network_model, scenario)
    contingency = network_model.con[scenario-1]
    net = network_model.net
    
    event = contingency["event"]
    if event == "Branch Out-of-Service"
        bus_k, bus_m, name = contingency["id"]
        br = net.get_branch_from_name_and_bus_numbers(name, bus_k, bus_m)
        pfnet_contingency = pfnet.Contingency(branches=[br])

    elseif event == "Generator Out-of-Service"
        bus, name = contingency["id"]
        gen = net.get_generator_from_name_and_bus_number(name, bus)
        pfnet_contingency = pfnet.Contingency(generators=[gen])
    else
        error("Invalid type of contingency (got: $event)")
    end
    pfnet_contingency.apply(net)
    return pfnet_contingency
end


"""
Clear the `network_model.net` contingency
"""
function clear_contingency(network_model, contingency)
    contingency.clear(network_model.net)
end
