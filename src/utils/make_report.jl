"""
    report(res::OperationsProblemResults)

 function make_report(res::OperationsProblemResults; kwargs...)
 This function uses weave to either generate a LaTeX or HTML
 file based on the report_design.jmd (julia markdown) file
 that it reads. Out_path in the weave function dictates
 where the created file gets exported.

# Example
using Requirements
using PowerSimulations
using Weave

results = solve_op_problem!(OpModel)
out_path = "/Users/lhanig/GitHub"


report(results, out_path)

# kwargs:
doctype = "md2html" to create an HTML, default is PDF via latex

jmd = "custom file path/report_design.jmd"
report(results, out_path; jmd = jmd)
jmd has a default of ".../pwd()/report_design/report_design.jmd"

"""



function report(res::Results,out_path::String; kwargs...)

    doctype = get(kwargs, :doctype, "md2pdf")
    default_string = joinpath(pwd(), "src/utils/report_design/report_design.jmd")
    jmd = get(kwargs, :jmd, default_string)
    args = Dict("res" => res, "variables" => res.variables)
    Weave.weave(jmd, out_path=out_path, latex_cmd = "xelatex",
                doctype = doctype, args = args)

end
