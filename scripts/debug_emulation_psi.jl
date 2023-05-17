using Pkg
Pkg.activate("test")
Pkg.instantiate()
using Revise


using PowerSimulations
using PowerSystems
using PowerSystemCaseBuilder
using InfrastructureSystems
const PSY = PowerSystems
const PSI = PowerSimulations
const PSB = PowerSystemCaseBuilder
using Xpress
using JuMP
using Logging
using Dates
using TimeSeries

c_sys5_reg = PSB.build_system(PSITestSystems, "c_sys5_reg")

# Transform Deterministic to Static
load_dict = Dict()
for load in get_components(PowerLoad, c_sys5_reg)
      name = get_name(load)
      t_array = get_time_series_array(
            Deterministic,
            load,
            "max_active_power",
            start_time = DateTime("2024-01-01T00:00:00"),
      )
      load_dict[name] = collect(values(t_array))
end

reg_dict = Dict()
for dev in get_components(RegulationDevice, c_sys5_reg)
      name = get_name(dev)
      t_array = get_time_series_array(
            Deterministic,
            dev,
            "max_active_power",
            start_time = DateTime("2024-01-01T00:00:00"),
      )
      reg_dict[name] = collect(values(t_array))
end

remove_time_series!(c_sys5_reg, Deterministic)

resolution = Dates.Hour(1)
dates = range(DateTime("2024-01-01T00:00:00"), step = resolution, length = 24)
c_sys5_reg

for load in get_components(PowerLoad, c_sys5_reg)
      name = get_name(load)
      t_array = load_dict[name]
      data = TimeArray(dates, t_array)
      ts = SingleTimeSeries("max_active_power", data)
      add_time_series!(c_sys5_reg, load, ts)
end

for dev in get_components(RegulationDevice, c_sys5_reg)
      name = get_name(dev)
      t_array = reg_dict[name]
      data = TimeArray(dates, t_array)
      ts = SingleTimeSeries("max_active_power", data)
      add_time_series!(c_sys5_reg, dev, ts)
end
        

template_agc = template_agc_reserve_deployment()
model = EmulationModel(template_agc, c_sys5_reg; optimizer = Xpress.Optimizer)
build!(model; executions = 24, output_dir = mktempdir(; cleanup = true))

run!(model)