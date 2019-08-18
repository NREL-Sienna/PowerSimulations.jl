using Dates
using GLPK
using JuMP
using MathOptInterface
using PowerSimulations
using PowerSystems
using Test
using TimeSeries


const EVIPRO_DATA = abspath(joinpath(dirname(Base.find_package("PowerSystems")), "..", "data", "evi-pro", "FlexibleDemand_1000.mat"))

macro trytotest(f)
    if isfile(EVIPRO_DATA)
        f
    else
        @warn string("Demand-response tests not run because file '", EVIPRO_DATA, "' is missing.")
    end
end


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
        if bev.capacity.max < 30. # FIXME: Exclude vehicles with small batteries.
            continue
        end
        @test begin
            problem = f(bev)
            JuMP.optimize!(problem.model, the_optimizer)
            optimizeresult = JuMP.termination_status(problem.model) == MathOptInterface.OPTIMAL
            if !optimizeresult
                @warn string("BEV ", i, " in '", EVIPRO_DATA, "' solution failed with ", JuMP.termination_status(problem.model), ".")
                false
            else
                charging = problem.result() |> locateddemand
                verify(bev, charging, message=string("BEV ", i, " in '", EVIPRO_DATA, "'")) |> all
            end
        end
    end
    @debug string("Maximum charging discrepancy: ", deltamax, " kWh.")
end


@testset "Price-insensitive constraints for demands on EVIpro dataset" begin
    @trytotest begin
        checkcharging(demandconstraints)
    end
end


@testset "Price-sensitive constraints for demands on EVIpro dataset" begin
    pricing = TimeArray([Time(0), Time(12)], [10., 3.])
    @trytotest begin
        checkcharging(x -> demandconstraintsprices(x, pricing))
    end
end


@testset "Greedy price-sensitive strategy for constraints for demands on EVIpro dataset" begin
    pricing = TimeArray([Time(0), Time(12)], [10., 3.])
    @trytotest begin
        checkcharging(x -> demandconstraintsgreedy(x, pricing))
    end
end


@testset "Full-charge strategy for price-sensitive constraints for demands on EVIpro dataset" begin
    pricing = TimeArray([Time(0), Time(12)], [10., 3.])
    @trytotest begin
        checkcharging(x -> demandconstraintsfull(x, pricing))
    end
end
