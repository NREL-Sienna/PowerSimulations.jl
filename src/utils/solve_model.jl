function SolvePSModel(Psmodel::JuMP.Model; Solver = nothing)
     
    model_type = JuMP.ProblemTraits(Psmodel)

    #==
    function ProblemTraits(m::Model; relaxation=false)
    int = !relaxation & any(c-> !(c == :Cont || c == :Fixed), m.colCat)
    qp = !isempty(m.obj.qvars1)
    qc = !isempty(m.quadconstr)
    nlp = m.nlpdata !== nothing
    soc = !isempty(m.socconstr)
    # will need to change this when we add support for arbitrary variable cones
    sdp = !isempty(m.sdpconstr) || !isempty(m.varCones)
    sos = !isempty(m.sosconstr)
    ProblemTraits(int, !(qp|qc|nlp|soc|sdp|sos), qp, qc, nlp, soc, sdp, sos, soc|sdp)
    end
    =#

    if Solver == nothing

        if (model_type.qc|model_type.qp|model_type.nlp) 

            if model_type.int
                error("The model is a Mixed Integer Non-Linear Problem, please define an appropiate solver manually using the Solver= argument")  
            end

            JuMP.setsolver(Psmodel, Ipopt.IpoptSolver())
            warn("The model contains non-linear elements (QP, QC, NLP), by default the solver is Ipopt Solver")
        
        elseif model_type.lin & model_type.int & !(model_type.qc|model_type.qp|model_type.nlp)
            
            JuMP.setsolver(Psmodel, Cbc.CbcSolver(logLevel = 1))
            warn("The model is Mixed Integer Linear, the default is Cbc Solver")
        
        elseif model_type.lin & !(model_type.qc|model_type.qp|model_type.nlp)
            
            JuMP.setsolver(Psmodel, Clp.ClpSolver(SolveType = 5, logLevel = 5))

            warn("The model is linear, by default the solver is Clp Solver")

        else 

            error("The PS Model is not a standard LP, MILP, QP, QC or NLP, please define an appropiate solver manually using the Solver argument")
            
        end

    else 
        JuMP.setsolver(Psmodel, Solver)
        warn("A solver has been defined manually, this might break the results output function")
        
    end

    JuMP.build(Psmodel)
    status = solve(Psmodel)

    if status != :Optimal
        println(status)
        error("Problem has no solution.")    
    end

    return Psmodel

end