module Stencil

using MacroTools, DataFlow
using DataFlow: Lambda, OLambda, prewalk, postwalk, isconstant, value, inputnode

include("syntax.jl")
include("inference.jl")
include("schedule.jl")
include("inline.jl")
include("backend/cpu.jl")

end
