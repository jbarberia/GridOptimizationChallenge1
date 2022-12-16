"""
An OPF formulation with soft thermal limits on branches 
"""
function build_opf_branch_thermal_limit_soft(pm::PM.AbstractPowerModel)
    # -- Variables
    PM.variable_bus_voltage(pm)
    PM.variable_gen_power(pm)
    PM.variable_branch_power(pm, bounded=false)

    variable_branch_power_slack(pm)
    variable_shunt_admitance_imaginary(pm)

    PM.constraint_model_voltage(pm)

    # -- Constraints
    for i in ids(pm, :ref_buses)
        PM.constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance_with_shunts(pm, i)
    end

    for (i, branch) in ref(pm, :branch)
        constraint_power_flow_from(pm, i)
        constraint_power_flow_to(pm, i)

        if branch["source_id"] == "branch"
            constraint_thermal_limit_line_from_soft(pm, i)
            constraint_thermal_limit_line_to_soft(pm, i)
            
        elseif branch["source_id"] == "transformer"
            constraint_thermal_limit_transformer_from_soft(pm, i)
            constraint_thermal_limit_transformer_to_soft(pm, i)
        end
    end

    # -- Objective
    PM.objective_variable_pg_cost(pm)
    pg_cost = var(pm, :pg_cost)
    sm_slack = var(pm, :sm_slack)

    @objective(pm.model, Min,
        sum(pg_cost[i] for (i,gen) in ref(pm,:gen))+
        5e5*sum(sm_slack[l] for (l,branch) in ref(pm, :branch_sm_active))
    )
end


"""
An OPF formulation with soft thermal limits on branches
Cuts are added as power bus injections
TODO -> implement it
"""
function build_opf_with_cuts_branch_thermal_limit_soft(pm::PM.AbstractPowerModel)
    # -- Variables
    PM.variable_bus_voltage(pm)
    PM.variable_gen_power(pm)
    PM.variable_branch_power(pm, bounded=false)

    variable_branch_power_slack(pm)
    variable_shunt_admitance_imaginary(pm)

    PM.constraint_model_voltage(pm)

    # -- Constraints
    for i in ids(pm, :ref_buses)
        PM.constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance_with_shunts(pm, i)
    end

    for (i, branch) in ref(pm, :branch)
        constraint_power_flow_from(pm, i)
        constraint_power_flow_to(pm, i)

        if branch["source_id"] == "branch"
            constraint_thermal_limit_line_from_soft(pm, i)
            constraint_thermal_limit_line_to_soft(pm, i)
            
        elseif branch["source_id"] == "transformer"
            constraint_thermal_limit_transformer_from_soft(pm, i)
            constraint_thermal_limit_transformer_to_soft(pm, i)
        end
    end

    # -- Objective
    PM.objective_variable_pg_cost(pm)
    pg_cost = var(pm, :pg_cost)
    sm_slack = var(pm, :sm_slack)

    @objective(pm.model, Min,
        sum(pg_cost[i] for (i,gen) in ref(pm,:gen))+
        5e5*sum(sm_slack[l] for (l,branch) in ref(pm, :branch_sm_active))
    )
end

