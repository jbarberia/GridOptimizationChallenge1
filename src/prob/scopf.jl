

"""
Solves the SCOPF with soft constraint and iterative cuts
"""
function solve_benders_cuts_scopf(network_model)
    net = network_model.net


    # Solve base case
    solve!(network_model, build_opf_soft)

    # Check any contingency
    cuts = []
    for contingency in network_model.con
        network_con_model = deepcopy(network_model)
        
        event = contingency["event"]
        if event == "Branch Out-of-Service"
            bus_k, bus_m, name = contingency["id"]
            br = net.get_branch_from_name_and_bus_numbers(name, bus_k, bus_m)
            net_contingency = pfnet.Contingency(branches=[br])

        elseif event == "Generator Out-of-Service"
            bus, name = contingency["id"]
            gen = net.get_generator_from_name_and_bus_number(name, bus)
            net_contingency = pfnet.Contingency(generators=[gen])
        else
            error("Invalid type of contingency (got: $event)")
        end

        # Solve PF (TODO: use `build_contingency_pf`)
        # TODO actualizar y pensar idea
        net_contingency.apply(net)
        solve!(network_con_model, build_pf)

        # Compute cut
    end
end