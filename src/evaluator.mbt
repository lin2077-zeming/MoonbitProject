// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Evaluator — evaluates `Expr` nodes to `Value`s at render time.

// ---------------------------------------------------------------------------
// Arithmetic wrapper functions (must be defined before use)
// ---------------------------------------------------------------------------

fn sub_int64(a : Int64, b : Int64) -> Int64 { a - b }
fn mul_int64(a : Int64, b : Int64) -> Int64 { a * b }
fn div_int64(a : Int64, b : Int64) -> Int64 { a / b }

fn sub_double(a : Double, b : Double) -> Double { a - b }
fn mul_double(a : Double, b : Double) -> Double { a * b }
fn div_double(a : Double, b : Double) -> Double { a / b }

fn lt_int64(a : Int64, b : Int64) -> Bool { a < b }
fn gt_int64(a : Int64, b : Int64) -> Bool { a > b }
fn le_int64(a : Int64, b : Int64) -> Bool { a <= b }
fn ge_int64(a : Int64, b : Int64) -> Bool { a >= b }

fn lt_double(a : Double, b : Double) -> Bool { a < b }
fn gt_double(a : Double, b : Double) -> Bool { a > b }
fn le_double(a : Double, b : Double) -> Bool { a <= b }
fn ge_double(a : Double, b : Double) -> Bool { a >= b }

// ---------------------------------------------------------------------------
// Map helper (avoid Map indexing Option issues)
// ---------------------------------------------------------------------------

fn map_has_key(m : Map[String, Value], key : String) -> Bool {
  for k in m.keys() {
    if k == key {
      return true
    }
  }
  false
}

// ---------------------------------------------------------------------------
// String helper — convert a single UInt16 to a String
// ---------------------------------------------------------------------------

fn char_to_string(_ch : UInt16) -> String {
  // Placeholder: proper Char→String conversion pending.
  // For now, return a single-character string via format.
  String::default()
}

// ---------------------------------------------------------------------------
// Structural equality
// ---------------------------------------------------------------------------

fn eval_eq(left : Value, right : Value) -> Bool {
  match (left, right) {
    (Null, Null) => true
    (Bool(a), Bool(b)) => a == b
    (Int(a), Int(b)) => a == b
    (Int(a), Float(b)) => a.to_double() == b
    (Float(a), Int(b)) => a == b.to_double()
    (Float(a), Float(b)) => a == b
    (Str(a), Str(b)) => a == b
    (Array(a), Array(b)) => {
      if a.length() != b.length() {
        return false
      }
      let mut i = 0
      let mut same = true
      while i < a.length() {
        if !eval_eq(a[i], b[i]) {
          same = false
          break
        }
        i = i + 1
      }
      same
    }
    (Object(_), Object(_)) => false
    _ => false
  }
}

// ---------------------------------------------------------------------------
// Binary operation helpers
// ---------------------------------------------------------------------------

fn eval_add(left : Value, right : Value) -> Result[Value, String] {
  match (left, right) {
    (Str(a), Str(b)) => Ok(Str(a + b))
    (Str(a), _) => Ok(Str(a + right.to_string()))
    (_, Str(b)) => Ok(Str(left.to_string() + b))
    (Int(a), Int(b)) => Ok(Int(a + b))
    (Int(a), Float(b)) => Ok(Float(a.to_double() + b))
    (Float(a), Int(b)) => Ok(Float(a + b.to_double()))
    (Float(a), Float(b)) => Ok(Float(a + b))
    _ => Err("Cannot add types: " + left.type_name() + " + " + right.type_name())
  }
}

fn eval_arithmetic(
  left : Value,
  right : Value,
  op_int : (Int64, Int64) -> Int64,
  op_float : (Double, Double) -> Double
) -> Result[Value, String] {
  match (left, right) {
    (Int(a), Int(b)) => Ok(Int(op_int(a, b)))
    (Int(a), Float(b)) => Ok(Float(op_float(a.to_double(), b)))
    (Float(a), Int(b)) => Ok(Float(op_float(a, b.to_double())))
    (Float(a), Float(b)) => Ok(Float(op_float(a, b)))
    _ => Err(
      "Cannot perform arithmetic on types: " +
      left.type_name() +
      " and " +
      right.type_name(),
    )
  }
}

fn eval_mod(left : Value, right : Value) -> Result[Value, String] {
  match (left, right) {
    (Int(a), Int(b)) => Ok(Int(a % b))
    (Float(a), Float(b)) => Ok(Float(a % b))
    (Int(a), Float(b)) => Ok(Float(a.to_double() % b))
    (Float(a), Int(b)) => Ok(Float(a % b.to_double()))
    _ => Err(
      "Cannot compute modulo for types: " +
      left.type_name() +
      " and " +
      right.type_name(),
    )
  }
}

fn eval_compare(
  left : Value,
  right : Value,
  cmp_int : (Int64, Int64) -> Bool,
  cmp_float : (Double, Double) -> Bool
) -> Result[Value, String] {
  match (left, right) {
    (Int(a), Int(b)) => Ok(Bool(cmp_int(a, b)))
    (Int(a), Float(b)) => Ok(Bool(cmp_float(a.to_double(), b)))
    (Float(a), Int(b)) => Ok(Bool(cmp_float(a, b.to_double())))
    (Float(a), Float(b)) => Ok(Bool(cmp_float(a, b)))
    (Str(a), Str(b)) => Ok(Bool(cmp_int(a.length().to_int64(), b.length().to_int64())))
    _ => Err(
      "Cannot compare types: " +
      left.type_name() +
      " and " +
      right.type_name(),
    )
  }
}

fn eval_binop(left : Value, op : BinOpKind, right : Value) -> Result[Value, String] {
  match op {
    BinOpKind::Add => eval_add(left, right)
    BinOpKind::Sub => eval_arithmetic(left, right, sub_int64, sub_double)
    BinOpKind::Mul => eval_arithmetic(left, right, mul_int64, mul_double)
    BinOpKind::Div => eval_arithmetic(left, right, div_int64, div_double)
    BinOpKind::Mod => eval_mod(left, right)
    BinOpKind::Eq  => Ok(Bool(eval_eq(left, right)))
    BinOpKind::Neq => Ok(Bool(!eval_eq(left, right)))
    BinOpKind::Lt  => eval_compare(left, right, lt_int64, lt_double)
    BinOpKind::Gt  => eval_compare(left, right, gt_int64, gt_double)
    BinOpKind::Le  => eval_compare(left, right, le_int64, le_double)
    BinOpKind::Ge  => eval_compare(left, right, ge_int64, ge_double)
    BinOpKind::And => Ok(Bool(left.is_truthy() && right.is_truthy()))
    BinOpKind::Or  => Ok(Bool(left.is_truthy() || right.is_truthy()))
  }
}

// ---------------------------------------------------------------------------
// Index evaluation
// ---------------------------------------------------------------------------

fn eval_index(container : Value, index : Value) -> Result[Value, String] {
  match container {
    Array(arr) => match index {
      Int(i) => {
        let len = arr.length().to_int64()
        let actual = if i < 0L { len + i } else { i }
        if actual >= 0L && actual < len {
          Ok(arr[actual.to_int()])
        } else {
          Err("Index out of bounds: " + i.to_string() + " (length: " + len.to_string() + ")")
        }
      }
      _ => Err("Array index must be an integer, got: " + index.type_name())
    }
    Str(s) => match index {
      Int(i) => {
        let len = s.length().to_int64()
        let actual = if i < 0L { len + i } else { i }
        if actual >= 0L && actual < len {
          let ch = s[actual.to_int()]
          Ok(Str(char_to_string(ch)))
        } else {
          Err("String index out of bounds: " + i.to_string())
        }
      }
      _ => Err("String index must be an integer, got: " + index.type_name())
    }
    Object(m) => match index {
      Str(key) => {
        if map_has_key(m, key) {
          Ok(m[key])
        } else {
          Err("Key not found: " + key)
        }
      }
      _ => Err("Object key must be a string, got: " + index.type_name())
    }
    _ => Err("Cannot index type: " + container.type_name())
  }
}

// ---------------------------------------------------------------------------
// Evaluator struct
// ---------------------------------------------------------------------------

pub(all) struct Evaluator {
  ctx : Context
  filters : FilterRegistry
}

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

pub fn Evaluator::new(ctx : Context) -> Evaluator {
  {
    ctx: ctx,
    filters: FilterRegistry::default(),
  }
}

/// Create an evaluator with a specific filter registry.
pub fn Evaluator::new_with_filters(
  ctx : Context,
  filters : FilterRegistry
) -> Evaluator {
  { ctx: ctx, filters: filters }
}

// ---------------------------------------------------------------------------
// Top-level evaluation
// ---------------------------------------------------------------------------

pub fn Evaluator::eval(self : Evaluator, expr : Expr) -> Result[Value, String] {
  match expr {
    Literal(v) => Ok(v)

    Variable(name) => match self.ctx.get(name) {
      Option::Some(v) => Ok(v)
      Option::None => Err("Undefined variable: " + name)
    }

    Member(obj, field) => {
      let val_result = self.eval(obj)
      let val = match val_result {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      match val {
        Object(m) => {
          if map_has_key(m, field) {
            Ok(m[field])
          } else {
            Err("Field not found: " + field)
          }
        }
        _ => Err("Cannot access field '" + field + "' on type " + val.type_name())
      }
    }

    Index(container, index) => {
      let c = match self.eval(container) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let i = match self.eval(index) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      eval_index(c, i)
    }

    Call(name, _args) => Err("Function '" + name + "' not yet implemented")

    BinOp(lhs, op, rhs) => {
      match op {
        BinOpKind::And => {
          let left = match self.eval(lhs) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          if !left.is_truthy() {
            return Ok(left)
          }
          self.eval(rhs)
        }
        BinOpKind::Or => {
          let left = match self.eval(lhs) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          if left.is_truthy() {
            return Ok(left)
          }
          self.eval(rhs)
        }
        _ => {
          let left = match self.eval(lhs) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          let right = match self.eval(rhs) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          eval_binop(left, op, right)
        }
      }
    }

    UnaryOp(op, operand) => {
      let val = match self.eval(operand) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      match op {
        UnaryOpKind::Not => Ok(Bool(!val.is_truthy()))
        UnaryOpKind::Neg => match val {
          Int(i) => Ok(Int(-i))
          Float(f) => Ok(Float(-f))
          _ => Err("Cannot negate type: " + val.type_name())
        }
      }
    }

    // -- Filter ------------------------------------------------------------
    Filter(base, filter_name, args) => {
      let base_val = match self.eval(base) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      let eval_args : Array[Value] = Array::new()
      for arg in args {
        let arg_val = match self.eval(arg) {
          Ok(v) => v
          Err(msg) => return Err(msg)
        }
        eval_args.push(arg_val)
      }
      let filter_fn = match self.filters.lookup(filter_name) {
        Some(f) => f
        None => return Err("Unknown filter: " + filter_name)
      }
      filter_fn(base_val, eval_args)
    }
  }
}
