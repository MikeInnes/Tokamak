using DataFlow.Interpreter

inline(ctx::Context, f, args...) = vertex(f, DataFlow.constant.(args)...)

function inline(ctx::Context, f::Func, args...)
  interpret(ctx, f.graph, args...)
end

function inline(ctx::Context, λ::DataFlow.Lambda, vars...)
  vertex(DataFlow.Lambda(interpv(ctx, λ.body)), vars...)
end

function inline(v::IVertex)
  ctx = Context(mux(iline, iargs, iconst, ituple, inline))
  out = interpv(ctx, v)
end
