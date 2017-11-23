domain(x::AbstractArray, n) = indices(x, n)

function λopen(v::IVertex)
  prewalk(v) do v
    isa(value(v), Lambda) ? DataFlow.λopen(v) : v
  end
end

function λclose(v::IVertex)
  postwalk(v) do v
    isa(value(v), OLambda) ? DataFlow.λclose(v) : v
  end
end

withopen(f, v) = v |> λopen |> f |> λclose

function dependents(v::IVertex)
  deps = ObjectIdDict()
  deps[v] = []
  DataFlow.prefor(v) do v
    foreach(w -> push!(get!(deps, w, []), v), v.inputs)
  end
  return deps
end

vcall(args...) = vertex(Call(), constant.(args)...)

function tolambda(v::IVertex, args...)
  λ = OLambda(length(args))
  is = [vertex(DataFlow.Split(i), constant(DataFlow.LooseEnd(λ.id)))
        for i = 1:length(args)]
  vertex(λ, DataFlow.postwalk!(v) do v
    get(is, findfirst(args, v), v)
  end) |> DataFlow.λclose
end
