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
using DataFlow: Call

function lower(typemap, x)
  while haskey(typemap, x)
    x = typemap[x]
  end
  return x
end

function unify(ctx::Context, a::Domain, b::Domain)
  a, b = lower.(ctx[:typemap], (a, b))
  a ≠ b && (ctx[:typemap][a] = b)
  return
end

withtype(v, T) = vertex(TypeAssert(), v, constant(T))
withtype(v, ::Void) = v
vtype(v::IVertex) = v.value isa TypeAssert ? v[2].value.value : nothing

function iarray(f, ctx::Context, ::Call, T::Type{<:AbstractArray})
  withtype(vertex(Call(), constant(T)), ArrayT([Domain() for _ = 1:ndims(T)]))
end

iarray(f, ctx::Context, v, args...) = f(ctx, v, args...)

function iloop(f, ctx::Context, ::Loop, l, args...)
  is = [Domain() for i = 1:l.value.args]
  vars = vtype.(l.inputs)
  inputs = [withtype(inputnode(i), sh) for (i, sh) in enumerate([vars..., is...])]
  body = interpret(ctx, l.value.body, inputs...)
  withtype(
    vertex(Loop(), vertex(Lambda(l.value.args, body), l.inputs...), args..., constant.(is)...),
    ArrayT(is))
end

iloop(f, ctx::Context, v, args...) = f(ctx, v, args...)

function iindex(f, ctx::Context, ::Call, ::typeof(getindex), xs, is...)
  foreach(d -> unify(ctx, d...), zip(vtype(xs).ds, vtype.(is)))
  vertex(Call(), constant(getindex), xs, is...)
end

function iindex(f, ctx::Context, ::Call, ::typeof(setindex!), xs, v, is...)
  foreach(d -> unify(ctx, d...), zip(vtype(xs).ds, vtype.(is)))
  vertex(Call(), constant(setindex!), xs, v, is...)
end

iindex(f, ctx::Context, v, args...) = f(ctx, v, args...)

function iinline(f, ctx::Context, ::Call, v, args...)
  isconstant(v) && v.value.value isa Func || return f(ctx, Call(), v, args...)
  interpret(ctx, v.value.value.graph, args...)
end

iinline(f, ctx::Context, v, args...) = f(ctx, v, args...)

interp(ctx::Context, f, args...) = vertex(f, constant.(args)...)

function infer(v::IVertex, ts::Shape...)
  inputs = [vertex(TypeAssert(), inputnode(i), constant(ts[i])) for i = 1:length(ts)]
  ctx = Context(mux(iline, iinline, iconst, iargs, iarray, iloop, iindex, interp),
                typemap = Dict())
  interpret(ctx, v, inputs...)
end

function striptypes(v::IVertex)
  postwalk(λopen(v)) do v
    v.value isa DataFlow.TypeAssert ? v[1] : v
  end |> λclose
end
