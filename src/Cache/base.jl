function shape(::typeof(*), a::MatShape, b::MatShape)
  x, y = promote(a, b)
  typeof(x)(size(x, 1), size(y, 2))
end
