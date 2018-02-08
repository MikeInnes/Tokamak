using Dagger, OffsetArrays
using Dagger: DArray, domainchunks, lookup_parts, chunks

# Utils

DArray{T,N}(dom::NTuple{N}, cdom, chs) where {T,N} =
  DArray(T, ArrayDomain(dom), ArrayDomain.(cdom), chs)

DArray{T,N}(f, dom::NTuple{N}, cdom) where {T,N} =
  DArray{T,N}(dom, cdom, f.(cdom))

Dagger.domainchunks(xs::DArray, dim::Integer) =
  map(d -> d.indexes[dim],
      domainchunks(xs)[ntuple(i -> i == dim ? (:) : 1 , ndims(xs))...])

domain(xs::DArray, d::Integer) = domainchunks(xs, d)

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

struct Chunks <: Shape
  d
end
tostring(d::Chunks, ctx) = string(tostring(d.d, ctx), "*")
domainv(sh::Domain, d::Chunks, v) = sh == d.d ? vcall(domainchunks, v.inputs...) : nothing

function arrays(v)
  s = Set()
  DataFlow.prefor(v) do v
    vtype(v) isa ArrayT && push!(s, v)
  end
  return s
end

function split_loop(v::IVertex)
  v = notype(v)
  @assert v.value isa Loop
  v = DataFlow.mapconst(v) do x
    x isa Type && x <: Array ? OffsetArray{x.parameters...} : x
  end
  is = v.inputs[3:end]
  out = vcall(DArray{Any,length(is)})
  body = tolambda(v, is...)
  push!(out.inputs, is...)
  vertex(Loop(), body, out, is...)
end

# TODO: variables and arguments should probably be swapped
argtuple(v) =
  vertex(Lambda(1, spliceinputs(v.value.body,
                                [inputnode(i) for i = 1:length(v.inputs)]...,
                                [inputnode(length(v.inputs)+1, i) for i = 1:v.value.args]...)),
         v.inputs...)

function compile_loop(v)
  lambda = v[1]
  is = map(x -> x.value.value, v[3:end])
  inputd(i) = inputnode(length(v[1,:])+findfirst(is, i))
  lambda = applybody(lambda) do body
    vars = delete!(arrays(body), body[2])
    vcall(Thunk, tolambda(vcall(parent, body), vars...),
          [vcall(chslice, var, inputd.(vtype(var).xs)...) for var in vars]...)
  end |> argtuple
  cdom = vcall(domprod, Chunks.(is)...)
  striptypes(vcall(DArray{Any,length(is)}, lambda, vcall(tuple, is...), cdom))
end

function compile_dagger(f::Func, ts...)
  ar, v = infer(f, ts...)
  v = insert_domains(compile_loop(split_loop(v)), ar)
  v = tolambda(v, [inputnode(n) for n = 1:length(ts)]...)
end

# @tk outer(xs, ys)[i,j] = xs[i] * ys[j]
# f = compile_dagger(outer, Vector{Float64}, Vector{Float64}) |> syntax |> eval
#
# xs = distribute(1:100, Blocks(10))
# ys = distribute(1:100, Blocks(10))
# collect(f(xs, ys))
