

abstract type AbstractNetworkModel end

abstract type AbstractACNetworkModel <: AbstractNetworkModel end

mutable struct ACPolarNetworkModel <: AbstractACNetworkModel
    net
    rop
    inl
    con
    scenarios::Vector
end

