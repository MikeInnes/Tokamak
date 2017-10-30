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

function dependents(v::IVertex)
  deps = ObjectIdDict()
  deps[v] = []
  DataFlow.prefor(v) do v
    foreach(w -> push!(get!(deps, w, []), v), v.inputs)
  end
  return deps
end
