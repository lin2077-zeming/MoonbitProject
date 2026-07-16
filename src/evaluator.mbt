// ---------------------------------------------------------------------------
// MoonTera — Expression Evaluator
// ---------------------------------------------------------------------------

pub fn evaluate(expr : Expr, ctx : Context, filters : FilterRegistry) -> Result[Value, String] {
  match expr {
    Expr::Literal(v) => Ok(v)
    Expr::Variable(name) => match ctx.get(name) {
      Some(v) => Ok(v)
      None => Err("Undefined variable: " + name)
    }
    Expr::UnaryOp(op, inner) => match evaluate(inner, ctx, filters) {
      Ok(val) => eval_unary(op, val)
      Err(e) => Err(e)
    }
    Expr::BinOp(lhs, op, rhs) => eval_binary(lhs, op, rhs, ctx, filters)
    Expr::Member(obj_expr, key) => match evaluate(obj_expr, ctx, filters) {
      Ok(obj) => Ok(eval_member(obj, key))
      Err(e) => Err(e)
    }
    Expr::Index(obj_expr, idx_expr) => match evaluate(obj_expr, ctx, filters) {
      Ok(obj) => match evaluate(idx_expr, ctx, filters) {
        Ok(idx) => eval_index(obj, idx)
        Err(e) => Err(e)
      }
      Err(e) => Err(e)
    }
    Expr::Filter(inner, filter_name, args) => {
      match evaluate(inner, ctx, filters) {
        Ok(val) => apply_filter(val, filter_name, args, ctx, filters)
        Err(e) => Err(e)
      }
    }
    Expr::Call(name, args) => eval_call(name, args, ctx, filters)
  }
}

fn eval_unary(op : UnaryOpKind, val : Value) -> Result[Value, String] {
  match op {
    UnaryOpKind::Neg => match val {
      Value::Int(n) => Ok(Value::Int(-n))
      Value::Float(f) => Ok(Value::Float(-f))
      _ => Err("Cannot negate non-numeric value")
    }
    UnaryOpKind::Not => Ok(Value::Bool(!val.is_truthy()))
  }
}

fn eval_member(obj : Value, key : String) -> Value {
  match obj {
    Value::Object(m) => match m.get(key) { Some(v) => v; None => Value::Null }
    _ => Value::Null
  }
}

fn eval_binary(lhs_expr : Expr, op : BinOpKind, rhs_expr : Expr, ctx : Context, filters : FilterRegistry) -> Result[Value, String] {
  match op {
    BinOpKind::And => match evaluate(lhs_expr, ctx, filters) {
      Ok(left) => if !left.is_truthy() { Ok(left) } else { evaluate(rhs_expr, ctx, filters) }
      Err(e) => Err(e)
    }
    BinOpKind::Or => match evaluate(lhs_expr, ctx, filters) {
      Ok(left) => if left.is_truthy() { Ok(left) } else { evaluate(rhs_expr, ctx, filters) }
      Err(e) => Err(e)
    }
    _ => match evaluate(lhs_expr, ctx, filters) {
      Ok(lhs) => match evaluate(rhs_expr, ctx, filters) {
        Ok(rhs) => apply_binop(lhs, op, rhs)
        Err(e) => Err(e)
      }
      Err(e) => Err(e)
    }
  }
}

fn apply_binop(lhs : Value, op : BinOpKind, rhs : Value) -> Result[Value, String] {
  match op {
    BinOpKind::Add => add_values(lhs, rhs)
    BinOpKind::Sub => num_op(lhs, rhs, fn(a, b) { a - b }, fn(a, b) { a - b })
    BinOpKind::Mul => num_op(lhs, rhs, fn(a, b) { a * b }, fn(a, b) { a * b })
    BinOpKind::Div => num_op(lhs, rhs, fn(a, b) { a / b }, fn(a, b) { a / b })
    BinOpKind::Mod => int_op(lhs, rhs, fn(a, b) { a % b })
    BinOpKind::Eq => Ok(Value::Bool(values_equal(lhs, rhs)))
    BinOpKind::Neq => Ok(Value::Bool(!values_equal(lhs, rhs)))
    BinOpKind::Lt => cmp_op(lhs, rhs, fn(a, b) { a < b }, fn(a, b) { a < b })
    BinOpKind::Gt => cmp_op(lhs, rhs, fn(a, b) { a > b }, fn(a, b) { a > b })
    BinOpKind::Le => cmp_op(lhs, rhs, fn(a, b) { a <= b }, fn(a, b) { a <= b })
    BinOpKind::Ge => cmp_op(lhs, rhs, fn(a, b) { a >= b }, fn(a, b) { a >= b })
    BinOpKind::And => Ok(Value::Bool(lhs.is_truthy() && rhs.is_truthy()))
    BinOpKind::Or => Ok(Value::Bool(lhs.is_truthy() || rhs.is_truthy()))
  }
}

fn add_values(lhs : Value, rhs : Value) -> Result[Value, String] {
  match (lhs, rhs) {
    (Value::Int(a), Value::Int(b)) => Ok(Value::Int(a + b))
    (Value::Int(a), Value::Float(b)) => Ok(Value::Float(a.to_double() + b))
    (Value::Float(a), Value::Int(b)) => Ok(Value::Float(a + b.to_double()))
    (Value::Float(a), Value::Float(b)) => Ok(Value::Float(a + b))
    (Value::Str(a), Value::Str(b)) => Ok(Value::Str(a + b))
    (Value::Str(a), b) => Ok(Value::Str(a + b.to_string()))
    (a, Value::Str(b)) => Ok(Value::Str(a.to_string() + b))
    _ => Err("Cannot add values of these types")
  }
}

fn num_op(lhs : Value, rhs : Value, int_fn : (Int64, Int64) -> Int64, float_fn : (Double, Double) -> Double) -> Result[Value, String] {
  match (lhs, rhs) {
    (Value::Int(a), Value::Int(b)) => Ok(Value::Int(int_fn(a, b)))
    (Value::Int(a), Value::Float(b)) => Ok(Value::Float(float_fn(a.to_double(), b)))
    (Value::Float(a), Value::Int(b)) => Ok(Value::Float(float_fn(a, b.to_double())))
    (Value::Float(a), Value::Float(b)) => Ok(Value::Float(float_fn(a, b)))
    _ => Err("Cannot apply numeric operator to non-numeric values")
  }
}

fn int_op(lhs : Value, rhs : Value, int_fn : (Int64, Int64) -> Int64) -> Result[Value, String] {
  match (lhs, rhs) {
    (Value::Int(a), Value::Int(b)) => Ok(Value::Int(int_fn(a, b)))
    _ => Err("Modulo requires integer operands")
  }
}

fn cmp_op(lhs : Value, rhs : Value, int_fn : (Int64, Int64) -> Bool, float_fn : (Double, Double) -> Bool) -> Result[Value, String] {
  match (lhs, rhs) {
    (Value::Int(a), Value::Int(b)) => Ok(Value::Bool(int_fn(a, b)))
    (Value::Int(a), Value::Float(b)) => Ok(Value::Bool(float_fn(a.to_double(), b)))
    (Value::Float(a), Value::Int(b)) => Ok(Value::Bool(float_fn(a, b.to_double())))
    (Value::Float(a), Value::Float(b)) => Ok(Value::Bool(float_fn(a, b)))
    (Value::Str(a), Value::Str(b)) => Ok(Value::Bool(a == b))
    _ => Ok(Value::Bool(false))
  }
}

fn values_equal(lhs : Value, rhs : Value) -> Bool {
  match (lhs, rhs) {
    (Value::Null, Value::Null) => true
    (Value::Bool(a), Value::Bool(b)) => a == b
    (Value::Int(a), Value::Int(b)) => a == b
    (Value::Float(a), Value::Float(b)) => a == b
    (Value::Str(a), Value::Str(b)) => a == b
    (Value::Int(a), Value::Float(b)) => a.to_double() == b
    (Value::Float(a), Value::Int(b)) => a == b.to_double()
    _ => false
  }
}

fn eval_index(obj : Value, idx : Value) -> Result[Value, String] {
  match (obj, idx) {
    (Value::Array(arr), Value::Int(n)) => {
      let i = n.to_int()
      if i >= 0 && i < arr.length() { Ok(arr[i]) }
      else { Err("Array index out of bounds: " + n.to_string()) }
    }
    (Value::Str(s), Value::Int(n)) => {
      let i = n.to_int()
      if i >= 0 && i < s.length() { Ok(Value::Str(s[i].to_string())) }
      else { Err("String index out of bounds: " + n.to_string()) }
    }
    (Value::Object(m), Value::Str(key)) => match m.get(key) { Some(v) => Ok(v); None => Ok(Value::Null) }
    _ => Err("Cannot index into this type")
  }
}

fn apply_filter(val : Value, filter_name : String, args : Array[Expr], ctx : Context, filters : FilterRegistry) -> Result[Value, String] {
  match filters.get(filter_name) {
    Some(filter_fn) => {
      let arg_vals : Array[Value] = []
      for i = 0; i < args.length(); i = i + 1 {
        match evaluate(args[i], ctx, filters) {
          Ok(v) => arg_vals.push(v)
          Err(e) => return Err(e)
        }
      }
      filter_fn(val, arg_vals)
    }
    None => Err("Unknown filter: " + filter_name)
  }
}

fn eval_call(name : String, args : Array[Expr], ctx : Context, filters : FilterRegistry) -> Result[Value, String] {
  match ctx.get_macro(name) {
    Some(macro_def) => {
      let arg_vals : Array[Value] = []
      for i = 0; i < args.length(); i = i + 1 {
        match evaluate(args[i], ctx, filters) {
          Ok(v) => arg_vals.push(v)
          Err(e) => return Err(e)
        }
      }
      let child_ctx = Context::new_child(ctx)
      for i = 0; i < macro_def.params.length(); i = i + 1 {
        let pv = if i < arg_vals.length() { arg_vals[i] } else { Value::Null }
        child_ctx.set(macro_def.params[i], pv)
      }
      let renderer = Renderer::new(child_ctx)
      match renderer.render_nodes(macro_def.body) {
        Ok(result) => Ok(Value::Str(result.output))
        Err(e) => Err(e)
      }
    }
    None => Err("Unknown function or macro: " + name)
  }
}
