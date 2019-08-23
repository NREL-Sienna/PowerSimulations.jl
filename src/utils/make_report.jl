
function make_report(res::OperationModelResults; kwargs...)

Order_gen = get(kwargs, :Order_gen, nothing)
Order_renew = get(kwargs, :Order_renew, nothing)
Order_therm = get(kwargs, :Order_therm, nothing)

if !(:Order_renew in keys(kwargs))
   stacked_renew = get_stacked_plot_data(res, "P_RenewableDispatch")
   bar_renew = get_bar_plot_data(res, "P_RenewableDispatch")
else
   stacked_renew = get_stacked_plot_data(res, "P_RenewableDispatch"; sort = Order_renew)
   bar_renew = get_bar_plot_data(res, "P_RenewableDispatch"; sort = Order_renew)
end

if !(:Order_therm in keys(kwargs))
   stacked_therm = get_stacked_plot_data(res, "P_ThermalStandard")
   bar_therm = get_bar_plot_data(res, "P_ThermalStandard")
else
   stacked_therm = get_stacked_plot_data(res, "P_ThermalStandard"; sort = Order_therm) 
   bar_therm = get_bar_plot_data(res, "P_ThermalStandard"; sort = Order_therm)
end

if !(:Order_gen in keys(kwargs))
   stacked_gen = get_stacked_generation_data(res)
else
   stacked_gen = get_stacked_generation_data(res; sort = Order_gen) 
end

if !(:PDF in keys(kwargs))
   doctype = "md2html"
else
   doctype = "md2tex"
end

Weave.weave(joinpath("/Users/lhanig/.julia/dev/PowerSimulations/src/utils/", "report_design.jmd"), 
            out_path="/Users/lhanig/GitHub", latex_cmd = "xelatex",doctype = doctype,
            args = Dict("stacked_gen" => stacked_gen, 
            "stacked_renew" => stacked_renew, 
            "stacked_therm" => stacked_therm,
            "bar_therm" => bar_therm,
            "bar_renew" => bar_renew,
            "P_therm" => res.variables[:P_ThermalStandard],
            "P_renew" => res.variables[:P_RenewableDispatch]))

end
