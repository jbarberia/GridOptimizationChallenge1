#=
This file contains common constraints and constraints interfaces to pass to extract the data and pass tp the corresponding dunction trough dispatch
=#


function constraint_power_balance_with_shunts(pm::PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    # just an interface to the function trough multiple dispatch
    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = ref(pm, nw, :bus_arcs_dc, i)
    bus_arcs_sw = ref(pm, nw, :bus_arcs_sw, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_storage = ref(pm, nw, :bus_storage, i)

    bus_shunts_const = ref(pm, :bus_shunts_const, i)
    bus_shunts_var = ref(pm, :bus_shunts_var, i)

    bus_pd = Dict(k => ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => ref(pm, nw, :load, k, "qd") for k in bus_loads)

    bus_gs_const = Dict(k => ref(pm, :shunt, k, "gs") for k in bus_shunts_const)
    bus_bs_const = Dict(k => ref(pm, :shunt, k, "bs") for k in bus_shunts_const)

    constraint_power_balance_with_shunts(pm, nw, i, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_shunts_var, bus_pd, bus_qd, bus_gs_const, bus_bs_const)
end


function constraint_power_flow_from(pm::PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = PM.calc_branch_y(branch)
    tr, ti = PM.calc_branch_t(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    tm = branch["tap"]

    constraint_power_flow_from(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
end


function constraint_power_flow_to(pm::PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = PM.calc_branch_y(branch)
    tr, ti = PM.calc_branch_t(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]

    constraint_power_flow_to(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
end


function constraint_thermal_limit_line_from_soft(pm::PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    if haskey(branch, "rate_a")
        constraint_thermal_limit_line_from(pm, nw, f_idx, branch["rate_a"])
    end
end


function constraint_thermal_limit_line_to_soft(pm::PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    if haskey(branch, "rate_a")
        constraint_thermal_limit_to_from(pm, nw, t_idx, branch["rate_a"])
    end
end


function constraint_thermal_limit_transformer_from_soft(pm::PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    if haskey(branch, "rate_a")
        constraint_thermal_limit_line_from(pm, nw, f_idx, branch["rate_a"])
    end
end


function constraint_thermal_limit_transformer_to_soft(pm::PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    if haskey(branch, "rate_a")
        constraint_thermal_limit_to_from(pm, nw, t_idx, branch["rate_a"])
    end
end
