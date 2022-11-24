

"""
Update ´cost_coeff_Q´ in the generators of the ´network_model.net´

Units of coefficients:
- cost_coeff_Q0 [$/hr]
- cost_coeff_Q1 [$/hr/pu]
- cost_coeff_Q2 [$/hr/pu^2]
"""
function update_generator_costs!(network_model::NetworkModel)
    net = network_model.net
    rop = network_model.rop

    for gen in net.generators
        gen_name = " "^(2-length(gen.name|>strip)) * (gen.name|>strip)
        index = (gen.bus.number, gen_name)
        Q2, Q1, Q0 = rop[index]["coefficients"]
    
        gen.cost_coeff_Q0 = Q0
        gen.cost_coeff_Q1 = Q1 * net.base_power
        gen.cost_coeff_Q2 = Q2 * net.base_power^2
    end
end

