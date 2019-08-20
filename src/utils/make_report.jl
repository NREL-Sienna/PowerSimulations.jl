
#function make_report(results::OperationModelResults; kwargs...)

   # path = get(kwargs, :path, nothing)
using Weave
using DSP 

 args = Dict()
 args["Stacked_gen"] = stacked_gen
 args["Stacked_renew"] = stacked_renew
 args["Stacked_therm"] = stacked_therm
  
  Weave.weave(joinpath(dirname(pathof(PowerSimulations)),
         "../../examples", "report_design.jmd"),
         fig_path = "figures", fig_ext = ".pdf",
         out_path=:pwd, latex_cmd = "xelatex", doctype = "md2pdf",
         args = Dict(
         "stacked_gen" => stacked_gen,
         "stacked_renew" => stacked_renew, 
         "stacked_therm" => stacked_therm,
         "bar_therm" => bar_therm,
         "bar_renew" => bar_renew,
         "P_therm" => res.variables[:P_ThermalStandard],
         "P_renew" => res.variables[:P_RenewableDispatch]))

