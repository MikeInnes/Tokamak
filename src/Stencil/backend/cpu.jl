import DataFlow: syntax, Constant

domainm(x, i) = :(1:size($x, $i))

domainin(idx, vars) = domainm(vars[idx[1]], idx[2])

ndloop(iters, body) =
  Expr(:for,
       Expr(:block, [:($i = $xs) for (i, xs) in iters]...),
       body)

splice(v::IVertex, args...) = DataFlow.spliceinputs(v, DataFlow.constant.(args)...)

function index(v::IVertex, i)
  if v.value isa DataFlow.Lambda
    splice(v.value.body, v.inputs..., DataFlow.constant(i))
  else
    vertex(Call(), DataFlow.constant(getindex), v, DataFlow.constant(i))
  end
end

function reduction(v::IVertex, types)
  dom = v[4].value isa DataFlow.Lambda ?
    domainin(types[v[4].value][1], syntax.([v[4].inputs...])) :
    :(1:length($(syntax(v[4]))))
  @gensym i val
  quote
    $val = $(syntax(v[3]))
    for $i in $(dom)
      $val = $(syntax(v[2]))($val, $(syntax(cpu(index(v[4], i), types))))
    end
    $val
  end |> DataFlow.constant
end

function cpu(v::IVertex, types)
  prewalk(v) do v
    v.value isa Call && v[1].value == Constant(reduce) ? reduction(v, types) : v
  end
end

function cpu(f::Func)
  v = inline(f.graph)
  arr, λs = infer_(v)
  n = length(arr.ts[end])
  args = [gensym() for _ = 1:length(arr.ts)-1]
  v = splice(v, args...)
  if n > 0
    @assert v.value isa DataFlow.Lambda
    is = [gensym(:i) for _ = 1:n]
    ds = map(i -> domainin(i, vcat(syntax.(v.inputs), args)), λs[v.value])
    body = splice(v.value.body, v.inputs..., is...)
    :(function (out, $(args...))
        $(ndloop(zip(is, ds), :(out[$(is...)] = $(syntax(cpu(body, λs))))))
        return out
      end)
  else
    :(function ($(args...),)
        $(syntax(cpu(v, λs)))
      end)
  end
end
