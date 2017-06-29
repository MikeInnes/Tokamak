using MacroTools, DataFlow
using DataFlow: prewalk, isconstant, value, inputnode

function desugar(ex)
  @capture(ex, f_(args__)[is__] = body_) &&
    (ex = :($f($(args...)) = [$(is...)] -> $body))
  MacroTools.prewalk(ex) do x
    @capture(x, [is__] -> body_) ? :(($(is...),) -> $body) : x
  end
end

function graphm(args, body)
  body = body |> MacroTools.flatten |> block |> DataFlow.graphm |> DataFlow.il
  prewalk(body) do v
    isconstant(v) && (i = findfirst(args, value(v[1]))) ≠ 0 ?
      inputnode(i) :
      v
  end
end

struct Func
  graph::IVertex{Any}
end

macro tk(ex)
  @capture(shortdef(desugar(ex)), f_(args__) = body_)
  ex = DataFlow.constructor(map(esc, graphm(args, body)))
  :($(esc(f)) = Func($ex); nothing)
end
