using Dates
using GLPK
using JuMP
using MathOptInterface
using PowerSystems
using PowerSimulations
using Test
using TimeSeries


const EVIPRO_DATA = abspath(joinpath(dirname(Base.find_package("PowerSystems")), "..", "data", "evi-pro", "FlexibleDemand_1000.mat"))


function augment(bev)
    bev = @set bev.power     = update(bev.power    , Time(23,59,59,999), NaN                       )
    bev = @set bev.locations = update(bev.locations, Time(23,59,59,999), ("", (ac = NaN, dc = NaN)))
    bev
end


function checkcharging(f)
    bevs = populate_BEV_demand(EVIPRO_DATA)
    the_optimizer = with_optimizer(GLPK.Optimizer)
    deltamax = 0
    i = 0
    for bev in bevs
        i += 1
        bev = augment(bev)
        if bev.capacity.max <= 25 # FIXME: Exclude vehicles with small batteries.
            continue
        end
        @test begin
            problem = f(bev)
            JuMP.optimize!(problem.model, the_optimizer)
            optimizeresult = JuMP.termination_status(problem.model) == MathOptInterface.OPTIMAL
            if !optimizeresult
                @warn string("BEV ", i, " in '", EVIPRO_DATA, "' solution failed with ", JuMP.termination_status(problem.model), ".")
            end
            charging = problem.result()
            delta = shortfall(bev, charging)
            deltamax = max(deltamax, abs(delta))
            energyresult = abs(delta) <= 1e-5
            if optimizeresult && !energyresult
                @warn string("BEV ", i, " in '", EVIPRO_DATA, "' has charging shortfall of ", delta, " kWh.")
            end
            limitresult = verifylimits(bev, charging)
            if optimizeresult && !limitresult
                @warn string("BEV ", i, " in '", EVIPRO_DATA, "' violates charging limits.")
            end
            batteryresult = verifybattery(bev, charging)
            if optimizeresult && !batteryresult
                @warn string("BEV ", i, " in '", EVIPRO_DATA, "' violates battery limits.")
            end
            optimizeresult && energyresult && limitresult && batteryresult
        end
    end
    @debug string("Maximum charging discrepancy: ", deltamax, " kWh.")
end


@testset "Price-insensitive constraints for demands on EVIpro dataset" begin
    checkcharging(demandconstraints)
end
