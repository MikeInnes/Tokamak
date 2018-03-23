module Tokamak

using MacroTools, DataFlow
using DataFlow: TypeAssert, Lambda, OLambda, prewalk, postwalk, isconstant, value,
  inputnode, constant, iscall, spliceinputs, syntax

export @tk

include("utils.jl")
include("syntax.jl")
include("loops.jl")
include("types.jl")

include("codegen/cpu.jl")
include("codegen/dagger.jl")

end # module
