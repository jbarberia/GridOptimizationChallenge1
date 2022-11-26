

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
        JuMP.Model(optimizer),
        Dict()
    )

    return network_model
end

"""
Returns a mapping with a representation of the 4 input files for the GOC1.
Does not check duplicates.
"""
function read_directory(directory::String)
    parse_file_with_extension = Dict(
        "raw" => x -> pfnet.PyParserRAW().parse(x),
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
function optimize!(network_model::AbstractNetworkModel)
    JuMP.optimize!(network_model.model)
end


"""
Build, solves and update data for a given optimization problem
"""
function solve!(network_model, builder)
    builder(network_model)
    optimize!(network_model)
    update_network!(network_model)
end