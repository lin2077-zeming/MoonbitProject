// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Black-box tests for AST node types and Value methods.

// =============================================================================
// Value::to_string
// =============================================================================

test "Value::to_string null" {
  let v = @tpl.Value::Null
  @prelude.assert_eq!(v.to_string(), "null")
}

test "Value::to_string bool true" {
  let v = @tpl.Value::Bool(true)
  @prelude.assert_eq!(v.to_string(), "true")
}

test "Value::to_string bool false" {
  let v = @tpl.Value::Bool(false)
  @prelude.assert_eq!(v.to_string(), "false")
}

test "Value::to_string int" {
  let v = @tpl.Value::Int(42L)
  @prelude.assert_eq!(v.to_string(), "42")
}

test "Value::to_string negative int" {
  let v = @tpl.Value::Int(-1L)
  @prelude.assert_eq!(v.to_string(), "-1")
}

test "Value::to_string float" {
  let v = @tpl.Value::Float(3.14)
  @prelude.assert_eq!(v.to_string(), "3.14")
}

test "Value::to_string string" {
  let v = @tpl.Value::Str("hello")
  @prelude.assert_eq!(v.to_string(), "hello")
}

test "Value::to_string array" {
  let v = @tpl.Value::Array([@tpl.Value::Int(1L), @tpl.Value::Int(2L), @tpl.Value::Int(3L)])
  @prelude.assert_eq!(v.to_string(), "[1, 2, 3]")
}

test "Value::to_string object" {
  let m : Map[String, @tpl.Value] = Map::new()
  let v = @tpl.Value::Object(m)
  @prelude.assert_eq!(v.to_string(), "[object]")
}

// =============================================================================
// Value::is_truthy
// =============================================================================

test "Value::is_truthy null is false" {
  @prelude.assert_false!(@tpl.Value::Null.is_truthy())
}

test "Value::is_truthy false is false" {
  @prelude.assert_false!(@tpl.Value::Bool(false).is_truthy())
}

test "Value::is_truthy true is true" {
  @prelude.assert_true!(@tpl.Value::Bool(true).is_truthy())
}

test "Value::is_truthy zero int is false" {
  @prelude.assert_false!(@tpl.Value::Int(0L).is_truthy())
}

test "Value::is_truthy non-zero int is true" {
  @prelude.assert_true!(@tpl.Value::Int(1L).is_truthy())
}

test "Value::is_truthy zero float is false" {
  @prelude.assert_false!(@tpl.Value::Float(0.0).is_truthy())
}

test "Value::is_truthy non-zero float is true" {
  @prelude.assert_true!(@tpl.Value::Float(0.1).is_truthy())
}

test "Value::is_truthy empty string is false" {
  @prelude.assert_false!(@tpl.Value::Str("").is_truthy())
}

test "Value::is_truthy non-empty string is true" {
  @prelude.assert_true!(@tpl.Value::Str("hello").is_truthy())
}

test "Value::is_truthy empty array is false" {
  let arr : Array[@tpl.Value] = Array::new()
  @prelude.assert_false!(@tpl.Value::Array(arr).is_truthy())
}

test "Value::is_truthy non-empty array is true" {
  @prelude.assert_true!(@tpl.Value::Array([@tpl.Value::Int(1L)]).is_truthy())
}

test "Value::is_truthy empty object is false" {
  let m : Map[String, @tpl.Value] = Map::new()
  @prelude.assert_false!(@tpl.Value::Object(m).is_truthy())
}

test "Value::is_truthy non-empty object is true" {
  let m : Map[String, @tpl.Value] = Map::new()
  m["key"] = @tpl.Value::Int(1L)
  @prelude.assert_true!(@tpl.Value::Object(m).is_truthy())
}

// =============================================================================
// Value::type_name
// =============================================================================

test "Value::type_name" {
  @prelude.assert_eq!(@tpl.Value::Null.type_name(), "null")
  @prelude.assert_eq!(@tpl.Value::Bool(true).type_name(), "bool")
  @prelude.assert_eq!(@tpl.Value::Int(0L).type_name(), "int")
  @prelude.assert_eq!(@tpl.Value::Float(0.0).type_name(), "float")
  @prelude.assert_eq!(@tpl.Value::Str("").type_name(), "string")
  @prelude.assert_eq!(@tpl.Value::Array([]).type_name(), "array")
  let m : Map[String, @tpl.Value] = Map::new()
  @prelude.assert_eq!(@tpl.Value::Object(m).type_name(), "object")
}

// =============================================================================
// AST type construction (compile-time check that types exist)
// =============================================================================

test "Expr literal construction" {
  let lit = @tpl.Expr::Literal(@tpl.Value::Int(42L))
  match lit {
    @tpl.Expr::Literal(v) => @prelude.assert_eq!(v.to_string(), "42")
    _ => @prelude.assert_false!(true)
  }
}

test "Expr variable construction" {
  let v = @tpl.Expr::Variable("name")
  match v {
    @tpl.Expr::Variable(n) => @prelude.assert_eq!(n, "name")
    _ => @prelude.assert_false!(true)
  }
}

test "Expr member access" {
  let v = @tpl.Expr::Variable("user")
  let m = @tpl.Expr::Member(v, "name")
  match m {
    @tpl.Expr::Member(_, field) => @prelude.assert_eq!(field, "name")
    _ => @prelude.assert_false!(true)
  }
}

test "Expr binop" {
  let lhs = @tpl.Expr::Literal(@tpl.Value::Int(1L))
  let rhs = @tpl.Expr::Literal(@tpl.Value::Int(2L))
  let op = @tpl.Expr::BinOp(lhs, @tpl.BinOpKind::Add, rhs)
  match op {
    @tpl.Expr::BinOp(_, k, _) => @prelude.assert_eq!(k, @tpl.BinOpKind::Add)
    _ => @prelude.assert_false!(true)
  }
}

test "Expr unaryop" {
  let v = @tpl.Expr::Literal(@tpl.Value::Bool(true))
  let op = @tpl.Expr::UnaryOp(@tpl.UnaryOpKind::Not, v)
  match op {
    @tpl.Expr::UnaryOp(@tpl.UnaryOpKind::Not, _) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "Expr filter" {
  let v = @tpl.Expr::Variable("name")
  let f = @tpl.Expr::Filter(v, "upper", [])
  match f {
    @tpl.Expr::Filter(_, name, _) => @prelude.assert_eq!(name, "upper")
    _ => @prelude.assert_false!(true)
  }
}

// =============================================================================
// Node construction
// =============================================================================

test "Node text" {
  let n = @tpl.Node::Text("hello")
  match n {
    @tpl.Node::Text(s) => @prelude.assert_eq!(s, "hello")
    _ => @prelude.assert_false!(true)
  }
}

test "Node output" {
  let n = @tpl.Node::Output(@tpl.Expr::Variable("x"))
  match n {
    @tpl.Node::Output(_) => @prelude.assert_true!(true)
    _ => @prelude.assert_false!(true)
  }
}

test "Node if" {
  let cond = @tpl.Expr::Literal(@tpl.Value::Bool(true))
  let then_body : Array[@tpl.Node] = [@tpl.Node::Text("yes")]
  let elifs : Array[@tpl.ElifBranch] = []
  let else_body : Array[@tpl.Node] = [@tpl.Node::Text("no")]
  let n = @tpl.Node::If(cond, then_body, elifs, else_body)
  match n {
    @tpl.Node::If(_, tb, _, eb) => {
      @prelude.assert_eq!(tb.length(), 1)
      @prelude.assert_eq!(eb.length(), 1)
    }
    _ => @prelude.assert_false!(true)
  }
}

test "Node for" {
  let n = @tpl.Node::For(
    "item",
    @tpl.Expr::Variable("items"),
    [@tpl.Node::Output(@tpl.Expr::Variable("item"))],
  )
  match n {
    @tpl.Node::For(var, _, body) => {
      @prelude.assert_eq!(var, "item")
      @prelude.assert_eq!(body.length(), 1)
    }
    _ => @prelude.assert_false!(true)
  }
}

test "Node block" {
  let n = @tpl.Node::Block("content", [@tpl.Node::Text("body")])
  match n {
    @tpl.Node::Block(name, body) => {
      @prelude.assert_eq!(name, "content")
      @prelude.assert_eq!(body.length(), 1)
    }
    _ => @prelude.assert_false!(true)
  }
}

test "Node extends" {
  let n = @tpl.Node::Extends("base.html")
  match n {
    @tpl.Node::Extends(name) => @prelude.assert_eq!(name, "base.html")
    _ => @prelude.assert_false!(true)
  }
}

test "Node include" {
  let n = @tpl.Node::Include("header.html")
  match n {
    @tpl.Node::Include(name) => @prelude.assert_eq!(name, "header.html")
    _ => @prelude.assert_false!(true)
  }
}

test "Node macro" {
  let n = @tpl.Node::Macro("input", ["name", "type"], [@tpl.Node::Text("<input>")])
  match n {
    @tpl.Node::Macro(nm, args, _) => {
      @prelude.assert_eq!(nm, "input")
      @prelude.assert_eq!(args.length(), 2)
    }
    _ => @prelude.assert_false!(true)
  }
}

test "Node filter block" {
  let n = @tpl.Node::FilterBlock("upper", [], [@tpl.Node::Text("loud")])
  match n {
    @tpl.Node::FilterBlock(name, _, body) => {
      @prelude.assert_eq!(name, "upper")
      @prelude.assert_eq!(body.length(), 1)
    }
    _ => @prelude.assert_false!(true)
  }
}

// =============================================================================
// Parser skeleton
// =============================================================================

test "Parser new and peek" {
  let tokens = @tpl.tokenize("hello")
  let tokens = match tokens {
    Ok(t) => t
    _ => @prelude.fail("tokenize failed")
  }
  let p = @tpl.Parser::new(tokens)
  let tok = p.peek()
  match tok {
    Some(t) => @prelude.assert_eq!(t.kind, @tpl.TokenKind::Text("hello"))
    None => @prelude.assert_false!(true)
  }
}

test "Parser advance" {
  let tokens = @tpl.tokenize("a")
  let tokens = match tokens {
    Ok(t) => t
    _ => @prelude.fail("tokenize failed")
  }
  let p = @tpl.Parser::new(tokens)
  let (tok, p2) = p.advance()
  match tok {
    Some(t) => @prelude.assert_eq!(t.kind, @tpl.TokenKind::Text("a"))
    None => @prelude.assert_false!(true)
  }
}

test "Parser peek_at" {
  let tokens = @tpl.tokenize("hello world")
  let tokens = match tokens {
    Ok(t) => t
    _ => @prelude.fail("tokenize failed")
  }
  let p = @tpl.Parser::new(tokens)
  let t0 = p.peek_at(0)
  let t1 = p.peek_at(1)
  match (t0, t1) {
    (Some(a), Some(b)) => {
      @prelude.assert_eq!(a.kind, @tpl.TokenKind::Text("hello world"))
      @prelude.assert_eq!(b.kind, @tpl.TokenKind::Eof)
    }
    _ => @prelude.assert_false!(true)
  }
}

test "Parser parse_template returns empty initially" {
  let tokens = @tpl.tokenize("{{ name }}")
  let tokens = match tokens {
    Ok(t) => t
    _ => @prelude.fail("tokenize failed")
  }
  let p = @tpl.Parser::new(tokens)
  let result = p.parse_template()
  match result {
    Ok((nodes, _)) => @prelude.assert_eq!(nodes.length(), 0)
    Err(_) => @prelude.assert_false!(true)
  }
}

test "Template struct" {
  let tpl = @tpl.Template::{ name: "test.html", nodes: [] }
  @prelude.assert_eq!(tpl.name, "test.html")
  @prelude.assert_eq!(tpl.nodes.length(), 0)
}
