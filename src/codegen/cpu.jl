function compile(f::Func, ts...)
  ar, v = infer(f, ts...)
  v = insert_domains(striptypes(v), ar)
  v = tolambda(v, length(ts))
end
