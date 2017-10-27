# Type System

const uid = Ref(UInt64(0))

abstract type Shape end

struct AnyT <: Shape end

struct Domain <: Shape
  id::UInt64
end

Domain() = Domain(uid[] += 1)

struct ArrayT <: Shape
  ds::Vector{Any}
end

ArrayT(ds::Domain...) = ArrayT([ds...])

struct TupleT <: Shape
  xs::Vector{Any}
end

TupleT(xs...) = TupleT([xs...])

struct Arrow <: Shape
  xs::Vector{Any}
end

Arrow(xs...) = Arrow([xs...])

tostring(d::Domain, ctx) = haskey(ctx[1], d) ? ctx[1][d] : (ctx[1][d] = shift!(ctx[2]))
tostring(d::ArrayT, ctx) = string("[", join(map(x -> tostring(x, ctx), d.ds), ","), "]")
tostring(d::TupleT, ctx) = string("(", join(map(x -> tostring(x, ctx), d.xs), ","), ")")
tostring(d::Arrow, ctx) = join(map(x -> tostring(x, ctx), d.xs), " → ")
tostring(d::AnyT, ctx) = "*"

tostring(x) = tostring(x, (Dict(), ['a':'z'...]))
Base.show(io::IO, x::Shape) = print(io, tostring(x))

shape(::Type{<:AbstractArray{T,N}}) where {T,N} = ArrayT([Domain() for i = 1:N])
shape(T::Type{<:Tuple}) = TupleT([shape(x) for x in T.parameters])

# Type Inference

using DataFlow.Interpreter

interp(ctx::Context, f, args...) = vertex(f, args...)

function infer(v::IVertex, ts::Shape...)
  inputs = [vertex(TypeAssert(), inputnode(i), constant(ts[i])) for i = 1:length(ts)]
  ctx = Context(interp)
  interpret(ctx, v, inputs...)
end
