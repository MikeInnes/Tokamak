# Remove lambdas

interpid(ctx::Context, f, args...) = vertex(f, args...)

function inline(v::IVertex, is, args...)
  ctx = Context(mux(ilambda, iargs, ituple, interpid))
  interpret(ctx, v, args...)(is...) |> DataFlow.striplines
end

inline(f::Func, args...) = inline(f.graph, args...)

# Skeleton

subidx(x, xs)::Vector{Int} = []

function subidx(x, xs::Vector)::Vector{Int}
  for (i, x′) in enumerate(xs)
    x == x′ && return [i]
    sub = subidx(x, x′)
    !isempty(sub) && return unshift!(sub, i)
  end
  return []
end

domains(a::Arrow) = map(d -> subidx(d, a.ts[1:end]), a.ts[end])

function cpu(f::Func)
  args = [gensym() for _ = 1:DataFlow.graphinputs(f.graph)]
  typ = infer(f)
  doms = domains(typ)
  is = [:i, :j, :k][1:length(typ.ts[end])]
  iters = [:($i = 1:size($(args[d[1]]), $(d[2]))) for (i, d) in zip(is, doms)]
  :(function (out, $(args...))
      $(Expr(:for, :($(iters...);), quote
        out[$(is...)] = $(DataFlow.syntax(inline(f, (is...,), args...)))
      end))
    end)
end
