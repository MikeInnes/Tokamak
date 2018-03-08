import Dagger: DArray, ArrayDomain, Thunk, chunks, domainchunks

# Domain munging conveniences

struct ChunkDomain
  domain::AbstractVector{Int}
  chunks::Vector{<:AbstractVector{Int}}
end

ArrayDomain(d::ChunkDomain...) = ArrayDomain(map(d -> d.domain, d)...)

mapcart(f, xs) = f.(xs)
mapcart(f, xs, ys) = f.(xs, reshape(xs, 1, :))
domprod(ds...) = mapcart(tuple, ds...)

chunkinds(i::ChunkDomain...) = domprod(map(i -> i.chunks, i)...)

chunkinds(xs::DArray, dim::Integer) =
  map(d -> d.indexes[dim],
      domainchunks(xs)[ntuple(i -> i == dim ? (:) : 1 , ndims(xs))...])

domain(xs::DArray, i::Integer) = ChunkDomain(indices(xs, i), chunkinds(xs, i))

# Constructors

DArray{T,N}(dom::NTuple{N,ChunkDomain}, chunks::AbstractArray{<:Any,N}) where {T,N} =
  DArray(T, ArrayDomain(dom...), ArrayDomain.(chunkinds(dom...)), chunks)

DArray{T,N}(f, dom::NTuple{N,ChunkDomain}) where {T,N} =
  DArray{T,N}(dom, f.(chunkinds(dom...)))

# Views

using Dagger: lookup_parts

function catchunks(chs)
  for i = 1:ndims(chs)
    chs = mapslices(xs -> [cat(i, xs...)], chs, i)
  end
  return chs[1]
end

function chslice(xs::DArray, d::ArrayDomain)
  subchunks, subdomains = lookup_parts(chunks(xs), domainchunks(xs), d)
  chsize = size(subdomains)
  subchunks
  Thunk(subchunks...) do subchunks...
    catchunks(reshape(collect(subchunks), chsize))
  end
end

chslice(xs::DArray, i...) = chslice(xs, ArrayDomain(i))
