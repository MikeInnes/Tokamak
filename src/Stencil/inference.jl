using DataFlow.Interpreter
using DataFlow: Call

subidx(x, xs)::Vector{Int} = []

function subidx(x, xs::AbstractVector)::Vector{Int}
  for (i, x′) in enumerate(xs)
    x == x′ && return [i]
    sub = subidx(x, x′)
    !isempty(sub) && return unshift!(sub, i)
  end
  return []
end

subidx(x, xs::Tuple) = subidx(x, collect(xs))

const uid = Ref(UInt64(0))

struct DomainVar
  id::UInt64
end

DomainVar() = DomainVar(uid[] += 1)

const AnyDomain = DomainVar(typemax(UInt64))

struct Arrow
  ts::Vector{Vector{DomainVar}}
end

function named(a::Arrow)
  names = [:m, :n, :o, :p]
  cache = Dict{DomainVar, Symbol}()
  map(t -> map(d -> d == AnyDomain ? :_ : Base.@get!(cache, d, shift!(names)), t), a.ts)
end

function Base.show(io::IO, a::Arrow)
  join(io, string.("(", join.(named(a), ", "), ")"), " → ")
end

struct Staged
  id::UInt64
end

Staged() = Staged(uid[] += 1)

lower(ctx::Context, x) = AnyDomain

function lower(ctx::Context, d::DomainVar)
  while haskey(ctx[:types], d)
    d = ctx[:types][d]
  end
  return d
end

lower(ctx::Context, x::Staged) = lower.(ctx, ctx[:types][x])

function unify(ctx::Context, a::DomainVar, b::DomainVar)
  a, b = lower.(ctx, (a, b))
  a == b || AnyDomain ∈ (a, b) || (ctx[:types][a] = b)
  return a
end

unify(ctx::Context, a, b) = a

function unify(ctx::Context, x::Staged, d::Tuple)
  haskey(ctx[:types], x) || (ctx[:types][x] = lower.(ctx, d))
  d′ = ctx[:types][x]
  @assert length(d) == length(d′)
  unify.(ctx, d, d′)
  return x
end

function iclosure(f, ctx::Context, λ::DataFlow.Lambda, vars...)
  args = interpret.(ctx, vars)
  idxs = [DomainVar() for i = 1:DataFlow.graphinputs(λ.body) - length(args)]
  interpret(ctx, λ.body, args..., idxs...)
  ctx[:lambdas][λ] = map(i -> subidx(i, lower.(ctx, args)), lower.(ctx, idxs))
  return unify(ctx, Staged(), (idxs...))
end

iclosure(f, ctx::Context, args...) = f(ctx, args...)

scalar(ctx) = unify(ctx, Staged(), ())

function iindex(f, ctx::Context, ::Call, ::typeof(getindex), xs::Staged, is...)
  unify(ctx, xs, is)
  scalar(ctx)
end

iindex(f, ctx::Context, a...) = f(ctx, a...)

function ireduce(f, ctx::Context, ::Call, ::typeof(reduce), red, v0, xs)
  unify(ctx, xs, (DomainVar(),))
  scalar(ctx)
end

ireduce(f, ctx::Context, a...) = f(ctx, a...)

function interp(ctx::Context, ::Call, f, args...)
  return Staged()
end

function interp(ctx::Context, ::Call, f::Func, args...)
  interpret(ctx, f.graph, args...)
end

function infer_(v::IVertex)
  inputs = [Staged() for i = 1:DataFlow.graphinputs(v)]
  ctx = Context(mux(iline, iconst, iclosure, iargs, ituple, iindex, ireduce, interp);
                types = Dict(), lambdas = Dict())
  val = interpret(ctx, v, inputs...)
  Arrow([[lower(ctx, x)...] for x in [inputs..., val]]), ctx[:lambdas]
end

infer(v::IVertex) = infer_(v)[1]

infer(f::Func) = infer(f.graph)
