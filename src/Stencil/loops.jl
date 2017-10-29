using MacroTools: @q

struct Loop end

function DataFlow.toexpr(f::Loop, λ, out, is...)
  exs = MacroTools.block(λ).args
  @capture(exs[end], (args__,) -> body_) || return :($(Loop())($λ, $out, $(is...)))
  isempty(is) && (is = Iterators.repeated(Symbol("<undef>")))
  iters = Expr(:block, [:($x=$y) for (x, y) in zip(args, is)]...)
  loop = Expr(:for, iters, body)
  @q begin
    $(exs[1:end-1]...)
    $loop
    $out
  end
end
