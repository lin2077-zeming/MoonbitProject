// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Black-box tests for the parser — expression parsing, block tags, nesting.

/// Helper: parse a template and return the nodes.
fn parse_nodes(source : String) -> Array[@tpl.Node] {
  let tpl_result = @tpl.Template::parse(source)
  match tpl_result {
    Ok(t) => t.nodes
    Err(msg) => @prelude.fail("parse failed: " + msg.to_string())
  }
}

/// Helper: parse an expression string (wraps in {{ }}).
fn parse_expr(expr_src : String) -> @tpl.Expr {
  let tokens_result = @tpl.lexer.tokenize(expr_src)
  let tokens = match tokens_result {
    Ok(ts) => ts
    Err(msg) => @prelude.fail("lexer: " + msg)
  }
  let p = @tpl.Parser::new(tokens)
  match p.parse_expression(0) {
    Ok((e, _)) => e
    Err(msg) => @prelude.fail("parse expr: " + msg)
  }
}

// =============================================================================
// 1. Operator precedence
// =============================================================================

test "precedence: mul before add" {
  let e = parse_expr("1 + 2 * 3")
  match e {
    @tpl.Expr::BinOp(
      @tpl.Expr::Literal(@tpl.Value::Int(1L)),
      @tpl.BinOpKind::Add,
      @tpl.Expr::BinOp(_, @tpl.BinOpKind::Mul, _),
    ) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "precedence: parens override" {
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

test "precedence: and before or" {
  let e = parse_expr("a or b and c")
  match e {
    @tpl.Expr::BinOp(
      @tpl.Expr::Variable("a"),
      @tpl.BinOpKind::Or,
      @tpl.Expr::BinOp(_, @tpl.BinOpKind::And, _),
    ) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "precedence: compare before and" {
  let e = parse_expr("a == b and c != d")
  match e {
    @tpl.Expr::BinOp(
      @tpl.Expr::BinOp(_, @tpl.BinOpKind::Eq, _),
      @tpl.BinOpKind::And,
      @tpl.Expr::BinOp(_, @tpl.BinOpKind::Neq, _),
    ) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

// =============================================================================
// 2. Member access chains
// =============================================================================

test "member access chain a.b.c" {
  let e = parse_expr("a.b.c")
  match e {
    @tpl.Expr::Member(
      @tpl.Expr::Member(@tpl.Expr::Variable("a"), "b"),
      "c",
    ) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "member access with call" {
  let e = parse_expr("user.name")
  match e {
    @tpl.Expr::Member(@tpl.Expr::Variable("user"), "name") =>
      @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

// =============================================================================
// 3. Function calls
// =============================================================================

test "function call no args" {
  let e = parse_expr("now()")
  match e {
    @tpl.Expr::Call("now", args) =>
      @prelude.assert_eq!(args.length(), 0)
    _ => @prelude.assert_false!(true)
  }
}

test "function call with args" {
  let e = parse_expr("range(0, 10)")
  match e {
    @tpl.Expr::Call("range", args) =>
      @prelude.assert_eq!(args.length(), 2)
    _ => @prelude.assert_false!(true)
  }
}

test "function call with nested expr args" {
  let e = parse_expr("add(1 + 2, 3 * 4)")
  match e {
    @tpl.Expr::Call("add", args) => {
      @prelude.assert_eq!(args.length(), 2)
    }
    _ => @prelude.assert_false!(true)
  }
}

// =============================================================================
// 4. Unary operators
// =============================================================================

test "unary not" {
  let e = parse_expr("not x")
  match e {
    @tpl.Expr::UnaryOp(@tpl.UnaryOpKind::Not,
      @tpl.Expr::Variable("x")) =>
      @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "unary negate" {
  let e = parse_expr("-42")
  match e {
    @tpl.Expr::UnaryOp(@tpl.UnaryOpKind::Neg, _) =>
      @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "double unary" {
  let e = parse_expr("not not x")
  match e {
    @tpl.Expr::UnaryOp(@tpl.UnaryOpKind::Not,
      @tpl.Expr::UnaryOp(@tpl.UnaryOpKind::Not, _)) =>
      @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

// =============================================================================
// 5. Index access
// =============================================================================

test "index access number" {
  let e = parse_expr("items[0]")
  match e {
    @tpl.Expr::Index(@tpl.Expr::Variable("items"), _) =>
      @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "index access variable" {
  let e = parse_expr("items[i]")
  match e {
    @tpl.Expr::Index(@tpl.Expr::Variable("items"),
      @tpl.Expr::Variable("i")) =>
      @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

// =============================================================================
// 6. Filter chains
// =============================================================================

test "filter simple" {
  let e = parse_expr("name | upper")
  match e {
    @tpl.Expr::Filter(@tpl.Expr::Variable("name"), "upper", _) =>
      @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "filter chain" {
  let e = parse_expr("name | upper | trim")
  match e {
    @tpl.Expr::Filter(
      @tpl.Expr::Filter(@tpl.Expr::Variable("name"), "upper", _),
      "trim",
      _,
    ) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "filter with args" {
  let e = parse_expr("items | join(', ')")
  match e {
    @tpl.Expr::Filter(_, "join", args) =>
      @prelude.assert_eq!(args.length(), 1)
    _ => @prelude.assert_false!(true)
  }
}

// =============================================================================
// 7. Nested if blocks
// =============================================================================

test "parse nested if" {
  let nodes = parse_nodes(
    "{% if outer %}{% if inner %}deep{% endif %}{% endif %}",
  )
  match nodes[0] {
    @tpl.Node::If(_, then_body, _, _) => {
      // then_body should contain an inner If node.
      @prelude.assert!(then_body.length() > 0)
    }
    _ => @prelude.assert_false!(true)
  }
}

test "parse if elif else with nesting" {
  let nodes = parse_nodes(
    "{% if a %}A{% elif b %}{% if c %}C{% endif %}{% else %}D{% endif %}",
  )
  @prelude.assert_eq!(nodes.length(), 1)
  match nodes[0] {
    @tpl.Node::If(_, then_body, elifs, else_body) => {
      @prelude.assert!(then_body.length() > 0)
      @prelude.assert!(elifs.length() > 0)
      @prelude.assert!(else_body.length() > 0)
    }
    _ => @prelude.assert_false!(true)
  }
}

// =============================================================================
// 8. For loop with nested content
// =============================================================================

test "parse for with if inside" {
  let nodes = parse_nodes(
    "{% for x in items %}{% if x > 0 %}{{ x }}{% endif %}{% endfor %}",
  )
  match nodes[0] {
    @tpl.Node::For("x", _, body) => {
      @prelude.assert!(body.length() > 0)
    }
    _ => @prelude.assert_false!(true)
  }
}

test "parse for with nested for" {
  let nodes = parse_nodes(
    "{% for row in rows %}{% for col in cols %}{{ col }}{% endfor %}{% endfor %}",
  )
  match nodes[0] {
    @tpl.Node::For("row", _, body) =>
      @prelude.assert!(body.length() > 0)
    _ => @prelude.assert_false!(true)
  }
}

// =============================================================================
// 9. Macro parsing
// =============================================================================

test "parse macro no params" {
  let nodes = parse_nodes(
    "{% macro hello() %}Hello{% endmacro %}",
  )
  match nodes[0] {
    @tpl.Node::Macro("hello", params, _) =>
      @prelude.assert_eq!(params.length(), 0)
    _ => @prelude.assert_false!(true)
  }
}

test "parse macro with params" {
  let nodes = parse_nodes(
    "{% macro button(text, class) %}<button>{{ text }}</button>{% endmacro %}",
  )
  match nodes[0] {
    @tpl.Node::Macro("button", params, _) =>
      @prelude.assert_eq!(params.length(), 2)
    _ => @prelude.assert_false!(true)
  }
}

// =============================================================================
// 10. Include parsing
// =============================================================================

test "parse include" {
  let nodes = parse_nodes("{% include 'header.html' %}")
  match nodes[0] {
    @tpl.Node::Include("header.html") => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

// =============================================================================
// 11. Mixed template parsing
// =============================================================================

test "parse complex mixed template" {
  let nodes = parse_nodes(
    "<html>{% if show %}Hello, {{ name | upper }}{% endif %}" +
    "{% for x in items %}<li>{{ x }}</li>{% endfor %}</html>",
  )
  @prelude.assert!(nodes.length() >= 3)
}

// =============================================================================
// 12. Parse errors
// =============================================================================

test "parse error: unclosed if" {
  let result = @tpl.Template::parse("{% if x %}no endif")
  match result {
    Ok(_) => @prelude.assert_false!(true)
    Err(_) => @prelude.assert_true!(true)
  }
}

test "parse error: unexpected elif" {
  let result = @tpl.Template::parse("{% elif x %}")
  match result {
    Ok(_) => @prelude.assert_false!(true)
    Err(_) => @prelude.assert_true!(true)
  }
}

test "parse error: unexpected else" {
  let result = @tpl.Template::parse("{% else %}")
  match result {
    Ok(_) => @prelude.assert_false!(true)
    Err(_) => @prelude.assert_true!(true)
  }
}

test "parse error: unexpected endfor" {
  let result = @tpl.Template::parse("{% endfor %}")
  match result {
    Ok(_) => @prelude.assert_false!(true)
    Err(_) => @prelude.assert_true!(true)
  }
}

test "parse error: unclosed macro" {
  let result = @tpl.Template::parse("{% macro m() %}oops")
  match result {
    Ok(_) => @prelude.assert_false!(true)
    Err(_) => @prelude.assert_true!(true)
  }
}
