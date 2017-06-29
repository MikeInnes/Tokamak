using Tokamak: @tk, infer
using Base.Test

@tk diag(A)[i] = A[i,i]
@tk trans(A)[i,j] = A[j,i]
@tk add(A,B)[i] = A[i] + B[i]

@test string(infer(diag)) == "(m, m) → (m)"
@test string(infer(trans)) == "(m, n) → (n, m)"
@test string(infer(add)) == "(m) → (m) → (m)"
