@testset "Test generate_formulation_combinations" begin
    res = PSI.generate_formulation_combinations()
    found_valid_device = false
    found_invalid_device = false
    found_valid_service = false
    found_invalid_service = false

    for item in res["device_formulations"]
        if item["device_type"] == PSY.ThermalStandard &&
           item["formulation"] == PSI.ThermalBasicCompactUnitCommitment
            found_valid_device = true
        end
    end

    for item in res["service_formulations"]
        if item["service_type"] == PSY.ConstantReserveNonSpinning &&
           item["formulation"] == PSI.NonSpinningReserve
            found_valid_service = true
        end
        #if item["service_type"] == PSY.AGC && item["formulation"] == PSI.NonSpinningReserve
        #    found_invalid_service = true
        #end
    end

    @test found_valid_device
    @test !found_invalid_device
    @test found_valid_service
    @test !found_invalid_service
end

@testset "Test generate_formulation_combinations with system" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
    res1 = PSI.generate_formulation_combinations()
    res2 = PSI.generate_formulation_combinations(sys)
    @test length(res1["device_formulations"]) > length(res2["device_formulations"])
    @test length(res1["service_formulations"]) > length(res2["service_formulations"])

    device_types = Set((typeof(x) for x in PSY.get_components(PSY.Device, sys)))
    diff = setdiff((x["device_type"] for x in res2["device_formulations"]), device_types)
    @test isempty(diff)

    service_types = Set((typeof(x) for x in PSY.get_components(PSY.Service, sys)))
    diff = setdiff((x["service_type"] for x in res2["service_formulations"]), service_types)
    @test isempty(diff)
end

@testset "Test write_formulation_combinations" begin
    res = PSI.generate_formulation_combinations()

    filename = joinpath(tempdir(), "data.json")
    @test !isfile(filename)
    try
        PSI.write_formulation_combinations(filename)
        @test isfile(filename)
        data = open(filename) do io
            JSON3.read(io, Dict)
        end
        @test "device_formulations" in keys(data)
        @test length(data["device_formulations"]) == length(res["device_formulations"])
        @test "service_formulations" in keys(data)
        @test length(data["service_formulations"]) == length(res["service_formulations"])
    finally
        isfile(filename) && rm(filename)
    end
end
