using GridOptimizationChallenge1
using Test
using JuMP
using Ipopt

nlp_solver = JuMP.optimizer_with_attributes(
    Ipopt.Optimizer,
    "print_level" => 5,
    "tol" => 1e-8
)

@testset "Example of resolution of the base case" begin
    # Read file
    goc_data = parse_c1_files(
        "scenario_1/case.con",
        "scenario_1/case.inl",
        "scenario_1/case.raw",
        "scenario_1/case.rop",
        scenario_id="scenario_1")
    network = build_c1_pm_model(goc_data)

    # Solve model
    result = solve_model(
        network,
        PM.ACPPowerModel,
        nlp_solver,
        build_opf_branch_thermal_limit_soft,
        ref_extensions=[ref_c1!],
        setting = Dict("output" => Dict("branch_flows" => true, "duals" => true)) # Compute branch flows & duals
    )
    
    # Update and correct solution
    update_data!(network, result["solution"])
    correct_c1_solution!(network)

    # Testing
    @test result["primal_status"] == MOI.FEASIBLE_POINT
    @test result["dual_status"] == MOI.FEASIBLE_POINT
end


@testset "Example of resolution of the contingency case" begin
    #= 
    This is a simple implementation. The network is solved trough an OPF of the base case
    Later the power flow is computed for each one of the contingencies

    DO NOT LOOP AGAIN TO FIX CONTINGENCIES IN THE BASE CASE

    How to evaluate this:

    python ~/.python/Evaluation/test.py scenario_1/case.raw scenario_1/case.rop scenario_1/case.con scenario_1/case.inl solution_1.txt ssolution_2.txt summary.csv detail.csv
    =#

    # Read file
    goc_data = parse_c1_files(
        "scenario_1/case.con",
        "scenario_1/case.inl",
        "scenario_1/case.raw",
        "scenario_1/case.rop",
        scenario_id="scenario_1")
    network = build_c1_pm_model(goc_data)

    # Setting output
    solution_path_1 = "solution_1.txt"
    solution_path_2 = "solution_2.txt"

    # Solve base case
    result = solve_model(
        network,
        PM.ACPPowerModel,
        nlp_solver,
        build_opf_branch_thermal_limit_soft,
        ref_extensions=[ref_c1!],
        setting = Dict("output" => Dict("branch_flows" => true, "duals" => true)) # Compute branch flows & duals
    )
    
    update_data!(network, result["solution"])
    correct_c1_solution!(network)
    sol1 = PMSC.write_c1_solution1(network, solution_file=solution_path_1)

    # Simulate contingencies
    set_up_network_to_contingency!(network)
    
    for contingency in network["gen_contingencies"]
        contingency_network = deepcopy(network)
        
        # Solve the PF contingency
        pg_loss = apply_gen_contingency!(contingency_network, contingency)
        result = PMSC.run_c1_fixpoint_pf_pvpq!(contingency_network, pg_loss, nlp_solver, iteration_limit=5)
        apply_contingency_post_processor!(contingency_network, result, contingency)

        # Writes the data in a file
        open(solution_path_2, "a") do sol_file
            sol2 = PMSC.write_c1_solution2_contingency(sol_file, network, result["solution"])
        end
    end
    
    for contingency in network["branch_contingencies"]
        contingency_network = deepcopy(network)
        
        # Solve the PF contingency
        pg_loss = apply_branch_contingency!(contingency_network, contingency)
        result = PMSC.run_c1_fixpoint_pf_pvpq!(contingency_network, pg_loss, nlp_solver, iteration_limit=5)
        apply_contingency_post_processor!(contingency_network, result, contingency)

        # Writes the data in a file
        open(solution_path_2, "a") do sol_file
            sol2 = PMSC.write_c1_solution2_contingency(sol_file, network, result["solution"])
        end
    end
    
    # Testing on the base case
    @test result["primal_status"] == MOI.FEASIBLE_POINT
    @test result["dual_status"] == MOI.FEASIBLE_POINT
    
end
