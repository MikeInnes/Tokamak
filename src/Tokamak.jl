module Tokamak

using MacroTools, DataFlow
using DataFlow: TypeAssert, Lambda, OLambda, prewalk, postwalk, isconstant, value,
  inputnode, constant, iscall, spliceinputs, syntax

include("utils.jl")
include("syntax.jl")
include("loops.jl")
include("types.jl")

include("codegen/dagger.jl")

end # module
