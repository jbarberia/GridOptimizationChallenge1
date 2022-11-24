module GridOptimizationChallenge1

using JuMP
using PyCall

# Python packages
const pfnet = PyNULL()
const GOC_IO = PyNULL()
function __init__()
	copy!(pfnet, pyimport("pfnet"))
	copy!(GOC_IO, pyimport("GOC_IO"))
end

include("utils.jl")

include("form/ac_polar.jl")
include("prob/opf.jl")	# OPF problems (base case)
include("prob/pf.jl")	# PF problems

end
