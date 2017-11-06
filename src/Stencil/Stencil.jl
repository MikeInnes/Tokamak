module Stencil

using MacroTools, DataFlow
using DataFlow: TypeAssert, Lambda, OLambda, prewalk, postwalk, isconstant, value,
  inputnode, constant, iscall

include("utils.jl")
include("syntax.jl")
include("loops.jl")
include("types.jl")

end
