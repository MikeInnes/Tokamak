using MacroTools, DataFlow
using DataFlow: prewalk, isconstant, value, inputnode

function desugar(ex)
  @capture(ex, f_(args__)[is__] = body_) &&
    (ex = :($f($(args...)) = [$(is...)] -> $body))
  MacroTools.prewalk(ex) do x
    @capture(x, [is__] -> body_) ? :(($(is...),) -> $body) : x
  end
end

graphm(args, body) = DataFlow.graphm(MacroTools.flatten(body), args = args)

struct Func
  graph::IVertex{Any}
end

macro tk(ex)
  @capture(shortdef(desugar(ex)), f_(args__) = body_)
  ex = DataFlow.constructor(map(esc, graphm(args, body)))
  :($(esc(f)) = Func($ex); nothing)
end
