// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Black-box tests for Context, Evaluator, and expression parser.

/// Helper: create a literal Int expression.
fn int_expr(i : Int64) -> @tpl.Expr { @tpl.Expr::Literal(@tpl.Value::Int(i)) }
fn float_expr(f : Double) -> @tpl.Expr { @tpl.Expr::Literal(@tpl.Value::Float(f)) }
fn str_expr(s : String) -> @tpl.Expr { @tpl.Expr::Literal(@tpl.Value::Str(s)) }
fn bool_expr(b : Bool) -> @tpl.Expr { @tpl.Expr::Literal(@tpl.Value::Bool(b)) }
fn null_expr() -> @tpl.Expr { @tpl.Expr::Literal(@tpl.Value::Null) }

/// Helper: evaluate an expression with an empty context.
fn eval_expr(expr : @tpl.Expr) -> @tpl.Value {
  let ctx = @tpl.Context::new()
  let ev = @tpl.Evaluator::new(ctx)
  match ev.eval(expr) {
    Ok(v) => v
    Err(msg) => @prelude.fail("eval failed: " + msg)
  }
}

// =============================================================================
// 1. Literal evaluation
// =============================================================================

test "eval literal null" {
  let v = eval_expr(null_expr())
  @prelude.assert_eq!(v, @tpl.Value::Null)
}

test "eval literal int" {
  let v = eval_expr(int_expr(42L))
  @prelude.assert_eq!(v, @tpl.Value::Int(42L))
}

test "eval literal float" {
  let v = eval_expr(float_expr(3.14))
  @prelude.assert_eq!(v, @tpl.Value::Float(3.14))
}

test "eval literal string" {
  let v = eval_expr(str_expr("hello"))
  @prelude.assert_eq!(v, @tpl.Value::Str("hello"))
}

test "eval literal bool true" {
  let v = eval_expr(bool_expr(true))
  @prelude.assert_eq!(v, @tpl.Value::Bool(true))
}

// =============================================================================
// 2. Variable lookup
// =============================================================================

test "eval variable found" {
  let ctx = @tpl.Context::new()
  let ctx = ctx.set("name", @tpl.Value::Str("Alice"))
  let ev = @tpl.Evaluator::new(ctx)
  let result = ev.eval(@tpl.Expr::Variable("name"))
  match result {
    Ok(v) => @prelude.assert_eq!(v, @tpl.Value::Str("Alice"))
    Err(_) => @prelude.assert_false!(true)
  }
}

test "eval variable not found" {
  let ctx = @tpl.Context::new()
  let ev = @tpl.Evaluator::new(ctx)
  let result = ev.eval(@tpl.Expr::Variable("missing"))
  match result {
    Ok(_) => @prelude.assert_false!(true)
    Err(_) => @prelude.assert_true!(true)
  }
}

test "eval variable from parent context" {
  let parent = @tpl.Context::new().set("x", @tpl.Value::Int(1L))
  let child = @tpl.Context::new_child(parent).set("y", @tpl.Value::Int(2L))
  let ev = @tpl.Evaluator::new(child)
  match ev.eval(@tpl.Expr::Variable("x")) {
    Ok(v) => @prelude.assert_eq!(v, @tpl.Value::Int(1L))
    Err(_) => @prelude.assert_false!(true)
  }
}

test "eval variable shadowed by child" {
  let parent = @tpl.Context::new().set("x", @tpl.Value::Int(1L))
  let child = @tpl.Context::new_child(parent).set("x", @tpl.Value::Int(99L))
  let ev = @tpl.Evaluator::new(child)
  match ev.eval(@tpl.Expr::Variable("x")) {
    Ok(v) => @prelude.assert_eq!(v, @tpl.Value::Int(99L))
    Err(_) => @prelude.assert_false!(true)
  }
}

// =============================================================================
// 3. Arithmetic operations
// =============================================================================

test "eval add int" {
  let lhs = int_expr(1L)
  let rhs = int_expr(2L)
  let v = eval_expr(@tpl.Expr::BinOp(lhs, @tpl.BinOpKind::Add, rhs))
  @prelude.assert_eq!(v, @tpl.Value::Int(3L))
}

test "eval add float" {
  let lhs = float_expr(1.5)
  let rhs = float_expr(2.5)
  let v = eval_expr(@tpl.Expr::BinOp(lhs, @tpl.BinOpKind::Add, rhs))
  @prelude.assert_eq!(v, @tpl.Value::Float(4.0))
}

test "eval add int float mix" {
  let lhs = int_expr(1L)
  let rhs = float_expr(2.5)
  let v = eval_expr(@tpl.Expr::BinOp(lhs, @tpl.BinOpKind::Add, rhs))
  @prelude.assert_eq!(v, @tpl.Value::Float(3.5))
}

test "eval add string concat" {
  let lhs = str_expr("hello ")
  let rhs = str_expr("world")
  let v = eval_expr(@tpl.Expr::BinOp(lhs, @tpl.BinOpKind::Add, rhs))
  @prelude.assert_eq!(v, @tpl.Value::Str("hello world"))
}

test "eval sub" {
  let v = eval_expr(@tpl.Expr::BinOp(int_expr(5L), @tpl.BinOpKind::Sub, int_expr(3L)))
  @prelude.assert_eq!(v, @tpl.Value::Int(2L))
}

test "eval mul" {
  let v = eval_expr(@tpl.Expr::BinOp(int_expr(4L), @tpl.BinOpKind::Mul, int_expr(3L)))
  @prelude.assert_eq!(v, @tpl.Value::Int(12L))
}

test "eval div" {
  let v = eval_expr(@tpl.Expr::BinOp(int_expr(10L), @tpl.BinOpKind::Div, int_expr(3L)))
  @prelude.assert_eq!(v, @tpl.Value::Int(3L))
}

test "eval mod" {
  let v = eval_expr(@tpl.Expr::BinOp(int_expr(10L), @tpl.BinOpKind::Mod, int_expr(3L)))
  @prelude.assert_eq!(v, @tpl.Value::Int(1L))
}

// =============================================================================
// 4. Comparison operations
// =============================================================================

test "eval eq true" {
  let v = eval_expr(@tpl.Expr::BinOp(int_expr(1L), @tpl.BinOpKind::Eq, int_expr(1L)))
  @prelude.assert_eq!(v, @tpl.Value::Bool(true))
}

test "eval eq false" {
  let v = eval_expr(@tpl.Expr::BinOp(int_expr(1L), @tpl.BinOpKind::Eq, int_expr(2L)))
  @prelude.assert_eq!(v, @tpl.Value::Bool(false))
}

test "eval neq" {
  let v = eval_expr(@tpl.Expr::BinOp(int_expr(1L), @tpl.BinOpKind::Neq, int_expr(2L)))
  @prelude.assert_eq!(v, @tpl.Value::Bool(true))
}

test "eval lt" {
  let v = eval_expr(@tpl.Expr::BinOp(int_expr(1L), @tpl.BinOpKind::Lt, int_expr(2L)))
  @prelude.assert_eq!(v, @tpl.Value::Bool(true))
}

test "eval gt" {
  let v = eval_expr(@tpl.Expr::BinOp(int_expr(3L), @tpl.BinOpKind::Gt, int_expr(2L)))
  @prelude.assert_eq!(v, @tpl.Value::Bool(true))
}

test "eval lte" {
  let v = eval_expr(@tpl.Expr::BinOp(int_expr(2L), @tpl.BinOpKind::Le, int_expr(2L)))
  @prelude.assert_eq!(v, @tpl.Value::Bool(true))
}

test "eval gte" {
  let v = eval_expr(@tpl.Expr::BinOp(int_expr(2L), @tpl.BinOpKind::Ge, int_expr(2L)))
  @prelude.assert_eq!(v, @tpl.Value::Bool(true))
}

test "eval eq string" {
  let v = eval_expr(@tpl.Expr::BinOp(str_expr("a"), @tpl.BinOpKind::Eq, str_expr("a")))
  @prelude.assert_eq!(v, @tpl.Value::Bool(true))
}

// =============================================================================
// 5. Logic operations (and/or/not)
// =============================================================================

test "eval and true true" {
  let v = eval_expr(@tpl.Expr::BinOp(bool_expr(true), @tpl.BinOpKind::And, bool_expr(true)))
  @prelude.assert_eq!(v, @tpl.Value::Bool(true))
}

test "eval and true false" {
  let v = eval_expr(@tpl.Expr::BinOp(bool_expr(true), @tpl.BinOpKind::And, bool_expr(false)))
  @prelude.assert_eq!(v, @tpl.Value::Bool(false))
}

test "eval or false true" {
  let v = eval_expr(@tpl.Expr::BinOp(bool_expr(false), @tpl.BinOpKind::Or, bool_expr(true)))
  @prelude.assert_eq!(v, @tpl.Value::Bool(true))
}

test "eval or false false" {
  let v = eval_expr(@tpl.Expr::BinOp(bool_expr(false), @tpl.BinOpKind::Or, bool_expr(false)))
  @prelude.assert_eq!(v, @tpl.Value::Bool(false))
}

test "eval not true" {
  let v = eval_expr(@tpl.Expr::UnaryOp(@tpl.UnaryOpKind::Not, bool_expr(true)))
  @prelude.assert_eq!(v, @tpl.Value::Bool(false))
}

test "eval not false" {
  let v = eval_expr(@tpl.Expr::UnaryOp(@tpl.UnaryOpKind::Not, bool_expr(false)))
  @prelude.assert_eq!(v, @tpl.Value::Bool(true))
}

test "eval neg" {
  let v = eval_expr(@tpl.Expr::UnaryOp(@tpl.UnaryOpKind::Neg, int_expr(5L)))
  @prelude.assert_eq!(v, @tpl.Value::Int(-5L))
}

// =============================================================================
// 6. Member access
// =============================================================================

test "eval member access found" {
  let m : Map[String, @tpl.Value] = Map::new()
  m["name"] = @tpl.Value::Str("Alice")
  let ctx = @tpl.Context::new().set("user", @tpl.Value::Object(m))
  let ev = @tpl.Evaluator::new(ctx)
  let expr = @tpl.Expr::Member(@tpl.Expr::Variable("user"), "name")
  match ev.eval(expr) {
    Ok(v) => @prelude.assert_eq!(v, @tpl.Value::Str("Alice"))
    Err(_) => @prelude.assert_false!(true)
  }
}

test "eval member access not found" {
  let m : Map[String, @tpl.Value] = Map::new()
  let ctx = @tpl.Context::new().set("user", @tpl.Value::Object(m))
  let ev = @tpl.Evaluator::new(ctx)
  let expr = @tpl.Expr::Member(@tpl.Expr::Variable("user"), "missing")
  match ev.eval(expr) {
    Ok(_) => @prelude.assert_false!(true)
    Err(_) => @prelude.assert_true!(true)
  }
}

// =============================================================================
// 7. Index access
// =============================================================================

test "eval index array" {
  let arr = @tpl.Value::Array([
    @tpl.Value::Int(10L),
    @tpl.Value::Int(20L),
    @tpl.Value::Int(30L),
  ])
  let ctx = @tpl.Context::new().set("items", arr)
  let ev = @tpl.Evaluator::new(ctx)
  let expr = @tpl.Expr::Index(@tpl.Expr::Variable("items"), int_expr(1L))
  match ev.eval(expr) {
    Ok(v) => @prelude.assert_eq!(v, @tpl.Value::Int(20L))
    Err(_) => @prelude.assert_false!(true)
  }
}

test "eval index out of bounds" {
  let arr = @tpl.Value::Array([@tpl.Value::Int(10L)])
  let ctx = @tpl.Context::new().set("items", arr)
  let ev = @tpl.Evaluator::new(ctx)
  let expr = @tpl.Expr::Index(@tpl.Expr::Variable("items"), int_expr(99L))
  match ev.eval(expr) {
    Ok(_) => @prelude.assert_false!(true)
    Err(_) => @prelude.assert_true!(true)
  }
}

// =============================================================================
// 8. Nested contexts
// =============================================================================

test "eval nested context get from root" {
  let root = @tpl.Context::new().set("global", @tpl.Value::Str("G"))
  let mid = @tpl.Context::new_child(root)
  let leaf = @tpl.Context::new_child(mid).set("local", @tpl.Value::Str("L"))
  let ev = @tpl.Evaluator::new(leaf)
  // Lookup from leaf should find global in root.
  match ev.eval(@tpl.Expr::Variable("global")) {
    Ok(v) => @prelude.assert_eq!(v, @tpl.Value::Str("G"))
    Err(_) => @prelude.assert_false!(true)
  }
  // Lookup local.
  match ev.eval(@tpl.Expr::Variable("local")) {
    Ok(v) => @prelude.assert_eq!(v, @tpl.Value::Str("L"))
    Err(_) => @prelude.assert_false!(true)
  }
}

// =============================================================================
// 9. Expression parser (basic)
// =============================================================================

/// Helper: parse an expression from source and return it.
fn parse_expr(source : String) -> @tpl.Expr {
  let tokens_result = @tpl.lexer.tokenize(source)
  let tokens = match tokens_result {
    Ok(ts) => ts
    Err(msg) => @prelude.fail("tokenize failed: " + msg)
  }
  let p = @tpl.Parser::new(tokens)
  let result = p.parse_expression(0)
  match result {
    Ok((e, _)) => e
    Err(msg) => @prelude.fail("parse failed: " + msg)
  }
}

test "parse literal int" {
  let e = parse_expr("42")
  match e {
    @tpl.Expr::Literal(@tpl.Value::Int(42L)) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "parse literal string" {
  let e = parse_expr("'hello'")
  match e {
    @tpl.Expr::Literal(@tpl.Value::Str("hello")) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "parse variable" {
  let e = parse_expr("username")
  match e {
    @tpl.Expr::Variable("username") => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "parse simple add" {
  let e = parse_expr("1 + 2")
  match e {
    @tpl.Expr::BinOp(_, @tpl.BinOpKind::Add, _) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "parse compare" {
  let e = parse_expr("a == b")
  match e {
    @tpl.Expr::BinOp(_, @tpl.BinOpKind::Eq, _) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "parse member access" {
  let e = parse_expr("user.name")
  match e {
    @tpl.Expr::Member(@tpl.Expr::Variable("user"), "name") => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "parse index access" {
  let e = parse_expr("items[0]")
  match e {
    @tpl.Expr::Index(@tpl.Expr::Variable("items"), _) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "parse filter pipe" {
  let e = parse_expr("name | upper")
  match e {
    @tpl.Expr::Filter(@tpl.Expr::Variable("name"), "upper", _) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "parse unary not" {
  let e = parse_expr("not x")
  match e {
    @tpl.Expr::UnaryOp(@tpl.UnaryOpKind::Not, _) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "parse grouped expression" {
  let e = parse_expr("(1 + 2) * 3")
  match e {
    @tpl.Expr::BinOp(
      @tpl.Expr::BinOp(_, @tpl.BinOpKind::Add, _),
      @tpl.BinOpKind::Mul,
      _,
    ) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "parse function call" {
  let e = parse_expr("range(0, 10)")
  match e {
    @tpl.Expr::Call("range", args) => {
      @prelude.assert_eq!(args.length(), 2)
    }
    _ => @prelude.assert_false!(true)
  }
}
