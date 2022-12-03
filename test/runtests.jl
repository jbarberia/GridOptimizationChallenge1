using GridOptimizationChallenge1
using Test
import Ipopt
import JuMP

nlp_solver = JuMP.optimizer_with_attributes(
    Ipopt.Optimizer,
    "print_level" => 2,
    "tol" => 1e-8
)

@testset "Network creation" begin
    network_model = create_network("./scenario_1", ACPolarNetworkModel, nlp_solver)

    @test network_model.con isa Vector{Dict{Any, Any}}
    @test network_model.inl isa Dict{Any, Any}
    @test network_model.rop isa Dict{Any, Any}

    @test network_model.net.get_num_buses() == 500
    @test network_model.net.get_num_generators() == 224
    @test network_model.net.get_num_generators_out_of_service() == 70
    @test network_model.con[1]["name"] == "G_000272NORTHPORT31U1"
    @test network_model.inl[472, "2 "]["alpha_g"] == 24.5
    @test network_model.rop[472, "2 "]["x"] |> length == network_model.rop[472, "2 "]["n_points"]
end


@testset "OPF base case scenario_1" begin
    @testset "hard formulation" begin
        network_model = create_network("./scenario_1/", ACPolarNetworkModel, nlp_solver)
        build_opf(network_model)
        optimize!(network_model)
        update_network!(network_model)
        
        @test network_model.net.get_generator_from_name_and_bus_number("3 ", 499).is_in_service() == false
        @test JuMP.value(network_model.scenarios[1][:pg][499, "3 "]) == 0.

        @test network_model.net.gen_P_cost <= 2.80e6
    end
    
    @testset "soft formulation" begin
        network_model = create_network("./scenario_1/", ACPolarNetworkModel, nlp_solver)
        build_opf_soft(network_model)
        optimize!(network_model)
        update_network!(network_model)
    
        @test network_model.net.gen_P_cost <= 2.80e6    
    end
end


@testset "PF solver" begin
    @testset "scenario_1/" begin
        network_model = create_network("./scenario_1/", ACPolarNetworkModel, nlp_solver)
        
        pre_bus_p_mis = network_model.net.bus_P_mis
        pre_bus_q_mis = network_model.net.bus_Q_mis
        
        build_pf(network_model)
        optimize!(network_model)
        update_network!(network_model)
        
        post_bus_p_mis = network_model.net.bus_P_mis
        post_bus_q_mis = network_model.net.bus_Q_mis

        @test pre_bus_p_mis >= post_bus_p_mis
        @test pre_bus_q_mis >= post_bus_q_mis

        @test post_bus_p_mis <= 1e-8
        @test post_bus_p_mis <= 1e-8
    end
    
end


@testset "Contingencies" begin
    @testset "scenario_1/" begin
        network_model = create_network("./scenario_1/", ACPolarNetworkModel, nlp_solver)
        network_model.con = [network_model.con[1]]

        build_opf(network_model)
        build_opf(network_model, 2)

        @test length(network_model.scenarios[1][:pg]) == length(network_model.scenarios[2][:pg])        
        @test length(network_model.scenarios[1][:qg]) == length(network_model.scenarios[2][:qg])        
    end
end


@testset "SCOPF solver" begin
    
    @testset "iterative cuts" begin
        network_model = create_network("./scenario_1/", ACPolarNetworkModel, nlp_solver)
        network_model.con = [network_model.con[1], network_model.con[end]]
        solve_benders_cuts_scopf(network_model)


    end
end