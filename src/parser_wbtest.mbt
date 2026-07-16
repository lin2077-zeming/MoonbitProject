// ---------------------------------------------------------------------------
// MoonTera — Parser white-box tests
// ---------------------------------------------------------------------------

/// Helper: create a token array from token kinds (with dummy positions).
fn make_tokens(kinds : Array[TokenKind]) -> Array[Token] {
  let tokens : Array[Token] = []
  for i = 0; i < kinds.length(); i = i + 1 {
    tokens.push(Token::{ kind: kinds[i], line: 1, col: 1 })
  }
  tokens
}

/// Helper: make a single token.
fn tk(kind : TokenKind) -> Token {
  Token::{ kind, line: 1, col: 1 }
}

// ===========================================================================
// Expression parsing — operator precedence
// ===========================================================================

test "parse — precedence: * before +" {
  let tokens = make_tokens([TokenKind::Int("1"), TokenKind::Plus, TokenKind::Int("2"), TokenKind::Star, TokenKind::Int("3")])
  match parse_expression(tokens) {
    Ok(expr) => match expr {
      Expr::BinOp(Expr::Literal(Value::Int(1L)), BinOpKind::Add,
        Expr::BinOp(Expr::Literal(Value::Int(2L)), BinOpKind::Mul, Expr::Literal(Value::Int(3L)))) =>
        assert_true!(true)
      _ => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "parse — precedence: and before or" {
  let tokens = make_tokens([TokenKind::Ident("a"), TokenKind::Or, TokenKind::Ident("b"), TokenKind::And, TokenKind::Ident("c")])
  match parse_expression(tokens) {
    Ok(expr) => match expr {
      Expr::BinOp(Expr::Variable("a"), BinOpKind::Or, _) => assert_true!(true)
      _ => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "parse — member access chain a.b.c" {
  let tokens = make_tokens([TokenKind::Ident("a"), TokenKind::Dot, TokenKind::Ident("b"), TokenKind::Dot, TokenKind::Ident("c")])
  match parse_expression(tokens) {
    Ok(expr) => match expr {
      Expr::Member(Expr::Member(Expr::Variable("a"), "b"), "c") => assert_true!(true)
      _ => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "parse — numeric literals" {
  let tokens = make_tokens([TokenKind::Int("42")])
  match parse_expression(tokens) {
    Ok(expr) => match expr {
      Expr::Literal(Value::Int(42L)) => assert_true!(true)
      _ => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "parse — string literal" {
  let tokens = make_tokens([TokenKind::Str("hello")])
  match parse_expression(tokens) {
    Ok(expr) => match expr {
      Expr::Literal(Value::Str("hello")) => assert_true!(true)
      _ => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "parse — unary minus" {
  let tokens = make_tokens([TokenKind::Minus, TokenKind::Int("5")])
  match parse_expression(tokens) {
    Ok(expr) => match expr {
      Expr::UnaryOp(UnaryOpKind::Neg, Expr::Literal(Value::Int(5L))) => assert_true!(true)
      _ => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "parse — filter chain" {
  let tokens = make_tokens([TokenKind::Ident("x"), TokenKind::Pipe, TokenKind::Ident("upper"), TokenKind::Pipe, TokenKind::Ident("trim")])
  match parse_expression(tokens) {
    Ok(expr) => match expr {
      Expr::Filter(Expr::Filter(Expr::Variable("x"), "upper", _), "trim", _) => assert_true!(true)
      _ => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

// ===========================================================================
// Template parsing — nested structures
// ===========================================================================

test "parse — nested if" {
  match Template::parse("test", "{% if a %}{% if b %}inner{% endif %}{% endif %}") {
    Ok(tpl) => match tpl.nodes[0] {
      Node::If(_, then_body, _, _) => match then_body[0] {
        Node::If(_, inner_then, _, _) => match inner_then[0] {
          Node::Text(s) => assert_true!(s == "inner")
          _ => assert_true!(false)
        }
        _ => assert_true!(false)
      }
      _ => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "parse — if inside for" {
  match Template::parse("test", "{% for x in items %}{% if x > 5 %}big{% endif %}{% endfor %}") {
    Ok(tpl) => match tpl.nodes[0] {
      Node::For(_, _, body) => match body[0] {
        Node::If(_, _, _, _) => assert_true!(true)
        _ => assert_true!(false)
      }
      _ => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "parse — for inside for" {
  match Template::parse("test", "{% for a in o %}{% for b in i %}{{ a }}{{ b }}{% endfor %}{% endfor %}") {
    Ok(tpl) => match tpl.nodes[0] {
      Node::For(_, _, body) => match body[0] {
        Node::For(_, _, _) => assert_true!(true)
        _ => assert_true!(false)
      }
      _ => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "parse — extends sets parent" {
  match Template::parse("test", "{% extends \"base.html\" %}{% block t %}T{% endblock %}") {
    Ok(tpl) => match tpl.parent {
      Some(p) => assert_true!(p == "base.html")
      None => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "parse — block extraction" {
  match Template::parse("test", "{% block a %}A{% endblock %}{% block b %}B{% endblock %}") {
    Ok(tpl) => {
      assert_true!(tpl.block_names.length() == 2)
    }
    Err(_) => assert_true!(false)
  }
}

test "parse — macro definition" {
  match Template::parse("test", "{% macro btn(label) %}<button>{{ label }}</button>{% endmacro %}") {
    Ok(tpl) => match tpl.nodes[0] {
      Node::Macro(name, params, _) => {
        assert_true!(name == "btn")
        assert_true!(params.length() == 1)
        assert_true!(params[0] == "label")
      }
      _ => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

// ===========================================================================
// Parse errors
// ===========================================================================

test "parse error — missing endif" {
  match Template::parse("test", "{% if x %}hello") {
    Ok(_) => assert_true!(false)
    Err(_) => assert_true!(true)
  }
}

test "parse error — missing endfor" {
  match Template::parse("test", "{% for x in items %}hello") {
    Ok(_) => assert_true!(false)
    Err(_) => assert_true!(true)
  }
}

test "parse error — missing endblock" {
  match Template::parse("test", "{% block x %}hello") {
    Ok(_) => assert_true!(false)
    Err(_) => assert_true!(true)
  }
}
