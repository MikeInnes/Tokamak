domainm(x, i) = :(1:size($x, $i))
indexm(x, i...) = :($x[$(i...)])

domainin(idx, vars) = domainm(vars[idx[1]], idx[2])

ndloop(iters, body) =
  Expr(:for,
       Expr(:block, [:($i = $xs) for (i, xs) in iters]...),
       body)

syntax(v::IVertex) = DataFlow.syntax(v)
syntax(x) = x

struct SymbolicArray
  func
  dims
end

Base.getindex(x::SymbolicArray, is...) = x.func(is...)
domainm(x::SymbolicArray, i) = x.dims[i]
indexm(x::SymbolicArray, i...) = x[i...]

interpid(ctx::Context, f, args...) = vertex(f, DataFlow.constant.(args)...)
interpid(ctx::Context, f::Func, args...) = interpret(ctx, f.graph, args...)
interpid(ctx::Context, ::typeof(getindex), xs, is...) = indexm(xs, is...)

function interpid(ctx::Context, ::typeof(reduce), red, v0, v)
  i = gensym(:i)
  :(let
    sum = $v0
    $(ndloop([(i,domainm(v, 1))], :(sum += $(syntax(indexm(v, i))))))
    sum
  end)
end

function isymbolic(_, ctx::Context, λ::DataFlow.Flosure, body, vars...)
  args = interpret.(ctx, vars)
  f = (is...) -> interpret(ctx, DataFlow.flopen(λ, body), args..., DataFlow.constant.(is)...)
  dom = map(i -> domainin(i, args), ctx[:lambdas][λ])
  return SymbolicArray(f, dom)
end

isymbolic(cb, a...) = cb(a...)

iindex(cb, a...) = cb(a...)

function inline(v::IVertex, args...)
  arrow, lambdas = infer_(v)
  ctx = Context(mux(iline, isymbolic, iargs, iconst, ituple, interpid),
                lambdas = lambdas)
  out = interpret(ctx, v, args...)
end

inline(f::Func, args...) = inline(f.graph, args...)

domains(a::Arrow) = map(d -> subidx(d, a.ts[1:end]), a.ts[end])

function cpu(f::Func)
  args = [gensym() for _ = 1:DataFlow.graphinputs(f.graph)]
  x = inline(f, args...)
  if x isa SymbolicArray
    is = [gensym(:i) for _ in x.dims]
    :(function (out, $(args...),)
        $(ndloop(zip(is, x.dims),
            :(out[$(is...)] = $(syntax(x[is...])))))
        return out
      end)
  else
    :(function ($(args...),)
        $x
      end)
  end
end
