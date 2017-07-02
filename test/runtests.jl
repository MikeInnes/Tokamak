using Tokamak: @tk, infer
using Base.Test

@tk diag(A)[i] = A[i,i]
@tk trans(A)[i,j] = A[j,i]
@tk add(A,B)[i] = A[i] + B[i]
@tk sum(xs) = reduce(+, 0, [i] -> xs[i])
@tk mul(A,B)[i,j] = reduce(+, 0, [k] -> A[i,k]*B[k,j])

@test string(infer(diag)) == "(m, m) → (m)"
@test string(infer(trans)) == "(m, n) → (n, m)"
@test string(infer(add)) == "(m) → (m) → (m)"
@test string(infer(sum)) == "(m) → ()"
@test string(infer(mul)) == "(m, n) → (n, o) → (m, o)"
