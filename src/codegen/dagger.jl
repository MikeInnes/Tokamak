using Dagger: DArray, Thunk
using OffsetArrays

include("dagger_utils.jl")

# Backend

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
  striptypes(vcall(DArray{Any,length(is)}, lambda, vcall(tuple, is...)))
end

function compile_dagger(f::Func, ts...)
  ar, v = infer(f, ts...)
  v = insert_domains(compile_loop(split_loop(v)), ar)
  v = tolambda(v, length(ts))
end

# @tk outer(xs, ys)[i,j] = xs[i] * ys[j]
# f = compile_dagger(outer, Vector{Float64}, Vector{Float64}) |> syntax |> eval
#
# xs = distribute(1:100, Blocks(10))
# ys = distribute(1:100, Blocks(10))
# collect(f(xs, ys))
