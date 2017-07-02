domainm(x, i) = :(1:size($x, $i))
indexm(x, i...) = :($x[$(i...)])

domainin(idx, vars) = domainm(vars[idx[1]], idx[2])

ndloop(iters, body) =
  Expr(:for,
       Expr(:block, [:($i = $xs) for (i, xs) in iters]...),
       body)

struct SymbolicArray
  func
  dims
end

Base.getindex(x::SymbolicArray, is...) = x.func(is...)
domainm(x::SymbolicArray, i) = x.dims[i]
indexm(x::SymbolicArray, i...) = DataFlow.syntax(x[i...])

interpid(ctx::Context, f, args...) = vertex(f, DataFlow.constant.(args)...)
interpid(ctx::Context, f::Func, args...) = interpret(ctx, f.graph, args...)

function interpid(ctx::Context, ::typeof(reduce), red, v0, v)
  @assert DataFlow.isconstant(v)
  v = value(v[1])
  i = gensym(:i)
  :(let
    sum = $(DataFlow.syntax(v0))
    $(ndloop([(i,domainm(v, 1))], :(sum += $(indexm(v, i)))))
    sum
  end) |> DataFlow.constant
end

function isymbolic(_, ctx::Context, λ::DataFlow.Flosure, body, vars...)
  args = interpret.(ctx, vars)
  f = (is...) -> interpret(ctx, DataFlow.flopen(λ, body), args..., is...)
  dom = map(i -> domainin(i, DataFlow.syntax.(args)), ctx[:lambdas][λ])
  DataFlow.constant(SymbolicArray(f, dom))
end

isymbolic(cb, a...) = cb(a...)

function iindex(_, ctx::Context, ::typeof(getindex), xs, is...)
  if DataFlow.isconstant(xs) && value(xs[1]) isa SymbolicArray
    value(xs[1])[is...]
  else
    vertex(getindex, xs, is...)
  end
end

iindex(cb, a...) = cb(a...)

function inline(v::IVertex, args...)
  arrow, lambdas = infer_(v)
  ctx = Context(mux(iline, isymbolic, iargs, ituple, iindex, interpid),
                lambdas = lambdas)
  out = interpret(ctx, v, args...)
  return DataFlow.isconstant(out) ? out[1].value : out
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
            :(out[$(is...)] = $(DataFlow.syntax(x[is...])))))
        return out
      end)
  else
    :(function ($(args...),)
        $x
      end)
  end
end

# cpu(mul) |> prettify
