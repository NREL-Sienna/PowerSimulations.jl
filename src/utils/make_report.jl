"""
    report(res::OperationModelResults)
		
 function make_report(res::OperationModelResults; kwargs...)		 
 This function uses weave to either generate a LaTeX or HTML
 file based on the report_design.jmd (julia markdown) file 
 that it reads. Out_path in the weave function dictates
 where the created file gets exported. 
   
# Example
using Requirements
using PowerSimulations
using Weave

results = solve_op_model!(OpModel)
out_path = "/Users/lhanig/GitHub"
jmd = "/Users/lhanig/.julia/dev/PowerSimulations/src/utils/report_design.jmd"

report(results, jmd, out_path)

kwargs: doctype = "md2html" to create an HTML
default is PDF via latex

"""



function report(res::OperationModelResults, jmd::String, out_path::String; kwargs...)

    println("hello")
    doctype = get(kwargs, :doctype, "md2pdf")
    args = Dict("res" => res, "variables" => res.variables)
    Weave.weave(jmd, out_path=out_path, latex_cmd = "xelatex",
                doctype = doctype, args = args)

end

