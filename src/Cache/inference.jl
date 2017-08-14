struct Shape{A<:AbstractArray,N}
  dims::NTuple{N,Int}
end

VecShape{T} = Shape{T,1}
MatShape{T} = Shape{T,2}

Shape{A}(dims::NTuple{N}) where {T,N,A<:AbstractArray{T,N}} =
  Shape{A,N}(dims)

Shape{A}(dims::NTuple{N}) where {T,N,A<:AbstractArray{T}} =
  Shape{A{N}}(dims)

(S::Type{<:Shape})(dims...) = S(dims)

Shape(T::Type{<:AbstractArray}, dims...) = Shape{T}(dims...)

Base.size(sh::Shape) = sh.dims
Base.size(sh::Shape, i::Integer) = i ≤ length(sh.dims) ? sh.dims[i] : 1

Base.promote_rule(::Type{Shape{A1,N1}}, ::Type{Shape{A2,N2}}) where {A1,N1,A2,N2} =
  Shape{promote_type(A1,A2)}

Base.convert(T::Union{Type{Shape{A,N}},Type{Shape{A}}}, sh::Shape{_,N}) where {A,N,_} = T(sh.dims)

infer(f, xs...) = nothing
