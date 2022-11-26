

abstract type AbstractNetworkModel end

abstract type AbstractACNetworkModel <: AbstractNetworkModel end

mutable struct ACPolarNetworkModel <: AbstractACNetworkModel
    net
    rop
    inl
    con
    model::JuMP.Model
    variable::Dict
end
