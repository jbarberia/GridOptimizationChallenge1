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
    result = solve_model(network, PM.ACPPowerModel, nlp_solver, build_opf, ref_extensions=[ref_c1!])
    
    # Update and correct solution
    update_data!(network, result["solution"])
    correct_c1_solution!(network)

    # Testing
    @test result["primal_status"] == MOI.FEASIBLE_POINT
    @test result["dual_status"] == MOI.FEASIBLE_POINT
end