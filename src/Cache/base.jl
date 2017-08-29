infer(::typeof(*), x::MatShape, y::MatShape) =
  similar(promote(x, y)[1], size(x, 1), size(y, 2))

infer(::typeof(broadcast), f, xs::Shape...) =
  Base.Broadcast.broadcast_shape(size.(xs)...)
