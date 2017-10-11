using Tokamak.Stencil: @tk, infer, cpu
using Base.Test

@testset "Stencil" begin

@tk diag(A)[i] = A[i,i]
@tk trans(A)[i,j] = A[j,i]
@tk add(A,B)[i] = A[i] + B[i]
@tk sum(xs) = reduce(+, 0, xs)
@tk mul(A,B)[i,j] = sum([k] -> A[i,k]*B[k,j])

@test string(infer(diag)) == "(m, m) → (m)"
@test string(infer(trans)) == "(m, n) → (n, m)"
@test string(infer(add)) == "(m) → (m) → (m)"
@test string(infer(sum)) == "(m) → ()"
@test string(infer(mul)) == "(m, n) → (n, o) → (m, o)"

diagf = eval(cpu(diag))
@test diagf(zeros(3), reshape(1:9, (3, 3))) == [1,5,9]

sumf = eval(cpu(sum))
@test sumf([1,2,3]) == Base.sum([1,2,3])

addf = eval(cpu(add))
@test addf(zeros(3), [1,2,3],[4,5,6]) == [5,7,9]

mulf = eval(cpu(mul))
A, B = rand(5,5), rand(5,5)
@test mulf(zeros(5,5), A, B) ≈ A*B

@tk tracemul(A,B) = sum(diag(mul(A,B)))
string(infer(tracemul)) == "(m, n) → (n, m) → ()"

A = reshape(1:9, (3,3))
tracemulf = eval(cpu(tracemul))
tracemulf(A,A) == trace(A^2)

@tk function tracemul2(A, B)
  C[i, j] = sum([k] -> A[i,k]*B[k,j])
  diag[i] = C[i,i]
  trace = sum(diag)
end

tracemul2f = eval(cpu(tracemul2))
@test tracemul2f(A,A) == trace(A^2)

end
