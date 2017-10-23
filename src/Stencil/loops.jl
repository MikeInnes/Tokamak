using MacroTools: @q

struct Loop end

function DataFlow.toexpr(f::Loop, λ, out)
  exs = MacroTools.block(λ).args
  @assert @capture(exs[end], (args__,) -> body_)
  iters = Expr(:block, args...)
  loop = Expr(:for, iters, body)
  @q begin
    $(exs[1:end-1]...)
    $loop
    $out
  end
end
