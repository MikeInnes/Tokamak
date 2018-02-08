using MacroTools: @q

struct Loop end

function DataFlow.toexpr(f::Loop, λ, out, is...)
  exs = MacroTools.block(λ).args
  @capture(exs[end], (args__,) -> body_) || return :($(Loop())($λ, $out, $(is...)))
  isempty(is) && (is = Iterators.repeated(Symbol("<undef>")))
  iters = Expr(:block, [:($x=$y) for (x, y) in zip(args, is)]...)
  loop = Expr(:for, iters, body)
  @q begin
    $(exs[1:end-1]...)
    $loop
    $out
  end
end

# Inline all temporary arrays
function rmtemps(v::IVertex)
  v = λopen(v)
  deps = dependents(v)
  v = DataFlow.postwalk!(v) do v
    (iscall(v, getindex) && value(v[2]) isa Loop && length(deps[v[2]]) == 1) || return v
    body = λclose(v[2,1])
    body = DataFlow.spliceinputs(body.value.body, body.inputs..., v.inputs[3:end]...)
    @assert iscall(body, setindex!)
    return body[3]
  end
  λclose(v)
end

function accum!(op, var, val)
  var[] = op(var[], val)
  return
end

@tk function reduce(f, v0, xs)
  [i] -> (out = Ref{Any}(v0)) => accum!(f, out, xs[i])
end
