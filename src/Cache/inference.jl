struct Shape{T,N}
  dims::NTuple{N,Int}
end

VecShape{T} = Shape{T,1}
MatShape{T} = Shape{T,2}

Shape{T}(dims::NTuple{N}) where {T,N} =
  Shape{T,N}(dims)

(S::Type{<:Shape})(dims...) = S(dims)

Shape(T::Type, dims...) = Shape{T}(dims...)

Base.size(sh::Shape) = sh.dims
Base.size(sh::Shape, i::Integer) = i ≤ length(sh.dims) ? sh.dims[i] : 1

Base.promote_rule(::Type{Shape{T1,N}}, ::Type{Shape{T2,N}}) where {T1,T2,N} =
  Shape{promote_type(T1,T2),N}

Base.promote_rule(::Type{Shape{T1,N1}}, ::Type{Shape{T2,N2}}) where {T1,N1,T2,N2} =
  Shape{promote_type(T1,T2)}

Base.convert(S::Union{Type{Shape{T,N}},Type{Shape{T}}}, sh::Shape{_,N}) where {T,N,_} = S(sh.dims)

infer(f, xs...) = nothing
