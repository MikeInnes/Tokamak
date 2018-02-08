# Type System

const uid = Ref(UInt64(0))

abstract type Shape end

struct AnyT <: Shape end

struct Domain <: Shape
  id::UInt64
end

Domain() = Domain(uid[] += 1)

struct ArrayT <: Shape
  xs::Vector{Any}
end

ArrayT(xs::Domain...) = ArrayT([xs...])

struct TupleT <: Shape
  xs::Vector{Any}
end

TupleT(xs...) = TupleT([xs...])

struct Arrow <: Shape
  xs::Vector{Any}
end

Arrow(xs...) = Arrow([xs...])

tostring(d::Domain, ctx) = "d$(d.id)"
tostring(d::ArrayT, ctx) = string("[", join(map(x -> tostring(x, ctx), d.xs), ","), "]")
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

function lower(m::Associative, x::Domain)
  while haskey(m, x)
    x = m[x]
  end
  return x
end

lower(m::Associative, x::Shape) = typeof(x)(lower.(m, x.xs)...)

function lower(m::Associative, v::IVertex)
  prewalkλ(v) do v
    isconstant(v) && v.value.value isa Shape ? constant(lower(m, v.value.value)) : v
  end
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
  ds = [Domain() for _ = 1:ndims(T)]
  ctor = vertex(Call(), constant(T), constant.(ds)...)
  withtype(ctor, ArrayT(ds...))
end

function iarray(f, ctx::Context, ::Call, T::Type{<:Ref}, x)
  ctor = vertex(Call(), constant(T), constant(x))
  withtype(ctor, ArrayT())
end

iarray(f, ctx::Context, v, args...) = f(ctx, v, args...)

function iloop(f, ctx::Context, ::Loop, l, args...)
  is = [Domain() for i = 1:l.value.args]
  vars = vtype.(l.inputs)
  inputs = [withtype(inputnode(i), sh) for (i, sh) in enumerate([vars..., is...])]
  body = interpret(ctx, l.value.body, inputs...)
  withtype(
    vertex(Loop(), vertex(Lambda(l.value.args, body), l.inputs...), args..., constant.(is)...),
    vtype(args[1]))
end

iloop(f, ctx::Context, v, args...) = f(ctx, v, args...)

function iindex(f, ctx::Context, ::Call, ::typeof(getindex), xs, is...)
  foreach(d -> unify(ctx, d...), zip(vtype(xs).xs, vtype.(is)))
  vertex(Call(), constant(getindex), xs, is...)
end

function iindex(f, ctx::Context, ::Call, ::typeof(setindex!), xs, v, is...)
  foreach(d -> unify(ctx, d...), zip(vtype(xs).xs, vtype.(is)))
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
  typemap = Dict()
  ctx = Context(mux(iline, iinline, iconst, iargs, iarray, iloop, iindex, interp),
                typemap = typemap)
  v = interpret(ctx, v, inputs...)
  v = lower(typemap, v)
  Arrow(lower.(typemap, ts)..., vtype(v)), v
end

infer(v::IVertex, ts::Type...) = infer(v, shape.(ts)...)

infer(f::Func, ts...) = infer(f.graph, ts...)

lower(x, ts...) = infer(x, ts...)[2]

# Post-processing

istype(v) = v.value isa DataFlow.TypeAssert
notype(v) = istype(v) ? notype(v[1]) : v

striptypes(v::IVertex) = prewalkλ(notype, v)

domainv(sh::Domain, d, v) = sh == d ? v : nothing

domainv(sh::ArrayT, d, v) =
  get(filter(x -> x ≠ nothing,
             domainv.(sh.xs, d,
                      vertex.(domain, v, constant.(1:length(sh.xs))))),
      1, nothing)

domainv(sh::Arrow, d) =
  filter(x -> x ≠ nothing,
         domainv.(sh.xs, d, inputnode.(1:length(sh.xs))))[1]

function insert_domains(v::IVertex, t::Shape)
  prewalkλ(v) do v
    isconstant(v) && v.value.value isa Shape || return v
    domainv(t, v.value.value)
  end
end
