using Tokamak: @tk, cpu, dagger
using Base.Test

@testset "Tokamak" begin

@tk diag(A)[i] = A[i,i]
@tk outer(x,y)[i,j] = x[i]*y[j]
@tk trans(A)[i,j] = A[j,i]
@tk add(A,B)[i] = A[i] + B[i]

@testset "CPU" begin

A = rand(5,5)
B = rand(5,5)
x = rand(5)
y = rand(5)

cpu_diag = cpu(diag, Matrix{Float64})
@test cpu_diag(A) == Base.diag(A)

cpu_outer = cpu(outer, Vector{Float64}, Vector{Float64})
@test cpu_outer(x,y) == x*y'

cpu_trans = cpu(trans, Matrix{Float64})
@test cpu_trans(A) == A'

cpu_add = cpu(add, Vector{Float64}, Vector{Float64})
@test cpu_add(x,y) == x+y

end

@testset "Dagger" begin

using Dagger

A = distribute(rand(100,100), Blocks(10,10))
B = distribute(rand(100,100), Blocks(10,10))
x = distribute(1:100, Blocks(10))
y = distribute(1:100, Blocks(10))

dagger_diag = dagger(diag, Matrix{Float64})
@test dagger_diag(A) |> collect == Base.diag(collect(A))

dagger_outer = dagger(outer, Vector{Float64}, Vector{Float64})
@test dagger_outer(x,y) == collect(x)*collect(y)'

dagger_trans = dagger(trans, Matrix{Float64})
@test dagger_trans(A) == A'

dagger_add = dagger(add, Vector{Float64}, Vector{Float64})
@test dagger_add(x,y) == x+y

end

end
