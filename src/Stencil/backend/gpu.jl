import DataFlow: syntax

cuidxs(n) = [:((blockIdx().$x-1) * blockDim().$x + threadIdx().$x)
             for x in take([:x, :y, :z], n)]

function gpu(f::Func)
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
        ($(is...),) = ($(cuidxs(length(is))...),)
        out[$(is...)] = $(syntax(cpu(body, λs)))
        return out
      end)
  else
    error("reductions not supported")
  end
end
