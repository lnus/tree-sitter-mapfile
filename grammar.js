/**
 * @file MapServer Mapfile grammar for tree-sitter
 * @author Linus Wæhler <17277861+lnus@users.noreply.github.com>
 * @license MIT
 *
 * Ported from mappyfile's Lark grammar (mappyfile/mapfile.lark). Node names
 * follow the Lark rule names where possible. mappyfile is MIT-licensed,
 * Copyright (c) 2017 Seth Girvin; see THIRD-PARTY-NOTICES.md.
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

const PREC = {
  or: 1,
  and: 2,
  not: 3,
  comparison: 4,
  sum: 5,
  product: 6,
  unary: 7,
};

// Blocks of the form `KEYWORD <items> END`.
const COMPOSITE_TYPES = [
  "CLASS",
  "CLUSTER",
  "COMPOSITE",
  "FEATURE",
  "GRID",
  "IDENTIFY",
  "JOIN",
  "LABEL",
  "LAYER",
  "LEADER",
  "LEGEND",
  "MAP",
  "OUTPUTFORMAT",
  "QUERYMAP",
  "REFERENCE",
  "SCALEBAR",
  "SCALETOKEN",
  "WEB",
];

// Keys that make `SYMBOL` open a block instead of being an attribute
// (schemas/symbol.json in mappyfile).
const SYMBOL_KEYS = [
  "ANCHORPOINT",
  "ANTIALIAS",
  "CHARACTER",
  "FILLED",
  "FONT",
  "IMAGE",
  "NAME",
  "TRANSPARENT",
  "TYPE",
];

// Values that make `STYLE` an attribute in QUERYMAP.
const STYLE_MODES = ["NORMAL", "HILITE", "SELECTED"];

const COMPARE_OPS = [">=", "<", "=*", "==", "=", "!=", "~", "~*", ">", "%", "<=", "<>"];
const COMPARE_WORDS = ["IN", "NE", "EQ", "LE", "LT", "GE", "GT", "LIKE"];

/**
 * Case-insensitive keyword that shows up in the tree as the anonymous node
 * `word` (upper case), e.g. `kw("END")` matches `end`, `End` and `END`.
 *
 * @param {string} word
 */
const kw = (word) => alias(new RegExp(word, "i"), word);

/**
 * `KEYWORD <content> END`
 *
 * @param {string} word
 * @param {RuleOrLiteral} content
 */
const block = (word, content) => seq(kw(word), content, kw("END"));

/**
 * @param {RuleOrLiteral} rule
 * @param {RuleOrLiteral} separator
 */
const sepBy1 = (rule, separator) => seq(rule, repeat(seq(separator, rule)));

export default grammar({
  name: "mapfile",

  extras: ($) => [/\s/, $.comment],

  word: ($) => $.unquoted_string,

  rules: {
    // A full MAP, a SYMBOLSET file, a CONFIG file, or a partial mapfile (e.g.
    // a lone LAYER, or the contents of an INCLUDEd file).
    source_file: ($) => repeat(choice($.symbolset, $.config_file, $._composite_item)),

    symbolset: ($) => block("SYMBOLSET", repeat($._composite_item)),

    // --- CONFIG file ----------------------------------------------------------

    config_file: ($) => block("CONFIG", repeat(choice($.env, $.maps, $.plugins))),

    env: ($) => block("ENV", repeat($.config_attr)),
    maps: ($) => block("MAPS", repeat($.config_attr)),
    plugins: ($) => block("PLUGINS", repeat($.config_attr)),

    // Block keywords aren't valid here, so they are lexed as plain
    // unquoted strings and can be used as keys.
    config_attr: ($) =>
      seq(
        field("key", choice($.unquoted_string, $.string)),
        field("value", $._attr_value),
      ),

    // --- Blocks ---------------------------------------------------------------

    _composite_item: ($) =>
      choice(
        $.attr,
        $.composite,
        $.points,
        $.projection,
        $.pattern,
        $.values,
        $.metadata,
        $.validation,
        $.connectionoptions,
        $.config,
        $.include,
        $.classauto,
      ),

    composite: ($) =>
      choice(
        seq(
          field("type", $.composite_type),
          repeat($._composite_item),
          kw("END"),
        ),
        // STYLE opens a block unless it is followed by a value (see `attr`).
        seq(
          field("type", alias(/style/i, $.composite_type)),
          repeat($._composite_item),
          kw("END"),
        ),
        // SYMBOL opens a block when followed by one of its keys, POINTS or
        // END. Otherwise it is an attribute.
        seq(
          field("type", alias(/symbol/i, $.composite_type)),
          optional(seq(choice(alias($.symbol_attr, $.attr), $.points), repeat($._composite_item))),
          kw("END"),
        ),
      ),

    composite_type: (_) => choice(...COMPOSITE_TYPES.map((k) => new RegExp(k, "i"))),

    // Shows up as `attr` in the tree.
    symbol_attr: ($) =>
      seq(
        field("key", alias(choice(...SYMBOL_KEYS.map((k) => new RegExp(k, "i"))), $.unquoted_string)),
        field("value", $._attr_value),
      ),

    projection: ($) =>
      block("PROJECTION", choice(repeat($.string), $.auto)),

    points: ($) => block("POINTS", repeat($.num_pair)),
    pattern: ($) => block("PATTERN", repeat($.num_pair)),

    values: ($) => block("VALUES", repeat($.string_pair)),
    metadata: ($) => block("METADATA", repeat($.string_pair)),
    validation: ($) => block("VALIDATION", repeat($.string_pair)),
    connectionoptions: ($) => block("CONNECTIONOPTIONS", repeat($.string_pair)),

    // `CONFIG "key" "value"` inside a MAP.
    config: ($) =>
      seq(
        kw("CONFIG"),
        field("key", choice($.string, $.unquoted_string)),
        field("value", choice($.string, $.unquoted_string)),
      ),

    // Not resolved, see CLAUDE.md.
    include: ($) => seq(kw("INCLUDE"), field("path", $.string)),

    classauto: (_) => kw("CLASSAUTO"),

    // --- Attributes -----------------------------------------------------------

    attr: ($) =>
      choice(
        seq(
          field("key", choice($.unquoted_string, alias(/symbol/i, $.unquoted_string))),
          field("value", $._attr_value),
        ),
        seq(
          field("key", alias(/style/i, $.unquoted_string)),
          field("value", choice($._value, $.style_mode)),
        ),
      ),

    style_mode: (_) => choice(...STYLE_MODES.map(kw)),

    _attr_value: ($) => choice($._value, $.unquoted_string),

    _value: ($) =>
      choice(
        $.string,
        $.int,
        $.float,
        $.expression,
        $.not_expression,
        $.attr_bind,
        $.path,
        $.regexp,
        $.runtime_var,
        $.list,
        $.null,
        $.true,
        $.false,
        $.extent,
        $.rgb,
        $.hexcolor,
        $.colorrange,
        $.hexcolorrange,
        $.num_pair,
        $.attr_bind_pair,
        $.attr_mixed_pair,
        $.auto,
      ),

    _number: ($) => choice($.int, $.float),

    // Grouped by count only; MapServer decides whether floats are allowed.
    num_pair: ($) => seq($._number, $._number),
    rgb: ($) => seq($._number, $._number, $._number),
    extent: ($) => seq($._number, $._number, $._number, $._number),
    colorrange: ($) => seq($._number, $._number, $._number, $._number, $._number, $._number),

    hexcolorrange: ($) => seq($.hexcolor, $.hexcolor),

    attr_bind_pair: ($) => seq($.attr_bind, $.attr_bind),
    attr_mixed_pair: ($) =>
      choice(seq($.attr_bind, $._number), seq($._number, $.attr_bind)),

    string_pair: ($) =>
      seq(
        field("key", choice($.string, $.unquoted_string)),
        field("value", choice($.string, $.unquoted_string)),
      ),

    attr_bind: ($) => seq("[", $.unquoted_string, "]"),

    list: ($) =>
      seq("{", sepBy1(choice($._value, $.unquoted_string_space), ","), "}"),

    // --- Expressions ----------------------------------------------------------

    expression: ($) => seq("(", $._expr, ")"),

    _expr: ($) =>
      choice(
        $.or_test,
        $.and_test,
        $.not_expression,
        $.comparison,
        $.add,
        $.sub,
        $.mul,
        $.div,
        $.power,
        $.neg,
        $.unary_expr,
        $._atom,
      ),

    or_test: ($) =>
      prec.left(PREC.or, seq($._expr, choice(kw("OR"), "||"), $._expr)),

    and_test: ($) =>
      prec.left(PREC.and, seq($._expr, choice(kw("AND"), "&&"), $._expr)),

    not_expression: ($) =>
      prec(PREC.not, seq(choice("!", kw("NOT")), $._expr)),

    comparison: ($) =>
      prec.left(PREC.comparison, seq($._expr, $.compare_op, $._expr)),

    compare_op: (_) => choice(...COMPARE_OPS, ...COMPARE_WORDS.map(kw)),

    add: ($) => prec.left(PREC.sum, seq($._expr, "+", $._expr)),
    sub: ($) => prec.left(PREC.sum, seq($._expr, "-", $._expr)),
    mul: ($) => prec.left(PREC.product, seq($._expr, "*", $._expr)),
    div: ($) => prec.left(PREC.product, seq($._expr, "/", $._expr)),
    power: ($) => prec.left(PREC.product, seq($._expr, "^", $._expr)),

    neg: ($) => prec(PREC.unary, seq("-", $._expr)),
    unary_expr: ($) => prec(PREC.unary, seq("+", $._expr)),

    // A subset of Lark's `value`: pairs and colours never occur in
    // expressions and would only add conflicts.
    _atom: ($) =>
      choice(
        $.func_call,
        $.expression,
        $.string,
        $.int,
        $.float,
        $.attr_bind,
        $.regexp,
        $.runtime_var,
        $.list,
        $.null,
        $.true,
        $.false,
      ),

    func_call: ($) =>
      seq(field("name", $.unquoted_string), "(", optional($.func_params), ")"),

    func_params: ($) => sepBy1($._expr, ","),

    // --- Terminals ------------------------------------------------------------

    true: (_) => kw("TRUE"),
    false: (_) => kw("FALSE"),
    null: (_) => kw("NULL"),
    auto: (_) => kw("AUTO"),

    // A trailing `i` makes the comparison case-insensitive.
    string: (_) =>
      token(
        choice(
          /"(\\"|[^"])*"i?/,
          /'(\\'|[^'])*'i?/,
          /`[^`]*`i?/,
        ),
      ),

    // Optional alpha channel. Wins over `string` on a tie.
    hexcolor: (_) =>
      token(
        prec(2, choice(
          /"#([0-9a-fA-F]{3}){1,2}([0-9a-fA-F]{2})?"/,
          /'#([0-9a-fA-F]{3}){1,2}([0-9a-fA-F]{2})?'/,
        )),
      ),

    // These overlap with each other and with `unquoted_string`. Tree-sitter
    // lets `prec` beat match length, so they have none: the longest match
    // wins (`5abc`, `/data/roads.shp`), and ties go to the rule defined first
    // (`5` is an int, `1.5` a float, `/foo/` a regexp).
    int: (_) => /[+-]?[0-9]+/,
    float: (_) =>
      /[+-]?([0-9]+[eE][+-]?[0-9]+|([0-9]+\.[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?)/,

    // `/.../` and `\\...\\`.
    regexp: (_) =>
      token(choice(
        /\/[^\/\n]*\/i?/,
        /\\\\([^\\\n]|\\[^\\\n])*\\\\i?/,
      )),

    path: (_) => /([a-zA-Z0-9_]*\.*\/|[a-zA-Z0-9_]+[.\/])[a-zA-Z0-9_\/.\-]+/,

    runtime_var: (_) => /%[^%\n]*%/,

    unquoted_string: (_) => /[a-zA-Z0-9_À-ÿ\-:]+/,

    // Unquoted list items, e.g. `{Main Street, O'Connell Street}`.
    unquoted_string_space: (_) => /[a-zA-Z0-9_À-ÿ\-: ']+/,

    comment: (_) =>
      token(prec(3, choice(
        /#[^\n]*/,
        /\/\*[^*]*\*+([^\/*][^*]*\*+)*\//,
      ))),
  },
});
