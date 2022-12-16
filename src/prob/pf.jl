"""
A simple PF formulation with generator response
"""
function build_pf_generator_response(pm::PM.AbstractPowerModel)
    # -- Variables
    PM.variable_bus_voltage(pm, bounded=false)
    PM.variable_gen_power(pm, bounded=false)
    PM.variable_branch_power(pm, bounded=false)
    
    variable_gen_power_slack(pm)
    variable_shunt_admitance_imaginary(pm)

    PM.constraint_model_voltage(pm)

    # -- Constraints
    for i in ids(pm, :ref_buses)
        PM.constraint_theta_ref(pm, i)
        PM.constraint_voltage_magnitude_setpoint(pm, i)
    end

    for (i, bus) in ref(pm, :bus)
        constraint_power_balance_with_shunts(pm, i)

        if bus["bus_type"] == 2
        #    PM.constraint_voltage_magnitude_setpoint(pm, i)
        end
    end

    for (i, gen) in ref(pm, :gen)
        if gen["pg_fixed"] == true
            constraint_gen_setpoint_active(pm, i)
        else
            constraint_gen_response_active(pm, i)
        end
    end

    for (i, branch) in ref(pm, :branch)
        constraint_power_flow_from(pm, i)
        constraint_power_flow_to(pm, i)
    end

    # -- Objective
    @objective(pm.model, Min,
        5e5*sum(var(pm, :pg_slack_pos, i) for (i, gen) in ref(pm, :gen))+
        5e5*sum(var(pm, :pg_slack_neg, i) for (i, gen) in ref(pm, :gen))
    )
end
