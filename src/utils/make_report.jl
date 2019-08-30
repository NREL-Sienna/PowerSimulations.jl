"""
   report(res::OperationModelResults)

This function uses weave to either generate a LaTeX or HTML
file based on the report_design.jmd (julia markdown) file 
that it reads from. Out_path in the weave function dictates
where the created file gets exported. 

#Examples report(results) for the 5-bus renewable system
will create 6 plots, 3 stack plots with the Plot() function
and 3 bar plots with the Plot() function. 
It will also make a table for each variable passed through results.

kwargs: PDF = "pdf" (or anything), will create a LaTeX file that
can be run to create a PDF. The default option for this function is
HTML.

"""
function report(res::OperationModelResults; kwargs...)

if !(:PDF in keys(kwargs))
   doctype = "md2html"
else
   doctype = "md2tex"
end

variables = collect(values(res.variables))
args = Dict("res" => res, "variables" => variables)

Weave.weave(joinpath("/Users/lhanig/.julia/dev/PowerSimulations/src/utils/", "report_design.jmd"), 
            out_path="/Users/lhanig/GitHub", latex_cmd = "xelatex",doctype = doctype,
            args = args)
      

end
