module Stencil

using MacroTools, DataFlow
using DataFlow: TypeAssert, Lambda, OLambda, prewalk, postwalk, isconstant, value,
  inputnode, constant

include("loops.jl")
include("syntax.jl")
include("types.jl")
include("inline.jl")

end
