using Dagger, OffsetArrays
using Dagger: DArray, domainchunks, lookup_parts, chunks

# Utils

DArray{T,N}(dom::NTuple{N}, cdom, chs) where {T,N} =
  DArray(T, ArrayDomain(dom), ArrayDomain.(cdom), chs)

Dagger.domainchunks(xs::DArray, dim::Integer) =
  map(d -> d.indexes[dim],
      domainchunks(xs)[ntuple(i -> i == dim ? (:) : 1 , ndims(xs))...])

mapcart(f, xs) = f.(xs)
mapcart(f, xs, ys) = f.(xs, reshape(xs, 1, :))
domprod(ds...) = mapcart(tuple, ds...)

function catchunks(chs)
  for i = 1:ndims(chs)
    chs = mapslices(xs -> [cat(i, xs...)], chs, i)
  end
  return chs[1]
end

function chslice(xs::DArray, d::ArrayDomain)
  subchunks, subdomains = lookup_parts(chunks(xs), domainchunks(xs), d)
  chsize = size(subdomains)
  Thunk(subchunks...) do subchunks...
    OffsetArray(catchunks(reshape(collect(subchunks), chsize)),
                d.indexes...)
  end
end

chslice(xs::DArray, i...) = chslice(xs, ArrayDomain(i))

# Backend

function split_loop(v::IVertex)
  @assert v.value isa Loop
  is = v.inputs[3:end]
  out = vcall(DArray{Any,length(is)})
  body = tolambda(vcall(setindex!, out, v, is...), is...)
  push!(out.inputs, is...)
  vertex(Loop(), body, out, is...)
end
