module PowerSimulationsPlots

export get_stacked_plot_data
export get_bar_plot_data
export get_stacked_generation_data
export get_bar_gen_data
export bar_plot
export stack_plot
export report
export make_fuel_dictionary
export fuel_plot

import Dates
import TimeSeries
import RecipesBase
import Requires

#I/O Imports
import Colors
import DataFrames
import Feather

import PowerSimulations
import PowerSystems
import InfrastructureSystems

const PSI = PowerSimulations
const PSY = PowerSystems
const IS = InfrastructureSystems
include("plot_results.jl")
include("fuel_results.jl")
include("plot_recipes.jl")
include("call_plots.jl")
include("make_report.jl")

#Initialization
function __init__()
    Requires.@require Weave = "44d3d7a6-8a23-5bf8-98c5-b353f8df5ec9" include("make_report.jl")
end

end
