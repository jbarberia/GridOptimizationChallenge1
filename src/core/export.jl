# This file is a copy of: https://github.com/lanl-ansi/PowerModels.jl/blob/master/src/core/export.jl
# exports everything except internal symbols, which are defined as
# those whose name starts with an underscore.

const _EXCLUDE_SYMBOLS = [Symbol(@__MODULE__), :eval, :include]

for sym in names(@__MODULE__, all=true)
    sym_string = string(sym)
    if sym in _EXCLUDE_SYMBOLS || startswith(sym_string, "_") || startswith(sym_string, "@_")
        continue
    end
    if !(Base.isidentifier(sym) || (startswith(sym_string, "@") &&
         Base.isidentifier(sym_string[2:end])))
       continue
    end
    @eval export $sym
end


# the follow items are also exported for user-friendlyness when calling
# `using PowerModels`

# so that users do not need to import JuMP to use a solver with PowerModels
import JuMP: optimizer_with_attributes
export optimizer_with_attributes

import JuMP: TerminationStatusCode
export TerminationStatusCode

import JuMP: ResultStatusCode
export ResultStatusCode

for status_code_enum in [TerminationStatusCode, ResultStatusCode]
    for status_code in instances(status_code_enum)
        @eval import JuMP: $(Symbol(status_code))
        @eval export $(Symbol(status_code))
    end
end

# from PowerModels
export solve_model

# from PowerModelsSecurityConstrained
export parse_c1_files, build_c1_pm_model, update_data!, correct_c1_solution!, ref_c1!

# from InfrastructureModels
export ids, ref, var, con, sol, nw_ids, nws, optimize_model!, nw_id_default
