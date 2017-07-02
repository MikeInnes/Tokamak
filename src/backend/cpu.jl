domainm(idx, vars) = :(1:size($(vars[idx[1]]), $(idx[2])))

interpid(ctx::Context, f, args...) = vertex(f, DataFlow.constant.(args)...)

ndloop(iters, body) =
  Expr(:for,
       Expr(:block, [:($i = $xs) for (i, xs) in iters]...),
       body)

function ireduction(_, ctx::Context, ::typeof(reduce), red, v0, v)
  λ, f, vars = value(v), v.inputs[1], interpret.(ctx, v.inputs[2:end])
  xs = map(i -> domainm(i, DataFlow.syntax.(vars)), ctx[:lamdbas][λ])
  is = [gensym(:i) for _ in xs]
  body = DataFlow.syntax(interpret(ctx, v)(is...))
  quote
    sum = $(DataFlow.syntax(v0))
    $(ndloop(zip(is, xs), :(sum += $(body))))
    sum
  end |> DataFlow.constant
end

ireduction(f, ctx::Context, a...) = f(ctx, a...)

function inline(v::IVertex, is, args...)
  arrow, lambdas = infer_(v)
  ctx = Context(mux(iline, ireduction, ilambda, iargs, ituple, interpid),
                lamdbas = lambdas)
  out = interpret(ctx, v, args...)
  isempty(arrow.ts[end]) ? out : out(is...)
end

inline(f::Func, args...) = inline(f.graph, args...)

domains(a::Arrow) = map(d -> subidx(d, a.ts[1:end]), a.ts[end])

function cpu(f::Func)
  args = [gensym() for _ = 1:DataFlow.graphinputs(f.graph)]
  typ = infer(f)
  if isempty(typ.ts[end])
    :(function ($(args...),)
        $(DataFlow.syntax(inline(f, [:i], args...)))
      end)
  else
    doms = map(i -> domainm(i, args), domains(typ))
    is = [gensym(:i) for _ in doms]
    :(function (out, $(args...),)
        $(ndloop(zip(is, doms),
            :(out[$(is...)] = $(DataFlow.syntax(inline(f, is, args...))))))
        return out
      end)
  end
end
