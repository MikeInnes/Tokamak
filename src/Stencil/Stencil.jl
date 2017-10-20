module Stencil

using MacroTools, DataFlow
using DataFlow: Lambda, OLambda, prewalk, postwalk, isconstant, value, inputnode

include("loops.jl")
include("syntax.jl")
include("inference.jl")
include("inline.jl")

end
