function inlinef(v::IVertex)
  prewalk(v) do v
    isa(v.value, Func) ? DataFlow.spliceinputs(inlinef(v.value.graph), v.inputs...) :
      v
  end
end

function fuse(v::IVertex)
  prewalk(inlinef(v)) do v
    isa(v.value, DataFlow.Lambda) || return v
    v = DataFlow.fuse(v)
    v.value = DataFlow.Lambda(v.value.args, fuse(v.value.body))
    return v
  end |> DataFlow.detuple
end

function inlinea(v::IVertex)
  prewalk(v) do v
    isa(v.value, DataFlow.Lambda) && return vertex(DataFlow.Lambda(v.value.args, inlinea(v.value.body)), v.inputs...)
    v.value == getindex && v[1].value isa DataFlow.Lambda || return v
    DataFlow.spliceinputs(v[1].value.body, v[1].inputs..., v.inputs[2:end]...) |> DataFlow.detuple
  end
end

function fish(v::IVertex)
  prewalk(v) do v
    isa(v.value, DataFlow.Lambda) || return v
    v.value = DataFlow.Lambda(v.value.args, fish(v.value.body))
    DataFlow.fish(v)
  end |> DataFlow.cse
end

inline(v::IVertex) = v |> fuse |> inlinea |> fish
