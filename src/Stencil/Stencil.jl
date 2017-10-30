module Stencil

using MacroTools, DataFlow
using DataFlow: TypeAssert, Lambda, OLambda, prewalk, postwalk, isconstant, value,
  inputnode, constant, iscall

include("utils.jl")
include("loops.jl")
include("syntax.jl")
include("types.jl")

end
