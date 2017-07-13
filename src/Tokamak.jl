module Tokamak

include("syntax.jl")
include("inference.jl")
include("schedule.jl")
include("inline.jl")
include("backend/cpu.jl")
include("backend/gpu.jl")

end # module
