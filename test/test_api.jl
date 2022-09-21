@testset "Test simulation from JSON" begin
    # The system needs to be created locally before we can do this.
    sys = PSB.build_system(PSITestSystems, "c_sys5_uc")
    sys_dir = mktempdir()
    sys_file = joinpath(sys_dir, "sys.json")
    PSY.to_json(sys, sys_file)
    sim_file = joinpath(DATA_DIR, "sim_from_api.json")
    api_sim = open(sim_file) do io
        JSON3.read(io, PSI.Api.Simulation)
    end
    api_sim.models.decision_models[1].system_path = sys_file
    sim_dir = mktempdir()
    sim = Simulation(api_sim, sim_dir)
    @test build!(sim) == PSI.BuildStatus.BUILT 
    @test execute!(sim) == PSI.RunStatus.SUCCESSFUL
end
