using Dagger: DArray, Thunk

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
  is = v[3:end]
  ls = [vcall(length, i) for i in is]
  v.inputs[3:end] = [vcall(UnitRange, 1, l) for l in ls]
  notype(v[2]).inputs[2:end] = ls
  body = tolambda(v, is...)
  out = vcall(DArray{Any,length(is)}, is...)
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
    vcall(Thunk, tolambda(body, vars...),
          [vcall(chslice, var, inputd.(vtype(var).xs)...) for var in vars]...)
  end |> argtuple
  striptypes(vcall(DArray{Any,length(is)}, lambda, vcall(tuple, is...)))
end

function daggerv(f::Func, ts...)
  ar, v = infer(f, ts...)
  v = insert_domains(compile_loop(split_loop(v)), ar)
  v = tolambda(v, length(ts))
end

dagger(a...) = daggerv(a...) |> syntax |> eval
