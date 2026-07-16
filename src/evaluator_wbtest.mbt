// ---------------------------------------------------------------------------
// MoonTera — Evaluator white-box tests
// ---------------------------------------------------------------------------

// ===========================================================================
// 1. Literal evaluation & Value helpers
// ===========================================================================

test "literal — string" {
  let expr = Expr::Literal(Value::Str("hello"))
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Str("hello"))
    Err(_) => assert_true!(false)
  }
}

test "literal — integer" {
  let expr = Expr::Literal(Value::Int(42L))
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Int(42L))
    Err(_) => assert_true!(false)
  }
}

test "literal — float" {
  let expr = Expr::Literal(Value::Float(3.14))
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Float(3.14))
    Err(_) => assert_true!(false)
  }
}

test "literal — boolean" {
  let expr = Expr::Literal(Value::Bool(true))
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Bool(true))
    Err(_) => assert_true!(false)
  }
}

test "literal — null" {
  let expr = Expr::Literal(Value::Null)
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Null)
    Err(_) => assert_true!(false)
  }
}

// ===========================================================================
// 2. Value::to_string
// ===========================================================================

test "Value::to_string — null" {
  assert_true!(Value::Null.to_string() == "null")
}

test "Value::to_string — bool" {
  assert_true!(Value::Bool(true).to_string() == "true")
  assert_true!(Value::Bool(false).to_string() == "false")
}

test "Value::to_string — int" {
  assert_true!(Value::Int(42L).to_string() == "42")
}

test "Value::to_string — float" {
  assert_true!(Value::Float(3.14).to_string() == "3.14")
}

test "Value::to_string — str" {
  assert_true!(Value::Str("hello").to_string() == "hello")
}

test "Value::to_string — array" {
  assert_true!(Value::Array([]).to_string() == "[Array]")
}

test "Value::to_string — object" {
  assert_true!(Value::Object(Map::new()).to_string() == "[Object]")
}

// ===========================================================================
// 3. Value::is_truthy
// ===========================================================================

test "is_truthy — null is falsy" {
  assert_true!(!Value::Null.is_truthy())
}

test "is_truthy — false is falsy" {
  assert_true!(!Value::Bool(false).is_truthy())
}

test "is_truthy — true is truthy" {
  assert_true!(Value::Bool(true).is_truthy())
}

test "is_truthy — int 0 is falsy" {
  assert_true!(!Value::Int(0L).is_truthy())
}

test "is_truthy — int non-zero is truthy" {
  assert_true!(Value::Int(1L).is_truthy())
}

test "is_truthy — empty str is falsy" {
  assert_true!(!Value::Str("").is_truthy())
}

test "is_truthy — non-empty str is truthy" {
  assert_true!(Value::Str("x").is_truthy())
}

// ===========================================================================
// 4. Variable lookup
// ===========================================================================

test "variable — found in root context" {
  let ctx = Context::new()
  ctx.set("name", Value::Str("MoonTera"))
  let expr = Expr::Variable("name")
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Str("MoonTera"))
    Err(_) => assert_true!(false)
  }
}

test "variable — undefined raises error" {
  let ctx = Context::new()
  let expr = Expr::Variable("missing")
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(_) => assert_true!(false)
    Err(_) => assert_true!(true)
  }
}

test "variable — found in parent scope" {
  let parent = Context::new()
  parent.set("x", Value::Int(10L))
  let child = Context::new_child(parent)
  let expr = Expr::Variable("x")
  match evaluate(expr, child, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Int(10L))
    Err(_) => assert_true!(false)
  }
}

test "variable — child shadows parent" {
  let parent = Context::new()
  parent.set("x", Value::Int(10L))
  let child = Context::new_child(parent)
  child.set("x", Value::Int(20L))
  let expr = Expr::Variable("x")
  match evaluate(expr, child, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Int(20L))
    Err(_) => assert_true!(false)
  }
}

// ===========================================================================
// 5. Arithmetic
// ===========================================================================

test "arithmetic — addition" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Int(3L)),
    BinOpKind::Add,
    Expr::Literal(Value::Int(4L)),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Int(7L))
    Err(_) => assert_true!(false)
  }
}

test "arithmetic — subtraction" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Int(10L)),
    BinOpKind::Sub,
    Expr::Literal(Value::Int(3L)),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Int(7L))
    Err(_) => assert_true!(false)
  }
}

test "arithmetic — multiplication" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Int(6L)),
    BinOpKind::Mul,
    Expr::Literal(Value::Int(7L)),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Int(42L))
    Err(_) => assert_true!(false)
  }
}

test "arithmetic — division" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Int(10L)),
    BinOpKind::Div,
    Expr::Literal(Value::Int(3L)),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Int(3L))
    Err(_) => assert_true!(false)
  }
}

test "arithmetic — modulo" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Int(10L)),
    BinOpKind::Mod,
    Expr::Literal(Value::Int(3L)),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Int(1L))
    Err(_) => assert_true!(false)
  }
}

test "arithmetic — int + float → float" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Int(3L)),
    BinOpKind::Add,
    Expr::Literal(Value::Float(0.5)),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Float(3.5))
    Err(_) => assert_true!(false)
  }
}

test "arithmetic — string concatenation" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Str("Hello, ")),
    BinOpKind::Add,
    Expr::Literal(Value::Str("World!")),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Str("Hello, World!"))
    Err(_) => assert_true!(false)
  }
}

test "arithmetic — complex expression" {
  // (2 + 3) * 4 = 20
  let expr = Expr::BinOp(
    Expr::BinOp(
      Expr::Literal(Value::Int(2L)),
      BinOpKind::Add,
      Expr::Literal(Value::Int(3L)),
    ),
    BinOpKind::Mul,
    Expr::Literal(Value::Int(4L)),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Int(20L))
    Err(_) => assert_true!(false)
  }
}

// ===========================================================================
// 6. Comparison
// ===========================================================================

test "comparison — equal" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Int(5L)),
    BinOpKind::Eq,
    Expr::Literal(Value::Int(5L)),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Bool(true))
    Err(_) => assert_true!(false)
  }
}

test "comparison — not equal" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Int(5L)),
    BinOpKind::Neq,
    Expr::Literal(Value::Int(3L)),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Bool(true))
    Err(_) => assert_true!(false)
  }
}

test "comparison — less than" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Int(3L)),
    BinOpKind::Lt,
    Expr::Literal(Value::Int(5L)),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Bool(true))
    Err(_) => assert_true!(false)
  }
}

test "comparison — greater than" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Int(5L)),
    BinOpKind::Gt,
    Expr::Literal(Value::Int(3L)),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Bool(true))
    Err(_) => assert_true!(false)
  }
}

test "comparison — less or equal" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Int(5L)),
    BinOpKind::Le,
    Expr::Literal(Value::Int(5L)),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Bool(true))
    Err(_) => assert_true!(false)
  }
}

test "comparison — string equality" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Str("abc")),
    BinOpKind::Eq,
    Expr::Literal(Value::Str("abc")),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Bool(true))
    Err(_) => assert_true!(false)
  }
}

// ===========================================================================
// 7. Logical operators
// ===========================================================================

test "logic — and (both true)" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Bool(true)),
    BinOpKind::And,
    Expr::Literal(Value::Bool(true)),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Bool(true))
    Err(_) => assert_true!(false)
  }
}

test "logic — and (false short-circuits)" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Bool(false)),
    BinOpKind::And,
    Expr::Variable("undefined_var"),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Bool(false))
    Err(_) => assert_true!(false)
  }
}

test "logic — or (true short-circuits)" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Bool(true)),
    BinOpKind::Or,
    Expr::Variable("undefined_var"),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Bool(true))
    Err(_) => assert_true!(false)
  }
}

test "logic — or (false then true)" {
  let expr = Expr::BinOp(
    Expr::Literal(Value::Bool(false)),
    BinOpKind::Or,
    Expr::Literal(Value::Bool(true)),
  )
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Bool(true))
    Err(_) => assert_true!(false)
  }
}

test "logic — not" {
  let expr = Expr::UnaryOp(UnaryOpKind::Not, Expr::Literal(Value::Bool(true)))
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Bool(false))
    Err(_) => assert_true!(false)
  }
}

test "logic — negation" {
  let expr = Expr::UnaryOp(UnaryOpKind::Neg, Expr::Literal(Value::Int(5L)))
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Int(-5L))
    Err(_) => assert_true!(false)
  }
}

// ===========================================================================
// 8. Member access
// ===========================================================================

test "member — access existing key" {
  let map = Map::new()
  map["name"] = Value::Str("MoonTera")
  let expr = Expr::Member(Expr::Literal(Value::Object(map)), "name")
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Str("MoonTera"))
    Err(_) => assert_true!(false)
  }
}

test "member — missing key returns null" {
  let map = Map::new()
  let expr = Expr::Member(Expr::Literal(Value::Object(map)), "missing")
  let ctx = Context::new()
  match evaluate(expr, ctx, FilterRegistry::default()) {
    Ok(v) => assert_true!(v == Value::Null)
    Err(_) => assert_true!(false)
  }
}

// ===========================================================================
// 9. Nested context (scope chain)
// ===========================================================================

test "context — nested scopes" {
  let root = Context::new()
  root.set("a", Value::Int(1L))
  root.set("b", Value::Int(2L))

  let child = Context::new_child(root)
  child.set("b", Value::Int(20L))
  child.set("c", Value::Int(30L))

  let flt = FilterRegistry::default()
  // a: from root
  match evaluate(Expr::Variable("a"), child, flt) {
    Ok(v) => assert_true!(v == Value::Int(1L))
    Err(_) => assert_true!(false)
  }
  // b: child shadows root
  match evaluate(Expr::Variable("b"), child, flt) {
    Ok(v) => assert_true!(v == Value::Int(20L))
    Err(_) => assert_true!(false)
  }
  // c: child only
  match evaluate(Expr::Variable("c"), child, flt) {
    Ok(v) => assert_true!(v == Value::Int(30L))
    Err(_) => assert_true!(false)
  }
  // root unchanged
  match evaluate(Expr::Variable("b"), root, flt) {
    Ok(v) => assert_true!(v == Value::Int(2L))
    Err(_) => assert_true!(false)
  }
}
