Base.Array{T,N}(dims::Base.OneTo...) where {T,N} = Array{T,N}(map(x -> x.stop, dims))

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

function applybody(f, v::IVertex)
  @assert v.value isa Lambda
  vertex(Lambda(v.value.args, f(v.value.body)), v.inputs...)
end

function prewalkλ(f, v::IVertex)
  prewalk(v) do v
    v = f(v)
    v.value isa Lambda ? applybody(v -> prewalkλ(f, v), v) : v
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

# After creating a lambda, make sure the types of closed-over variables are
# propagated inside the new scope.
function closure_types(v)
  vars = [withtype(inputnode(i), vtype(v[i])) for i = 1:length(v.inputs)]
  vertex(Lambda(v.value.args, spliceinputs(v.value.body, vars...)),
         v.inputs...)
end

function tolambda(v::IVertex, args::IVertex...)
  λ = OLambda(length(args))
  is = [vertex(DataFlow.Split(i), constant(DataFlow.LooseEnd(λ.id)))
        for i = 1:length(args)]
  vertex(λ, DataFlow.postwalk!(v) do v
    get(is, findfirst(args, v), v)
  end) |> DataFlow.λclose |> closure_types
end

tolambda(v::IVertex, n::Integer) = vertex(Lambda(n, v))
