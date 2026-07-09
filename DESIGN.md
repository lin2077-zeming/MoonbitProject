# MoonBit 模板渲染引擎 — 架构设计文档

> 一个受 Tera / Jinja2 启发的 MoonBit 模板引擎，支持变量插值、控制流、
> 过滤器链、模板继承和自定义扩展。

---

## 目录

1. [项目概述](#1-项目概述)
2. [模块划分](#2-模块划分)
3. [词法分析设计](#3-词法分析设计)
4. [AST 节点类型定义](#4-ast-节点类型定义)
5. [核心数据结构](#5-核心数据结构)
6. [渲染流程与状态管理](#6-渲染流程与状态管理)
7. [错误处理设计](#7-错误处理设计)
8. [模板继承机制](#8-模板继承机制)
9. [过滤器系统](#9-过滤器系统)
10. [表达式求值引擎](#10-表达式求值引擎)
11. [API 设计](#11-api-设计)
12. [测试策略](#12-测试策略)
13. [文件结构](#13-文件结构)

---

## 1. 项目概述

### 1.1 设计目标

- **完整的模板语言**: 支持变量、循环、条件、过滤器、模板继承、include、macro
- **零依赖**: 仅使用 `moonbitlang/core` 标准库
- **安全**: 默认开启 HTML 自动转义，防止 XSS
- **高性能**: 解析一次，多次渲染；使用 `StringBuilder` 高效拼接
- **友好的错误信息**: 带源码位置的错误提示，便于调试
- **可扩展**: Trait 驱动的过滤器/测试器注册机制

### 1.2 模板语法概览

```jinja2
{# 这是注释 #}

{# 变量插值 #}
<h1>{{ title }}</h1>
<p>{{ user.name | upper }}</p>

{# 条件判断 #}
{% if user.is_admin %}
  <a href="/admin">管理后台</a>
{% elif user.is_moderator %}
  <span>版主</span>
{% else %}
  <span>普通用户</span>
{% endif %}

{# 循环 #}
{% for item in items %}
  <li>{{ loop.index }}: {{ item.name | escape }}</li>
{% else %}
  <li>列表为空</li>
{% endfor %}

{# 变量赋值 #}
{% set full_name = first_name ~ " " ~ last_name %}

{# 模板继承 #}
{% extends "base.html" %}
{% block content %}
  <p>这是子模板的内容</p>
{% endblock %}

{# 引入 #}
{% include "partials/header.html" %}

{# 宏定义 #}
{% macro input(name, value="", type="text") %}
  <input type="{{ type }}" name="{{ name }}" value="{{ value }}">
{% endmacro %}
```

### 1.3 数据流概览

```
┌──────────────┐     ┌────────────┐     ┌──────────┐     ┌──────────────┐
│   Template   │────▶│   Lexer    │────▶│  Parser  │────▶│     AST      │
│   (String)   │     │  (Token[]) │     │          │     │  (Node[])    │
└──────────────┘     └────────────┘     └──────────┘     └──────┬───────┘
                                                                │
                          ┌─────────────────────────────────────┘
                          ▼
┌──────────────┐     ┌────────────┐     ┌──────────┐
│   Context    │────▶│  Renderer  │────▶│  Output   │
│   (Value)    │     │            │     │  (String) │
└──────────────┘     └────────────┘     └──────────┘
```

---

## 2. 模块划分

### 2.1 模块层次结构

```
moon.pkg.json
src/
├── lib.mbt              # 公共 API 入口，重导出
├── template.mbt          # Template 结构体及核心渲染方法
├── environment.mbt       # Environment 配置与模板注册
├── ast.mbt               # 所有 AST 节点类型定义
├── lexer.mbt             # 词法分析器：字符串 → Token 流
├── parser.mbt            # 语法分析器：Token 流 → AST
│   ├── parser_core.mbt   #   核心解析逻辑
│   ├── parser_expr.mbt   #   表达式解析（Pratt 解析器）
│   └── parser_tags.mbt   #   标签解析（{% %}, {{ }}, {# #}）
├── renderer.mbt          # 渲染引擎：AST + Context → String
│   ├── renderer_core.mbt #   核心遍历逻辑
│   └── renderer_expr.mbt #   表达式求值
├── value.mbt             # Value 类型与类型转换
├── context.mbt           # 渲染上下文（作用域栈）
├── filters.mbt           # 内置过滤器实现
├── tests.mbt             # 内置测试器实现（is defined, is odd 等）
├── errors.mbt            # 错误类型定义
├── inheritance.mbt       # 模板继承（extends/block）处理
├── autoescape.mbt        # HTML 自动转义
├── source.mbt            # 源码位置追踪（行号、列号）
└── builtins.mbt          # 全局内置函数（range, debug 等）
```

### 2.2 模块职责矩阵

| 模块 | 职责 | 依赖 |
|------|------|------|
| `lib` | 公共 API，类型重导出，文档入口 | 所有 |
| `template` | `Template` 结构体，`render()` 方法 | ast, renderer, context, value |
| `environment` | 模板注册、过滤器管理、全局配置 | template, filters, tests, autoescape |
| `ast` | 所有 AST 节点类型的 enum/struct 定义 | source |
| `lexer` | 模板字符串 → `Token` 流 | source |
| `parser` | `Token` 流 → `Array[Node]` AST | ast, lexer, source |
| `renderer` | AST 遍历 → 字符串输出 | ast, context, value, filters, autoescape |
| `value` | 运行时值的类型定义与操作 | — |
| `context` | 渲染作用域栈管理 | value |
| `filters` | 内置过滤器函数实现 | value, errors |
| `tests` | 内置测试器函数实现 | value |
| `errors` | 结构化错误类型 | source |
| `inheritance` | 继承链解析、block 收集与替换 | ast, template |
| `autoescape` | HTML 特殊字符转义策略 | value |
| `source` | 源码行号/列号追踪 | — |
| `builtins` | 全局函数（`range`, `now`, `debug`） | value, errors |

---

## 3. 词法分析设计

### 3.1 Token 类型

```moonbit
// src/lexer.mbt

/// 词法单元
pub(all) enum Token {
  // 字面量
  StringLit(String)       // "hello" 或 'hello'
  IntLit(Int64)           // 42, -7
  FloatLit(Double)        // 3.14, -0.5
  BoolLit(Bool)           // true, false
  Ident(String)           // user_name, item

  // 运算符
  Plus                   // +
  Minus                  // -
  Star                   // *
  Slash                  // /
  Percent                // %
  Tilde                  // ~  (字符串拼接)
  EqEq                   // ==
  Ne                     // !=
  Lt                     // <
  Le                     // <=
  Gt                     // >
  Ge                     // >=
  And                    // and
  Or                     // or
  Not                    // not
  Pipe                   // |  (过滤器)
  Dot                    // .
  LBracket               // [
  RBracket               // ]
  LParen                 // (
  RParen                 // )
  Comma                  // ,
  Colon                  // :
  Assign                 // =
  Question               // ?

  // 关键字
  KwIn                   // in
  KwIs                   // is

  // 标签分隔符
  VarStart               // {{
  VarEnd                 // }}
  BlockStart             // {%
  BlockEnd               // %}
  CommentStart           // {#
  CommentEnd             // #}

  // 标签关键字 (仅在 block 内部识别)
  TagIf                  // if
  TagElif                // elif
  TagElse                // else
  TagEndif               // endif
  TagFor                 // for
  TagEndfor              // endfor
  TagBlock               // block
  TagEndblock            // endblock
  TagExtends             // extends
  TagInclude             // include
  TagMacro               // macro
  TagEndmacro            // endmacro
  TagSet                 // set
  TagEndset              // endset
  TagSuper               // super
  TagCall                // call

  // 特殊
  Eof                    // 文件末尾
  RawText(String)        // 模板文本（标签外的普通文本）
}

/// 带位置信息的 Token
pub(all) struct TokenWithPos {
  token : Token
  pos : SourcePos
}
```

### 3.2 词法分析器状态机

```moonbit
/// 词法分析器内部状态
enum LexerState {
  Text           // 正在读取普通文本
  MaybeTag       // 遇到 {，可能是标签开始
  InExpr         // 在 {{ }} 表达式内部
  InBlock        // 在 {% %} 语句块内部
  InComment      // 在 {# #} 注释内部
  InString(DoubleQuote | SingleQuote)  // 在字符串字面量内部
}
```

### 3.3 Lexer 接口

```moonbit
// src/lexer.mbt

/// 词法分析器
struct Lexer {
  source : String
  pos : Int          // 当前字节偏移
  line : Int         // 当前行号
  col : Int          // 当前列号
  state : LexerState
}

/// 对模板源码进行词法分析，返回 Token 流
pub fn tokenize(source : String) -> Result[Array[TokenWithPos], TemplateError] {
  let lexer = Lexer::new(source)
  lexer.tokenize_all()
}
```

---

## 4. AST 节点类型定义

### 4.1 顶层节点

```moonbit
// src/ast.mbt

/// 模板顶层 AST 节点
pub(all) enum Node {
  Text(TextNode)
  Variable(VariableNode)
  Block(BlockNode)
  If(IfNode)
  For(ForNode)
  Include(IncludeNode)
  Extends(ExtendsNode)
  Set(SetNode)
  Macro(MacroNode)
  Call(CallNode)
  FilterBlock(FilterBlockNode)
  Comment
  Raw(RawNode)
}
```

### 4.2 各节点详细定义

```moonbit
// src/ast.mbt

// ---------------------------------------------------------------------------
// 纯文本节点 — 直接输出
// ---------------------------------------------------------------------------
pub(all) struct TextNode {
  content : String
}

// ---------------------------------------------------------------------------
// 变量输出节点 — {{ expr | filter1 | filter2 }}
// ---------------------------------------------------------------------------
pub(all) struct VariableNode {
  expr : Expr
  filters : Array[FilterCall]
}

// ---------------------------------------------------------------------------
// 过滤器调用 — filter_name(arg1, arg2, ...)
// ---------------------------------------------------------------------------
pub(all) struct FilterCall {
  name : String
  args : Array[Expr]
}

// ---------------------------------------------------------------------------
// Block 定义节点 — {% block name %}...{% endblock %}
// ---------------------------------------------------------------------------
pub(all) struct BlockNode {
  name : String
  body : Array[Node]
}

// ---------------------------------------------------------------------------
// 条件分支节点
// {% if cond1 %}...{% elif cond2 %}...{% else %}...{% endif %}
// ---------------------------------------------------------------------------
pub(all) struct IfNode {
  branches : Array[(Expr, Array[Node])]  // (条件, 分支体) 列表
  else_body : Array[Node]                 // else 分支（可为空数组）
}

// ---------------------------------------------------------------------------
// 循环节点 — {% for item in iterable %}...{% else %}...{% endfor %}
// ---------------------------------------------------------------------------
pub(all) struct ForNode {
  key : Option[String]             // 可选键变量: {% for k, v in map %}
  value : String                   // 值变量
  iterable : Expr                  // 被迭代的表达式
  body : Array[Node]               // 循环体
  else_body : Array[Node]          // 空迭代时的 else 分支
}

// ---------------------------------------------------------------------------
// Include 节点 — {% include "template.html" %}
// ---------------------------------------------------------------------------
pub(all) struct IncludeNode {
  template : Expr                          // 模板名（支持变量）
  context : Option<Array<(String, Expr)>>  // 可选传递上下文：{% include "t" with a=b %}
  ignore_missing : Bool                    // {% include "t" ignore missing %}
}

// ---------------------------------------------------------------------------
// Extends 节点 — {% extends "base.html" %}
// ---------------------------------------------------------------------------
pub(all) struct ExtendsNode {
  template : String    // 父模板名
}

// ---------------------------------------------------------------------------
// Set 节点 — {% set name = expr %}...{% endset %}
// ---------------------------------------------------------------------------
pub(all) struct SetNode {
  name : String
  value : Expr
  body : Option<Array[Node>>   // {% set name %}body{% endset %} 块赋值
}

// ---------------------------------------------------------------------------
// Macro 定义 — {% macro name(args) %}...{% endmacro %}
// ---------------------------------------------------------------------------
pub(all) struct MacroNode {
  name : String
  args : Array<MacroArg>
  body : Array[Node]
}

pub(all) struct MacroArg {
  name : String
  default : Option<Expr>
}

// ---------------------------------------------------------------------------
// Call 节点 — {% call macro_name(arg1, arg2) %}
// ---------------------------------------------------------------------------
pub(all) struct CallNode {
  name : String          // 宏名称
  args : Array<Expr>     // 位置参数
  kwargs : Array<(String, Expr)>  // 关键字参数
}

// ---------------------------------------------------------------------------
// FilterBlock 节点 — {% filter name(args) %}...{% endfilter %}
// ---------------------------------------------------------------------------
pub(all) struct FilterBlockNode {
  filter : String
  args : Array<Expr>
  body : Array<Node>
}

// ---------------------------------------------------------------------------
// Raw 节点 — {% raw %}...{% endraw %}
// ---------------------------------------------------------------------------
pub(all) struct RawNode {
  content : String
}

// ---------------------------------------------------------------------------
// Super 函数 — {{ super() }}  仅在 block 内部有效
// ---------------------------------------------------------------------------
// 不作为独立节点，而是通过 Expr::Super 表达
```

### 4.3 表达式 AST

```moonbit
// src/ast.mbt

/// 表达式类型 — 用于变量取值、条件判断、过滤器参数等
pub(all) enum Expr {
  // 字面量
  StringLit(String)
  IntLit(Int64)
  FloatLit(Double)
  BoolLit(Bool)
  ArrayLit(Array[Expr])
  DictLit(Array<(String, Expr)>)    // {key: val, ...}

  // 标识符
  Ident(String)                       // user_name

  // 成员访问
  Dot(Box[Expr], String)              // user.name
  Index(Box[Expr], Box[Expr])         // items[0]

  // 运算符
  Unary(UnaryOp, Box[Expr])           // not x, -x
  Binary(Box[Expr], BinaryOp, Box[Expr])  // a + b, a and b

  // 函数调用
  Call(String, Array[Expr])           // range(0, 10)

  // 测试表达式
  Test(Box[Expr], String, Array[Expr])  // x is defined, x is divisibleby(3)

  // 字符串拼接
  Concat(Array[Expr])                 // "a" ~ "b" ~ expr

  // 三元表达式
  Ternary(Box[Expr], Box[Expr], Box[Expr])  // a if cond else b

  // Super 调用（仅在 block 内部）
  Super

  // 空值 (None / null)
  Null
}

/// 二元运算符
pub(all) enum BinaryOp {
  Add        // +
  Sub        // -
  Mul        // *
  Div        // /
  Mod        // %
  Eq         // ==
  Ne         // !=
  Lt         // <
  Le         // <=
  Gt         // >
  Ge         // >=
  And        // and
  Or         // or
  In         // in
  Concat     // ~
}

/// 一元运算符
pub(all) enum UnaryOp {
  Not        // not
  Neg        // -
}

// ---------------------------------------------------------------------------
// 源码位置 — 每个节点携带位置信息，用于错误报告
// ---------------------------------------------------------------------------
pub(all) struct SourcePos {
  line : Int
  col : Int
  len : Int       // Token 长度
}

/// 带位置的节点包装
pub(all) struct Spanned[A] {
  node : A
  pos : SourcePos
}
```

### 4.4 AST 设计原则

1. **穷尽性**: 使用 `enum` 保证模式匹配穷尽，编译器会检查所有分支
2. **递归安全**: 使用 `Box[A]` 处理递归类型，避免栈溢出
3. **位置追踪**: 每个节点携带 `SourcePos`，错误信息精确定位到行列
4. **零拷贝**: 标识符和字面量尽可能引用原始源码切片（在内存允许时）

---

## 5. 核心数据结构

### 5.1 Value — 运行时值

```moonbit
// src/value.mbt

/// 模板引擎运行时值的统一表示
pub(all) enum Value {
  Null
  Bool(Bool)
  Int(Int64)
  Float(Double)
  String(String)
  Array(Array[Value])
  Map(Map[String, Value])
  SafeHtml(String)       // 已转义的安全 HTML，不会被再次转义
}

/// Value 的常用操作
impl Value {
  /// 判断值是否为"真"（用于条件判断）
  pub fn is_truthy(self : Value) -> Bool {
    match self {
      Null => false
      Bool(b) => b
      Int(i) => i != 0L
      Float(f) => f != 0.0
      String(s) => s != ""
      Array(a) => a.length() > 0
      Map(m) => m.size() > 0
      SafeHtml(s) => s != ""
    }
  }

  /// 获取字符串表示
  pub fn to_string(self : Value) -> String {
    match self {
      Null => "null"
      Bool(b) => if b { "true" } else { "false" }
      Int(i) => i.to_string()
      Float(f) => f.to_string()
      String(s) => s
      SafeHtml(s) => s
      Array(_) => "[Array]"
      Map(_) => "[Map]"
    }
  }

  /// 获取类型的字符串描述
  pub fn type_name(self : Value) -> String {
    match self {
      Null => "null"
      Bool(_) => "bool"
      Int(_) => "int"
      Float(_) => "float"
      String(_) => "string"
      SafeHtml(_) => "SafeHtml"
      Array(_) => "array"
      Map(_) => "map"
    }
  }

  /// 索引访问 value[index]
  pub fn index(self : Value, idx : Value) -> Result[Value, TemplateError] {
    match (self, idx) {
      (Array(arr), Int(i)) => {
        // 支持负索引
        let actual_idx = if i < 0L { arr.length().to_int64() + i } else { i }
        if actual_idx >= 0L && actual_idx < arr.length().to_int64() {
          Ok(arr[actual_idx.to_int()])
        } else {
          Err(TemplateError::index_out_of_bounds(i, arr.length()))
        }
      }
      (Map(m), String(k)) => match m[k] {
        Some(v) => Ok(v)
        None => Err(TemplateError::key_not_found(k))
      }
      _ => Err(TemplateError::type_error("index", self.type_name()))
    }
  }

  /// 属性访问 value.field
  pub fn get_attr(self : Value, field : String) -> Result[Value, TemplateError] {
    match self {
      Map(m) => match m[field] {
        Some(v) => Ok(v)
        None => Err(TemplateError::attribute_not_found(field, "map"))
      }
      _ => Err(TemplateError::type_error("attribute access", self.type_name()))
    }
  }
}

/// 从 MoonBit 原生类型转换为 Value
pub impl From<Bool> for Value {
  from(b : Bool) -> Value { Value::Bool(b) }
}

pub impl From<Int> for Value {
  from(i : Int) -> Value { Value::Int(i.to_int64()) }
}

pub impl From<Int64> for Value {
  from(i : Int64) -> Value { Value::Int(i) }
}

pub impl From<Double> for Value {
  from(i : Double) -> Value { Value::Float(i) }
}

pub impl From<String> for Value {
  from(s : String) -> Value { Value::String(s) }
}
```

### 5.2 Context — 渲染上下文

```moonbit
// src/context.mbt

/// 渲染上下文 — 维护作用域栈和循环状态
pub(all) struct Context {
  scopes : Array[Map[String, Value]]   // 作用域栈，索引 0 为全局作用域
  current_loop : Option[LoopState]     // 当前循环状态
  autoescape : AutoEscapeMode          // 自动转义模式
}

/// 循环状态 — 可在模板中通过 loop 变量访问
pub(all) struct LoopState {
  index : Int        // 当前索引（从 1 开始）
  index0 : Int       // 当前索引（从 0 开始）
  first : Bool       // 是否为第一次迭代
  last : Bool        // 是否为最后一次迭代
  length : Int       // 总长度
}

impl Context {
  /// 创建新的上下文
  pub fn new(autoescape : AutoEscapeMode) -> Context {
    Context::{
      scopes: Array::[],
      current_loop: None,
      autoescape: autoescape,
    }
  }

  /// 创建带顶层数据的上下文
  pub fn from_value(value : Value, autoescape : AutoEscapeMode) -> Context {
    match value {
      Map(m) => Context::new(autoescape).push_scope(m)
      _ => {
        let mut map = Map::new()
        map["self"] = value
        Context::new(autoescape).push_scope(map)
      }
    }
  }

  /// 推入新作用域
  pub fn push_scope(self : Context, scope : Map[String, Value]) -> Context {
    self.scopes.push(scope)
    self
  }

  /// 弹出当前作用域
  pub fn pop_scope(self : Context) -> Context {
    self.scopes.pop()
    self
  }

  /// 在当前作用域设置变量
  pub fn set(self : Context, name : String, value : Value) -> Context {
    if self.scopes.is_empty() {
      self.scopes.push(Map::new())
    }
    let last_idx = self.scopes.length() - 1
    self.scopes[last_idx][name] = value
    self
  }

  /// 查找变量（从内向外遍历作用域栈）
  pub fn get(self : Context, name : String) -> Option[Value] {
    let mut i = self.scopes.length()
    while i > 0 {
      i = i - 1
      match self.scopes[i][name] {
        Some(v) => return Some(v)
        None => continue
      }
    }
    None
  }

  /// 进入循环
  pub fn enter_loop(self : Context, length : Int) -> Context {
    self.current_loop = Some(LoopState::{
      index: 1,
      index0: 0,
      first: true,
      last: length == 1,
      length: length,
    })
    self
  }

  /// 推进循环到下一次迭代
  pub fn advance_loop(self : Context) -> Context {
    match self.current_loop {
      Some(loop) => {
        let next = loop.index + 1
        self.current_loop = Some(LoopState::{
          index: next,
          index0: next - 1,
          first: false,
          last: next == loop.length,
          length: loop.length,
        })
        self
      }
      None => self
    }
  }

  /// 生成 loop 魔法变量的 Map
  pub fn loop_object(self : Context) -> Map[String, Value] {
    match self.current_loop {
      Some(loop) => {
        let mut m = Map::new()
        m["index"] = Value::Int(loop.index.to_int64())
        m["index0"] = Value::Int(loop.index0.to_int64())
        m["first"] = Value::Bool(loop.first)
        m["last"] = Value::Bool(loop.last)
        m["length"] = Value::Int(loop.length.to_int64())
        m
      }
      None => Map::new()
    }
  }
}
```

### 5.3 Template — 已解析的模板

```moonbit
// src/template.mbt

/// 编译后的模板（已解析为 AST）
pub(all) struct Template {
  name : String                    // 模板名称
  ast : Array[Node]                // 顶层 AST 节点列表
  parent : Option<String>          // extends 的父模板名
  blocks : Map[String, BlockNode]  // 模板中定义的所有 block
  macros : Map[String, MacroNode]  // 模板中定义的所有 macro
  source : String                  // 原始源码（用于错误报告）
}

impl Template {
  /// 从源码编译模板
  pub fn compile(name : String, source : String) -> Result[Template, TemplateError] {
    let tokens = lexer::tokenize(source)?
    let (ast, parent, blocks, macros) = parser::parse(tokens)?
    Ok(Template::{ name, ast, parent, blocks, macros, source })
  }
}
```

### 5.4 Environment — 全局配置

```moonbit
// src/environment.mbt

/// 模板引擎全局环境 — 管理模板集合、过滤器、测试器、全局变量
pub(all) struct Environment {
  templates : Map[String, Template]           // 已注册的模板
  filters : Map[String, FilterFn]             // 过滤器注册表
  tests : Map[String, TestFn]                 // 测试器注册表
  globals : Map[String, Value]                // 全局变量
  autoescape : AutoEscapeMode                 // 自动转义模式
  trim_blocks : Bool                          // 是否修剪 block 标签后的换行
  lstrip_blocks : Bool                        // 是否去除 block 标签前的空白
  throw_on_undefined : Bool                   // 未定义变量是否抛出错误
}

/// 自动转义模式
pub(all) enum AutoEscapeMode {
  None            // 不转义
  Html            // 转义 HTML（默认）
  Custom(fn(String) -> String)  // 自定义转义函数
}

/// 过滤器函数签名
pub(all) type FilterFn = (Value, Array[Value]) -> Result[Value, TemplateError]

/// 测试器函数签名
pub(all) type TestFn = (Value, Array[Value]) -> Result[Bool, TemplateError]

impl Environment {
  /// 创建默认环境
  pub fn new() -> Environment {
    let env = Environment::{
      templates: Map::new(),
      filters: Map::new(),
      tests: Map::new(),
      globals: Map::new(),
      autoescape: AutoEscapeMode::Html,
      trim_blocks: true,
      lstrip_blocks: false,
      throw_on_undefined: true,
    }
    // 注册内置过滤器和测试器
    env = filters::register_all(env)
    env = tests::register_all(env)
    env = builtins::register_all(env)
    env
  }

  /// 添加字符串模板
  pub fn add_template(
    self : Environment,
    name : String,
    source : String
  ) -> Result[Environment, TemplateError] {
    let template = Template::compile(name, source)?
    self.templates[name] = template
    Ok(self)
  }

  /// 注册自定义过滤器
  pub fn register_filter(
    self : Environment,
    name : String,
    f : FilterFn
  ) -> Environment {
    self.filters[name] = f
    self
  }

  /// 注册自定义测试器
  pub fn register_test(
    self : Environment,
    name : String,
    t : TestFn
  ) -> Environment {
    self.tests[name] = t
    self
  }

  /// 设置全局变量
  pub fn set_global(
    self : Environment,
    name : String,
    value : Value
  ) -> Environment {
    self.globals[name] = value
    self
  }

  /// 渲染指定模板
  pub fn render(
    self : Environment,
    name : String,
    data : Value
  ) -> Result[String, TemplateError] {
    match self.templates[name] {
      Some(template) => {
        let resolver = TemplateResolver::new(self)
        let resolved = resolver.resolve(template)?   // 处理继承链
        let renderer = Renderer::new(self)
        renderer.render(resolved, data)
      }
      None => Err(TemplateError::template_not_found(name))
    }
  }

  /// 一次性渲染（不缓存模板）
  pub fn render_str(
    self : Environment,
    source : String,
    data : Value
  ) -> Result[String, TemplateError] {
    let template = Template::compile("__inline__", source)?
    let resolver = TemplateResolver::new(self)
    let resolved = resolver.resolve(template)?
    let renderer = Renderer::new(self)
    renderer.render(resolved, data)
  }
}
```

---

## 6. 渲染流程与状态管理

### 6.1 渲染管道

```
Environment.render("page.html", data)
  │
  ├─ 1. 查找模板 "page.html"
  │     └─ 不存在 → TemplateNotFound 错误
  │
  ├─ 2. 模板解析 (Template::compile)
  │     └─ 仅首次，结果缓存
  │
  ├─ 3. 模板继承解析 (TemplateResolver)
  │     ├─ 检测 extends 指令
  │     ├─ 递归加载父模板
  │     ├─ 收集所有 block 定义
  │     └─ 构建最终的 AST（父模板框架 + 子模板 block 覆盖）
  │
  ├─ 4. AST 渲染 (Renderer)
  │     ├─ 创建 Context（作用域栈）
  │     ├─ 遍历 AST 节点
  │     ├─ 递归求值表达式
  │     └─ 输出到 StringBuilder
  │
  └─ 5. 返回渲染结果 String
```

### 6.2 Renderer 实现

```moonbit
// src/renderer.mbt

/// 渲染器 — 遍历 AST 并生成输出
pub(all) struct Renderer {
  env : Environment
}

impl Renderer {
  pub fn new(env : Environment) -> Renderer {
    Renderer::{ env }
  }

  /// 主渲染入口
  pub fn render(
    self : Renderer,
    template : Template,
    data : Value
  ) -> Result[String, TemplateError] {
    let ctx = Context::from_value(data, self.env.autoescape)
    let output = StringBuilder::new()
    self.render_nodes(template.ast, ctx, output)?
    Ok(output.to_string())
  }

  /// 渲染节点列表
  fn render_nodes(
    self : Renderer,
    nodes : Array[Node],
    mut ctx : Context,
    output : StringBuilder
  ) -> Result[Unit, TemplateError] {
    for node in nodes {
      match node {
        Text(t) => {
          output.write_string(t.content)
        }
        Variable(v) => {
          let val = self.eval_expr(v.expr, ctx)?
          let filtered = self.apply_filters(val, v.filters)?
          let escaped = self.maybe_escape(filtered, ctx)?
          output.write_string(escaped.to_string())
        }
        If(if_node) => {
          self.render_if(if_node, ctx, output)?
        }
        For(for_node) => {
          self.render_for(for_node, ctx, output)?
        }
        Block(block) => {
          // Block 在继承解析阶段处理，这里直接渲染 body
          self.render_nodes(block.body, ctx, output)?
        }
        Include(inc) => {
          self.render_include(inc, ctx, output)?
        }
        Set(set_node) => {
          match set_node.body {
            Some(body) => {
              let mut inner = StringBuilder::new()
              self.render_nodes(body, ctx, &mut inner)?
              ctx = ctx.set(set_node.name, Value::String(inner.to_string()))
            }
            None => {
              let val = self.eval_expr(set_node.value, ctx)?
              ctx = ctx.set(set_node.name, val)
            }
          }
        }
        Macro(_) => {
          // Macro 定义不产生输出，已在解析阶段注册
          continue
        }
        Call(call) => {
          self.render_call(call, ctx, output)?
        }
        FilterBlock(fb) => {
          self.render_filter_block(fb, ctx, output)?
        }
        Comment => {
          // 注释不产生输出
          continue
        }
        Raw(r) => {
          output.write_string(r.content)
        }
        Extends(_) => {
          // extends 在继承解析阶段已处理
          continue
        }
      }
    }
    Ok(())
  }

  /// 渲染条件分支
  fn render_if(
    self : Renderer,
    if_node : IfNode,
    mut ctx : Context,
    output : StringBuilder
  ) -> Result[Unit, TemplateError] {
    for (cond, body) in if_node.branches {
      let result = self.eval_expr(cond, ctx)?
      if result.is_truthy() {
        ctx = ctx.push_scope(Map::new())  // if 分支引入新作用域
        self.render_nodes(body, ctx, output)?
        ctx = ctx.pop_scope()
        return Ok(())
      }
    }
    // 没有任何条件满足，渲染 else 分支
    if if_node.else_body.length() > 0 {
      ctx = ctx.push_scope(Map::new())
      self.render_nodes(if_node.else_body, ctx, output)?
      ctx = ctx.pop_scope()
    }
    Ok(())
  }

  /// 渲染循环
  fn render_for(
    self : Renderer,
    for_node : ForNode,
    mut ctx : Context,
    output : StringBuilder
  ) -> Result[Unit, TemplateError] {
    let iterable = self.eval_expr(for_node.iterable, ctx)?
    match iterable {
      Array(items) => {
        if items.is_empty() {
          // 渲染 else 分支
          if for_node.else_body.length() > 0 {
            ctx = ctx.push_scope(Map::new())
            self.render_nodes(for_node.else_body, ctx, output)?
            ctx = ctx.pop_scope()
          }
          return Ok(())
        }
        ctx = ctx.enter_loop(items.length())
        for i = 0; i < items.length(); i = i + 1 {
          let mut loop_scope = ctx.loop_object()
          match for_node.key {
            Some(key_var) => loop_scope[key_var] = Value::Int(i.to_int64())
            None => {}
          }
          loop_scope[for_node.value] = items[i]
          ctx = ctx.push_scope(loop_scope)
          self.render_nodes(for_node.body, ctx, output)?
          ctx = ctx.pop_scope()
          ctx = ctx.advance_loop()
        }
        ctx.current_loop = None
      }
      Map(m) => {
        // 遍历 map 的 key-value
        if m.size() == 0 {
          if for_node.else_body.length() > 0 {
            ctx = ctx.push_scope(Map::new())
            self.render_nodes(for_node.else_body, ctx, output)?
            ctx = ctx.pop_scope()
          }
          return Ok(())
        }
        let keys = m.keys()
        ctx = ctx.enter_loop(keys.length())
        for i = 0; i < keys.length(); i = i + 1 {
          let mut loop_scope = ctx.loop_object()
          let k = keys[i]
          match for_node.key {
            Some(key_var) => loop_scope[key_var] = Value::String(k)
            None => {}
          }
          loop_scope[for_node.value] = m[k].unwrap()
          ctx = ctx.push_scope(loop_scope)
          self.render_nodes(for_node.body, ctx, output)?
          ctx = ctx.pop_scope()
          ctx = ctx.advance_loop()
        }
        ctx.current_loop = None
      }
      String(s) => {
        // 字符串也可以迭代（按字符）
        // ... 类似处理
      }
      _ => return Err(TemplateError::type_error("iterable", iterable.type_name()))
    }
    Ok(())
  }
}
```

### 6.3 渲染状态转换图

```
                    ┌──────────┐
                    │  IDLE    │
                    └─────┬────┘
                          │ render() 调用
                          ▼
                    ┌──────────┐
                    │ RESOLVE  │  处理 extends/inheritance
                    └─────┬────┘
                          │
                          ▼
                    ┌──────────┐
               ┌───▶│  RENDER  │  遍历 AST
               │    └─────┬────┘
               │          │
               │          ├── Text      → 直接输出
               │          ├── Variable  → 求值 → 过滤器 → 转义 → 输出
               │          ├── If        → 求值条件 → 递归渲染分支
               │          ├── For       → 展开循环 → 递归渲染 body
               │          ├── Include   → 加载子模板 → 递归渲染
               │          ├── Block     → 选择最具体实现 → 递归渲染
               │          ├── Macro     → 注册到 context（不产生输出）
               │          ├── Call      → 查找 macro → 渲染宏体
               │          ├── Set       → 求值 → 写入 context
               │          └── FilterBlock → 渲染 body → 应用过滤器
               │          │
               │          ▼
               │    ┌──────────┐
               └────┤  NODE    │  移动到下一个节点
                    └─────┬────┘
                          │ AST 遍历完成
                          ▼
                    ┌──────────┐
                    │  DONE    │  返回 String
                    └──────────┘
```

---

## 7. 错误处理设计

### 7.1 错误类型定义

```moonbit
// src/errors.mbt

/// 模板引擎所有错误的统一类型
pub(all) enum TemplateError {
  // 解析阶段错误
  ParseError {
    msg : String
    pos : SourcePos
  }
  UnexpectedToken {
    expected : String
    got : String
    pos : SourcePos
  }
  UnclosedTag {
    tag : String       // "if", "for", "block" 等
    opened_at : SourcePos
  }

  // 模板管理错误
  TemplateNotFound(String)
  CircularExtends(String, Array[String])  // 模板名, 继承链

  // 渲染阶段错误
  UndefinedVariable {
    name : String
    pos : SourcePos
  }
  UndefinedFilter {
    name : String
    pos : SourcePos
  }
  UndefinedTest {
    name : String
    pos : SourcePos
  }
  UndefinedMacro {
    name : String
    pos : SourcePos
  }
  TypeError {
    expected : String
    got : String
    pos : SourcePos
  }
  IndexOutOfBounds {
    index : Int64
    length : Int
    pos : SourcePos
  }
  KeyNotFound {
    key : String
    pos : SourcePos
  }
  FilterError {
    filter_name : String
    msg : String
    pos : SourcePos
  }
  RenderError {
    msg : String
    pos : SourcePos
  }

  // 继承相关错误
  InheritanceError {
    msg : String
    pos : Option[SourcePos]
  }
  BlockNotFound {
    block_name : String
    template_name : String
  }

  // IO 错误（读取模板文件时）
  IoError(String)
}

/// 为 TemplateError 实现 Show trait，提供友好的错误消息
impl Show for TemplateError with output(self : TemplateError, logger : &Logger) -> Unit {
  match self {
    ParseError(msg, pos) =>
      logger.write_string("Parse error at line \{pos.line}, col \{pos.col}: \{msg}")
    UndefinedVariable(name, pos) =>
      logger.write_string(
        "Variable `\{name}` is undefined at line \{pos.line}, col \{pos.col}"
      )
    TemplateNotFound(name) =>
      logger.write_string("Template `\{name}` not found")
    // ... 其余分支
  }
}

/// 辅助构造函数，减少模板代码
impl TemplateError {
  pub fn parse_error(msg : String, pos : SourcePos) -> TemplateError {
    TemplateError::ParseError({ msg, pos })
  }

  pub fn undefined_variable(name : String, pos : SourcePos) -> TemplateError {
    TemplateError::UndefinedVariable({ name, pos })
  }

  pub fn type_error(expected : String, got : String) -> TemplateError {
    TemplateError::TypeError({
      expected,
      got,
      pos: SourcePos::{ line: 0, col: 0, len: 0 },
    })
  }
}
```

### 7.2 错误处理策略

| 错误类别 | 处理策略 | 示例 |
|----------|----------|------|
| 解析错误 | 立即失败，返回 `Err` | 未闭合的 `{% if %}` |
| 变量未定义 | 默认抛出错误；可配置为返回空字符串 | `{{ undefined_var }}` |
| 过滤器未定义 | 抛出错误 | `{{ x | unknown_filter }}` |
| 类型错误 | 抛出错误 | 对字符串做 `+` |
| 模板未找到 | 抛出错误 | `{% extends "missing.html" %}` |
| 循环继承 | 解析阶段检测并拒绝 | A extends B extends C extends A |

---

## 8. 模板继承机制

### 8.1 继承解析流程

```moonbit
// src/inheritance.mbt

/// 模板继承解析器
pub(all) struct TemplateResolver {
  env : Environment
}

impl TemplateResolver {
  pub fn new(env : Environment) -> TemplateResolver {
    TemplateResolver::{ env }
  }

  /// 解析模板继承链，返回最终的完整 AST
  ///
  /// 算法：
  /// 1. 如果模板没有 extends，直接返回模板的 AST
  /// 2. 如果模板有 extends "parent"，递归解析父模板
  /// 3. 将子模板的 block 定义替换到父模板的对应位置
  /// 4. 对于父模板中的每个 block：
  ///    - 如果子模板定义了同名 block → 使用子模板的定义
  ///    - 如果父模板 block 内有 {{ super() }} → 渲染时替换为父模板 block 的内容
  ///    - 否则使用父模板的默认内容
  pub fn resolve(
    self : TemplateResolver,
    template : Template
  ) -> Result[Template, TemplateError] {
    match template.parent {
      None => Ok(template)
      Some(parent_name) => {
        // 循环继承检测
        if template.name == parent_name {
          return Err(TemplateError::circular_extends(
            template.name,
            Array::[template.name, parent_name],
          ))
        }
        match self.env.templates[parent_name] {
          None => Err(TemplateError::template_not_found(parent_name))
          Some(parent_template) => {
            let resolved_parent = self.resolve(parent_template)?
            // 将子模板的 block 合并到父模板的 AST 中
            let merged = self.merge_blocks(
              resolved_parent.ast,
              template.blocks,
              resolved_parent.blocks,
            )
            Ok(Template::{
              name: template.name,
              ast: merged,
              parent: resolved_parent.parent,
              blocks: template.blocks,    // 保持子模板的 block 定义
              macros: template.macros,
              source: template.source,
            })
          }
        }
      }
    }
  }

  /// 递归将子模板的 block 替换到 AST 中
  fn merge_blocks(
    self : TemplateResolver,
    ast : Array[Node],
    child_blocks : Map[String, BlockNode],
    parent_blocks : Map[String, BlockNode],
  ) -> Array[Node] {
    let mut result = Array::new()
    for node in ast {
      match node {
        Block(block) => {
          // 子模板中定义的同名 block 替换父模板的
          let final_block = match child_blocks[block.name] {
            Some(child_block) => {
              // 将 {{ super() }} 替换为父模板 block 的内容
              self.inject_super(child_block.body, block.body)
            }
            None => block
          }
          result.push(Block(final_block))
        }
        _ => result.push(node)
      }
    }
    result
  }

  /// 将子模板 block 中的 {{ super() }} 替换为父模板 block 的内容
  fn inject_super(
    self : TemplateResolver,
    child_body : Array[Node],
    parent_body : Array[Node],
  ) -> Array[Node] {
    let mut result = Array::new()
    for node in child_body {
      match node {
        Variable(v) => match v.expr {
          Expr::Super => result.append(parent_body)
          _ => result.push(node)
        }
        // 递归处理嵌套节点
        If(if_node) => {
          // ... 递归处理 if 分支中的 super()
        }
        For(for_node) => {
          // ... 递归处理 for 循环体中的 super()
        }
        _ => result.push(node)
      }
    }
    result
  }
}
```

### 8.2 继承示例

**base.html:**
```html
<html>
<head><title>{% block title %}默认标题{% endblock %}</title></head>
<body>
  {% block nav %}<nav>导航栏</nav>{% endblock %}
  <main>{% block content %}{% endblock %}</main>
  <footer>{% block footer %}© 2026{% endblock %}</footer>
</body>
</html>
```

**page.html:**
```html
{% extends "base.html" %}
{% block title %}关于我们{% endblock %}
{% block content %}
  <h1>{{ company.name }}</h1>
  <p>{{ company.description }}</p>
{% endblock %}
{% block footer %}
  {{ super() }} — 保留所有权利
{% endblock %}
```

**最终渲染结果:**
```html
<html>
<head><title>关于我们</title></head>
<body>
  <nav>导航栏</nav>
  <main><h1>Acme Corp</h1><p>我们是最棒的</p></main>
  <footer>© 2026 — 保留所有权利</footer>
</body>
</html>
```

---

## 9. 过滤器系统

### 9.1 内置过滤器

```moonbit
// src/filters.mbt

/// 注册所有内置过滤器到 Environment
pub fn register_all(env : Environment) -> Environment {
  env
    .register_filter("upper", filter_upper)
    .register_filter("lower", filter_lower)
    .register_filter("trim", filter_trim)
    .register_filter("capitalize", filter_capitalize)
    .register_filter("title", filter_title)
    .register_filter("replace", filter_replace)
    .register_filter("length", filter_length)
    .register_filter("reverse", filter_reverse)
    .register_filter("sort", filter_sort)
    .register_filter("unique", filter_unique)
    .register_filter("first", filter_first)
    .register_filter("last", filter_last)
    .register_filter("slice", filter_slice)
    .register_filter("join", filter_join)
    .register_filter("default", filter_default)
    .register_filter("abs", filter_abs)
    .register_filter("round", filter_round)
    .register_filter("int", filter_int)
    .register_filter("float", filter_float)
    .register_filter("json_encode", filter_json_encode)
    .register_filter("urlencode", filter_urlencode)
    .register_filter("escape", filter_escape)
    .register_filter("safe", filter_safe)
    .register_filter("split", filter_split)
    .register_filter("range", filter_range)
    .register_filter("indent", filter_indent)
    .register_filter("linebreaksbr", filter_linebreaksbr)
    .register_filter("striptags", filter_striptags)
    .register_filter("truncate", filter_truncate)
    .register_filter("wordcount", filter_wordcount)
}

/// {{ value | upper }}
fn filter_upper(value : Value, args : Array[Value]) -> Result[Value, TemplateError] {
  match value {
    String(s) => Ok(Value::String(s.to_upper()))
    _ => Err(TemplateError::type_error("string for upper", value.type_name()))
  }
}

/// {{ value | lower }}
fn filter_lower(value : Value, args : Array[Value]) -> Result[Value, TemplateError] {
  match value {
    String(s) => Ok(Value::String(s.to_lower()))
    _ => Err(TemplateError::type_error("string for lower", value.type_name()))
  }
}

/// {{ value | trim }}
fn filter_trim(value : Value, args : Array[Value]) -> Result[Value, TemplateError] {
  match value {
    String(s) => Ok(Value::String(s.trim()))
    _ => Err(TemplateError::type_error("string for trim", value.type_name()))
  }
}

/// {{ value | default("fallback") }}
fn filter_default(value : Value, args : Array[Value]) -> Result[Value, TemplateError] {
  if value.is_truthy() {
    Ok(value)
  } else {
    match args.length() {
      0 => Ok(Value::String(""))
      _ => Ok(args[0])
    }
  }
}

/// {{ items | length }}
fn filter_length(value : Value, args : Array[Value]) -> Result[Value, TemplateError] {
  match value {
    Array(a) => Ok(Value::Int(a.length().to_int64()))
    Map(m) => Ok(Value::Int(m.size().to_int64()))
    String(s) => Ok(Value::Int(s.length().to_int64()))
    _ => Err(TemplateError::type_error("array/map/string for length", value.type_name()))
  }
}

/// {{ items | join(", ") }}
fn filter_join(value : Value, args : Array[Value]) -> Result[Value, TemplateError] {
  match value {
    Array(a) => {
      let sep = match args.length() {
        0 => ""
        _ => args[0].to_string()
      }
      let parts = Array::new(a.length())
      for item in a {
        parts.push(item.to_string())
      }
      Ok(Value::String(parts.join(sep)))
    }
    _ => Err(TemplateError::type_error("array for join", value.type_name()))
  }
}

/// {{ value | escape }} — HTML 转义
fn filter_escape(value : Value, args : Array[Value]) -> Result[Value, TemplateError] {
  match value {
    String(s) => Ok(Value::SafeHtml(autoescape::escape_html(s)))
    SafeHtml(_) => Ok(value)  // 已转义的不再转义
    _ => Ok(Value::SafeHtml(autoescape::escape_html(value.to_string())))
  }
}

/// {{ html | safe }} — 标记为安全 HTML，跳过自动转义
fn filter_safe(value : Value, args : Array[Value]) -> Result[Value, TemplateError] {
  match value {
    String(s) => Ok(Value::SafeHtml(s))
    SafeHtml(_) => Ok(value)
    _ => Ok(Value::SafeHtml(value.to_string()))
  }
}
```

### 9.2 自定义过滤器注册

```moonbit
// 用户自定义过滤器示例
fn my_custom_filter(value : Value, args : Array[Value]) -> Result[Value, TemplateError] {
  match value {
    String(s) => Ok(Value::String(s.reverse()))
    _ => Err(TemplateError::type_error("string", value.type_name()))
  }
}

let env = Environment::new()
  .register_filter("reverse_str", my_custom_filter)
  .add_template("test", "Hello {{ name | reverse_str }}")?
```

---

## 10. 表达式求值引擎

### 10.1 Pratt 解析器架构

```moonbit
// src/parser_expr.mbt

/// Pratt 解析器 — 处理中缀/前缀表达式
struct ExprParser {
  tokens : Array[TokenWithPos]
  pos : Int          // 当前位置
}

/// 运算符优先级（绑定力）定义
fn prefix_bp(token : Token) -> Option[Int] {
  match token {
    Not => Some(55)
    Minus => Some(55)
    Plus => Some(55)      // 正号
    _ => None
  }
}

fn infix_bp(token : Token) -> Option<(Int, Int)> {
  // 返回 (左绑定力, 右绑定力)
  match token {
    Or => Some((10, 11))
    And => Some((20, 21))
    EqEq | Ne => Some((30, 31))
    Lt | Le | Gt | Ge => Some((30, 31))
    In => Some((30, 31))
    KwIs => Some((30, 31))
    Tilde => Some((40, 41))
    Plus | Minus => Some((45, 46))
    Star | Slash | Percent => Some((50, 51))
    Pipe => Some((5, 6))      // 过滤器管道
    Dot | LBracket => Some((70, 71))
    _ => None
  }
}

impl ExprParser {
  /// 入口：解析表达式
  fn parse_expr(self : ExprParser, min_bp : Int) -> Result[Expr, TemplateError] {
    // 1. 解析前缀（操作数）
    let mut lhs = self.parse_prefix()?

    // 2. 循环处理中缀运算符
    while self.pos < self.tokens.length() {
      let token = self.tokens[self.pos].token
      match infix_bp(token) {
        Some((lbp, rbp)) => {
          if lbp < min_bp {
            break
          }
          self.pos = self.pos + 1  // 消费运算符
          let rhs = self.parse_expr(rbp)?
          lhs = match token {
            Plus => Expr::Binary(Box::new(lhs), BinaryOp::Add, Box::new(rhs))
            Minus => Expr::Binary(Box::new(lhs), BinaryOp::Sub, Box::new(rhs))
            Star => Expr::Binary(Box::new(lhs), BinaryOp::Mul, Box::new(rhs))
            Slash => Expr::Binary(Box::new(lhs), BinaryOp::Div, Box::new(rhs))
            EqEq => Expr::Binary(Box::new(lhs), BinaryOp::Eq, Box::new(rhs))
            Ne => Expr::Binary(Box::new(lhs), BinaryOp::Ne, Box::new(rhs))
            And => Expr::Binary(Box::new(lhs), BinaryOp::And, Box::new(rhs))
            Or => Expr::Binary(Box::new(lhs), BinaryOp::Or, Box::new(rhs))
            Dot => match rhs {
              Ident(name) => Expr::Dot(Box::new(lhs), name)
              _ => return Err(TemplateError::parse_error(
                "Expected identifier after `.`",
                self.current_pos(),
              ))
            }
            Pipe => {
              // 管道操作符：expr | filter_name(args)
              self.parse_filter_chain(lhs)?
            }
            _ => lhs
          }
        }
        None => break
      }
    }
    Ok(lhs)
  }
}
```

### 10.2 表达式求值

```moonbit
// src/renderer_expr.mbt

impl Renderer {
  /// 求值表达式，返回 Value
  pub fn eval_expr(
    self : Renderer,
    expr : Expr,
    ctx : Context
  ) -> Result[Value, TemplateError] {
    match expr {
      // 字面量
      Expr::StringLit(s) => Ok(Value::String(s))
      Expr::IntLit(i) => Ok(Value::Int(i))
      Expr::FloatLit(f) => Ok(Value::Float(f))
      Expr::BoolLit(b) => Ok(Value::Bool(b))
      Expr::Null => Ok(Value::Null)
      Expr::ArrayLit(items) => {
        let mut arr = Array::new(items.length())
        for item in items {
          arr.push(self.eval_expr(item, ctx)?)
        }
        Ok(Value::Array(arr))
      }
      Expr::DictLit(pairs) => {
        let mut m = Map::new()
        for (k, v) in pairs {
          m[k] = self.eval_expr(v, ctx)?
        }
        Ok(Value::Map(m))
      }

      // 变量查找
      Expr::Ident(name) => match ctx.get(name) {
        Some(v) => Ok(v)
        None => match self.env.globals[name] {
          Some(v) => Ok(v)
          None => {
            if self.env.throw_on_undefined {
              Err(TemplateError::undefined_variable(name, SourcePos::unknown()))
            } else {
              Ok(Value::String(""))
            }
          }
        }
      }

      // 成员访问
      Expr::Dot(obj, field) => {
        let val = self.eval_expr(obj.0, ctx)?
        val.get_attr(field)
      }
      Expr::Index(obj, idx) => {
        let container = self.eval_expr(obj.0, ctx)?
        let index = self.eval_expr(idx.0, ctx)?
        container.index(index)
      }

      // 一元运算
      Expr::Unary(op, operand) => {
        let val = self.eval_expr(operand.0, ctx)?
        match op {
          UnaryOp::Not => Ok(Value::Bool(!val.is_truthy()))
          UnaryOp::Neg => match val {
            Int(i) => Ok(Value::Int(-i))
            Float(f) => Ok(Value::Float(-f))
            _ => Err(TemplateError::type_error("number for negation", val.type_name()))
          }
        }
      }

      // 二元运算
      Expr::Binary(lhs_expr, op, rhs_expr) => {
        let lhs = self.eval_expr(lhs_expr.0, ctx)?
        let rhs = self.eval_expr(rhs_expr.0, ctx)?
        self.eval_binary(lhs, op, rhs)
      }

      // 测试: x is defined
      Expr::Test(operand, test_name, args) => {
        let val = self.eval_expr(operand.0, ctx)?
        match self.env.tests[test_name] {
          Some(test_fn) => {
            let eval_args = Array::new(args.length())
            for a in args {
              eval_args.push(self.eval_expr(a, ctx)?)
            }
            match test_fn(val, eval_args) {
              Ok(b) => Ok(Value::Bool(b))
              Err(e) => Err(e)
            }
          }
          None => Err(TemplateError::undefined_test(test_name, SourcePos::unknown()))
        }
      }

      // 函数调用: range(0, 10)
      Expr::Call(func_name, args) => {
        let eval_args = Array::new(args.length())
        for a in args {
          eval_args.push(self.eval_expr(a, ctx)?)
        }
        self.call_builtin(func_name, eval_args)
      }

      // 三元: a if cond else b
      Expr::Ternary(cond_expr, then_expr, else_expr) => {
        let cond = self.eval_expr(cond_expr.0, ctx)?
        if cond.is_truthy() {
          self.eval_expr(then_expr.0, ctx)
        } else {
          self.eval_expr(else_expr.0, ctx)
        }
      }

      Expr::Super => {
        // super() 在继承解析阶段已处理，不应到达这里
        Ok(Value::String(""))
      }

      Expr::Concat(parts) => {
        let mut result = ""
        for p in parts {
          let v = self.eval_expr(p, ctx)?
          result = result + v.to_string()
        }
        Ok(Value::String(result))
      }
    }
  }

  /// 二元运算求值
  fn eval_binary(
    self : Renderer,
    lhs : Value,
    op : BinaryOp,
    rhs : Value,
  ) -> Result[Value, TemplateError] {
    match op {
      // 算术
      BinaryOp::Add => eval_arithmetic(lhs, rhs, |a, b| a + b, |a, b| a + b)
      BinaryOp::Sub => eval_arithmetic(lhs, rhs, |a, b| a - b, |a, b| a - b)
      BinaryOp::Mul => eval_arithmetic(lhs, rhs, |a, b| a * b, |a, b| a * b)
      BinaryOp::Div => eval_arithmetic(lhs, rhs, |a, b| a / b, |a, b| a / b)
      BinaryOp::Mod => eval_arithmetic(lhs, rhs, |a, b| a % b, |a, b| a % b)

      // 比较
      BinaryOp::Eq => Ok(Value::Bool(lhs == rhs))
      BinaryOp::Ne => Ok(Value::Bool(lhs != rhs))
      BinaryOp::Lt => eval_compare(lhs, rhs, |a, b| a < b)
      BinaryOp::Le => eval_compare(lhs, rhs, |a, b| a <= b)
      BinaryOp::Gt => eval_compare(lhs, rhs, |a, b| a > b)
      BinaryOp::Ge => eval_compare(lhs, rhs, |a, b| a >= b)

      // 逻辑
      BinaryOp::And => Ok(Value::Bool(lhs.is_truthy() && rhs.is_truthy()))
      BinaryOp::Or => Ok(Value::Bool(lhs.is_truthy() || rhs.is_truthy()))

      // 拼接
      BinaryOp::Concat => Ok(Value::String(lhs.to_string() + rhs.to_string()))

      // 包含
      BinaryOp::In => self.eval_in(lhs, rhs)
    }
  }
}
```

---

## 11. API 设计

### 11.1 公共 API

```moonbit
// src/lib.mbt

/// MoonBit 模板渲染引擎
///
/// # 快速开始
///
/// ```
/// let env = Environment::new()
///   .add_template("hello", "Hello, {{ name }}!")?
///
/// let mut data = Map::new()
/// data["name"] = Value::String("World")
///
/// let result = env.render("hello", Value::Map(data))?
/// assert_eq!(result, "Hello, World!")
/// ```
///
/// # 一次性渲染
///
/// ```
/// let result = Environment::new()
///   .render_str("{{ x + y }}", Value::Map({x: 1, y: 2}))?
/// assert_eq!(result, "3")
/// ```

// ---------------------------------------------------------------------------
// 公共类型重导出
// ---------------------------------------------------------------------------
pub use environment::{ Environment, AutoEscapeMode }
pub use template::{ Template }
pub use context::{ Context, LoopState }
pub use value::{ Value }
pub use errors::{ TemplateError }
pub use ast::{
  Node, Expr, BinaryOp, UnaryOp,
  TextNode, VariableNode, BlockNode, IfNode, ForNode,
  IncludeNode, ExtendsNode, SetNode, MacroNode, MacroArg,
  CallNode, FilterBlockNode, RawNode, FilterCall,
  SourcePos,
}
pub use filters::{ register_all as register_all_filters }

/// 版本信息
pub const VERSION : String = "0.1.0"

/// 快速渲染 — 最简 API
pub fn render(
  source : String,
  data : Value
) -> Result[String, TemplateError] {
  Environment::new().render_str(source, data)
}
```

### 11.2 典型使用场景

```moonbit
// 场景 1: 从字符串模板渲染
fn example_basic() -> Result[Unit, TemplateError] {
  let env = Environment::new()

  // 注册模板
  let env = env.add_template("welcome", r#"
    <h1>欢迎, {{ user.name | upper }}!</h1>
    <ul>
    {% for item in user.items %}
      <li>{{ loop.index }}. {{ item | escape }}</li>
    {% endfor %}
    </ul>
  "#)?

  // 准备数据
  let mut user = Map::new()
  user["name"] = Value::String("张三")
  user["items"] = Value::Array([
    Value::String("苹果"),
    Value::String("香蕉"),
    Value::String("橘子"),
  ])

  let mut data = Map::new()
  data["user"] = Value::Map(user)

  // 渲染
  let result = env.render("welcome", Value::Map(data))?
  println(result)
  Ok(())
}

// 场景 2: 模板继承
fn example_inheritance() -> Result[Unit, TemplateError] {
  let env = Environment::new()
    .add_template("layout", r#"
      <html>
      <head><title>{% block title %}默认{% endblock %}</title></head>
      <body>{% block body %}{% endblock %}</body>
      </html>
    "#)?
    .add_template("page", r#"
      {% extends "layout" %}
      {% block title %}我的页面{% endblock %}
      {% block body %}<p>Hello!</p>{% endblock %}
    "#)?

  env.render("page", Value::Map(Map::new()))
}

// 场景 3: 自定义过滤器
fn example_custom_filter() -> Result[Unit, TemplateError] {
  let env = Environment::new()
    .register_filter("greet", fn(value, _args) {
      match value {
        Value::String(s) => Ok(Value::String("你好, " + s + "!"))
        _ => Err(TemplateError::type_error("string", value.type_name()))
      }
    })
    .add_template("t", "{{ name | greet }}")?

  let mut data = Map::new()
  data["name"] = Value::String("世界")

  env.render("t", Value::Map(data))
}
```

---

## 12. 测试策略

### 12.1 测试分层

```
test/
├── lexer_test.mbt           # 词法分析器单元测试
├── parser_test.mbt          # 语法分析器单元测试
├── expression_test.mbt      # 表达式求值测试
├── renderer_test.mbt        # 渲染器测试
├── filter_test.mbt          # 内置过滤器测试
├── inheritance_test.mbt     # 模板继承测试
├── error_test.mbt           # 错误处理测试
├── autoescape_test.mbt      # 自动转义测试
├── context_test.mbt         # 上下文管理测试
└── integration_test.mbt     # 集成测试（端到端场景）
```

### 12.2 测试用例示例

```moonbit
// test/lexer_test.mbt

test "lexer: simple text" {
  let result = lexer::tokenize("Hello, World!")?
  assert_eq!(result.length(), 2)  // RawText + Eof
}

test "lexer: variable interpolation" {
  let result = lexer::tokenize("{{ name }}")?
  inspect!(result, content="lexer_variable")
}

test "lexer: block tags" {
  let result = lexer::tokenize("{% if x %}{% endif %}")?
  assert_eq!(result.length(), > 2)
}

// test/parser_test.mbt

test "parser: simple variable" {
  let tokens = lexer::tokenize("{{ user.name }}")?
  let (ast, _, _, _) = parser::parse(tokens)?
  match ast[0] {
    Variable(v) => match v.expr {
      Dot(ident, field) => {
        // ...
      }
      _ => assert!(false, "expected dot expression")
    }
    _ => assert!(false, "expected variable node")
  }
}

test "parser: if elif else" {
  let tokens = lexer::tokenize(
    "{% if a %}A{% elif b %}B{% else %}C{% endif %}"
  )?
  let (ast, _, _, _) = parser::parse(tokens)?
  match ast[0] {
    If(if_node) => {
      assert_eq!(if_node.branches.length(), 2)
      assert_eq!(if_node.else_body.length(), > 0)
    }
    _ => assert!(false)
  }
}

// test/renderer_test.mbt

test "render: variable substitution" {
  let result = render("{{ name }}", Value::Map({name: "World"}))?
  assert_eq!(result, "World")
}

test "render: if statement true branch" {
  let result = render(
    "{% if show %}visible{% endif %}",
    Value::Map({show: true})
  )?
  assert_eq!(result, "visible")
}

test "render: if statement false branch" {
  let result = render(
    "{% if show %}visible{% endif %}",
    Value::Map({show: false})
  )?
  assert_eq!(result, "")
}

test "render: for loop" {
  let result = render(
    "{% for x in items %}{{ x }},{% endfor %}",
    Value::Map({items: [1, 2, 3]})
  )?
  assert_eq!(result, "1,2,3,")
}

test "render: loop.index" {
  let result = render(
    "{% for x in items %}{{ loop.index }}:{{ x }} {% endfor %}",
    Value::Map({items: ["a", "b"]})
  )?
  assert_eq!(result, "1:a 2:b ")
}

test "render: filters chain" {
  let result = render(
    "{{ name | upper | trim }}",
    Value::Map({name: "  hello  "})
  )?
  assert_eq!(result, "HELLO")
}

test "render: undefined variable throws" {
  let result = render("{{ missing }}", Value::Map(Map::new()))
  assert!(result.is_err())
}

// test/inheritance_test.mbt

test "inheritance: basic extends" {
  let env = Environment::new()
    .add_template("base", "X{% block a %}A{% endblock %}Y")?
    .add_template("child",
      "{% extends \"base\" %}{% block a %}B{% endblock %}"
    )?
  let result = env.render("child", Value::Map(Map::new()))?
  assert_eq!(result, "XBY")
}

test "inheritance: super()" {
  let env = Environment::new()
    .add_template("base", "{% block a %}A{% endblock %}")?
    .add_template("child",
      "{% extends \"base\" %}{% block a %}{{ super() }}+B{% endblock %}"
    )?
  let result = env.render("child", Value::Map(Map::new()))?
  assert_eq!(result, "A+B")
}

// test/error_test.mbt

test "error: template not found" {
  let env = Environment::new()
  let result = env.render("nonexistent", Value::Map(Map::new()))
  match result {
    Err(TemplateError::TemplateNotFound(name)) =>
      assert_eq!(name, "nonexistent")
    _ => assert!(false, "expected TemplateNotFound")
  }
}
```

---

## 13. 文件结构

### 13.1 目录布局

```
moonbit-template/
├── moon.mod.json               # MoonBit 项目清单
├── moon.pkg.json               # 包配置
├── README.md                   # 用户文档
├── DESIGN.md                   # 本设计文档
├── CHANGELOG.md                # 变更日志
├── src/
│   ├── moon.pkg.json
│   ├── lib.mbt                 # 公共 API 入口
│   ├── template.mbt            # Template 结构体
│   ├── environment.mbt         # Environment 配置
│   ├── ast.mbt                 # AST 节点类型
│   ├── lexer.mbt               # 词法分析器
│   ├── parser.mbt              # 语法分析器入口
│   ├── parser_core.mbt         # 核心解析逻辑
│   ├── parser_expr.mbt         # 表达式 Pratt 解析器
│   ├── parser_tags.mbt         # 标签解析器
│   ├── renderer.mbt            # 渲染器入口
│   ├── renderer_core.mbt       # 核心渲染逻辑
│   ├── renderer_expr.mbt       # 表达式求值
│   ├── value.mbt               # Value 运行时类型
│   ├── context.mbt             # 渲染上下文
│   ├── filters.mbt             # 内置过滤器
│   ├── tests.mbt               # 内置测试器
│   ├── errors.mbt              # 错误类型
│   ├── inheritance.mbt         # 模板继承
│   ├── autoescape.mbt          # HTML 转义
│   ├── source.mbt              # 源码位置
│   └── builtins.mbt            # 全局函数
├── test/
│   ├── moon.pkg.json
│   ├── lexer_test.mbt
│   ├── parser_test.mbt
│   ├── expression_test.mbt
│   ├── renderer_test.mbt
│   ├── filter_test.mbt
│   ├── inheritance_test.mbt
│   ├── error_test.mbt
│   ├── autoescape_test.mbt
│   ├── context_test.mbt
│   └── integration_test.mbt
├── examples/
│   ├── hello.mbt               # 最小示例
│   ├── blog.mbt                # 博客渲染示例
│   └── inheritance.mbt         # 模板继承示例
└── benchmarks/
    └── bench.mbt               # 性能基准测试
```

### 13.2 moon.mod.json

```json
{
  "name": "linzeming/template",
  "version": "0.1.0",
  "readme": "README.md",
  "repository": "",
  "license": "MIT",
  "keywords": ["template", "templating", "jinja2", "tera", "html"],
  "description": "A Jinja2/Tera-inspired template engine for MoonBit",
  "source": "src",
  "deps": {
    "moonbitlang/core": "latest"
  }
}
```

---

## 附录 A: 与 Tera/Jinja2 的对照表

| 特性 | Jinja2 | Tera | 本引擎 |
|------|--------|------|--------|
| 变量插值 | `{{ var }}` | `{{ var }}` | `{{ var }}` |
| 语句块 | `{% %}` | `{% %}` | `{% %}` |
| 注释 | `{# #}` | `{# #}` | `{# #}` |
| 过滤器 | `\|` | `\|` | `\|` |
| 条件 | `if/elif/else` | `if/elif/else` | `if/elif/else` |
| 循环 | `for in` | `for in` | `for in` |
| 变量赋值 | `{% set %}` | `{% set %}` | `{% set %}` |
| 模板继承 | `extends/block` | `extends/block` | `extends/block` |
| Include | `include` | `include` | `include` |
| Macro | `macro` | `macro` | `macro` |
| super() | ✅ | ✅ | ✅ |
| 循环 else | ✅ | ❌ | ✅ |
| 测试器 (is) | ✅ | ✅ | ✅ |
| 三元表达式 | ✅ | ✅ | ✅ |
| 数组字面量 | ✅ | ✅ | ✅ |
| 字典字面量 | ✅ | ❌ | ✅ |

## 附录 B: 后续扩展计划

- [ ] **编译期模板**: 将模板预编译为 MoonBit 源码，零运行时开销
- [ ] **增量渲染**: 支持流式输出，适用于大模板
- [ ] **调试模式**: 输出带注释的渲染结果，标记变量来源
- [ ] **LSP 支持**: 模板语法高亮和自动补全的 Language Server
- [ ] **i18n 集成**: 国际化过滤器 `{{ "key" | trans }}`
- [ ] **沙箱模式**: 限制模板可访问的变量和函数
- [ ] **自定义标签**: 类似 Django 的自定义 template tag API
- [ ] **空白控制**: 更精细的 `{%- -%}` 空白修剪
