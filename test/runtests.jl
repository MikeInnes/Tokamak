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

end
