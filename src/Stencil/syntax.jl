using MacroTools: @q

function lower_loop(is, out, box, body)
  @q begin
    $out = $box
    $(Expr(:vertex, Loop(), :(($(is...),) -> $body), out))
  end
end

function lower_stencil(is, body)
  @gensym out
  lower_loop(is, out, :(Array{Any,$(length(is))}()), :($out[$(is...)] = $body))
end

function desugar(ex)
  MacroTools.postwalk(ex) do x
    @capture(x, [is__] -> (out_ = box_) => body_) ? lower_loop(is, out, box, body) :
    @capture(x, [is__] -> body_) ? lower_stencil(is, body) :
    @capture(x, c_[is__] = body_) ? :($c = $(lower_stencil(is, body))) :
      x
  end
end

graphm(args, body) = DataFlow.graphm(MacroTools.flatten(body), args = args)

struct Func
  name::Symbol
  graph::IVertex{Any}
end

Base.show(io::IO, f::Func) = print(io, f.name, "::Func")

macro tk(ex)
  @capture(shortdef(desugar(ex)), f_(args__) = body_)
  ex = esc(DataFlow.constructor(graphm(args, body)))
  :($(esc(f)) = Func($(Expr(:quote, f)), $ex); nothing)
end
