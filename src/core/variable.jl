#=
This file contains the variable definitions for the powermodel
=#

### shunt ###

function variable_shunt_admitance_imaginary(pm::PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    bs = var(pm, nw)[:bs] = @variable(pm.model,
        [i in ids(pm, nw, :shunt_var)], base_name="$(nw)_bs",
        start=PM.comp_start_value(ref(pm, nw, :shunt, i), "bs_start")
    )

    if bounded
        for i in ids(pm, nw, :shunt_var)
            shunt = ref(pm, nw, :shunt, i)
            JuMP.set_lower_bound(bs[i], shunt["bmin"])
            JuMP.set_upper_bound(bs[i], shunt["bmax"])
        end
    end

    report && PM.sol_component_value(pm, nw, :shunt, :bs, ids(pm, nw, :shunt_var), bs)
end

### branch ###

function variable_branch_power_slack(pm::PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    sm_slack = var(pm, nw)[:sm_slack] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :branch_sm_active)], base_name="$(nw)_sm_slack",
        start=PM.comp_start_value(ref(pm, nw, :branch, l), "sm_slack_start")
    )

    if bounded
        for (l,branch) in ref(pm, nw, :branch_sm_active)
            JuMP.set_lower_bound(sm_slack[l], 0.0)
        end
    end

    report && PM.sol_component_value(pm, nw, :branch, :sm_slack, ids(pm, nw, :branch_sm_active), sm_slack)
end

### gen ###

function variable_gen_power_slack(pm::PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    variable_gen_power_slack_positive(pm, nw=nw, bounded=bounded, report=report)
    variable_gen_power_slack_negative(pm, nw=nw, bounded=bounded, report=report)
end


function variable_gen_power_slack_positive(pm::PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    pg_slack_pos = var(pm, nw)[:pg_slack_pos] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :gen)], base_name="$(nw)_pg_slack_pos",
        start = 0
    )

    if bounded
        for (i, gen) in ref(pm, nw, :gen)
            JuMP.set_lower_bound(pg_slack_pos[i], 0)
        end
    end

    report && sol_component_value(pm, nw, :gen, :pg_slack_pos, ids(pm, nw, :gen), pg_slack_pos)
end


function variable_gen_power_slack_negative(pm::PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    pg_slack_neg = var(pm, nw)[:pg_slack_neg] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :gen)], base_name="$(nw)_pg_slack_neg",
        start = 0
    )

    if bounded
        for (i, gen) in ref(pm, nw, :gen)
            JuMP.set_lower_bound(pg_slack_neg[i], 0)
        end
    end

    report && sol_component_value(pm, nw, :gen, :pg_slack_neg, ids(pm, nw, :gen), pg_slack_neg)
end
