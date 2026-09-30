; Helix: the first matching pattern wins, so specific patterns come first.

(comment) @comment

; Keys
(attr key: (_) @variable.other.member)
(config_attr key: (unquoted_string) @variable.other.member)
(config key: (unquoted_string) @variable.other.member)
(string_pair key: (unquoted_string) @variable.other.member)

; Blocks
(composite_type) @keyword
[
  "END"
  "SYMBOLSET"
  "CONFIG"
  "ENV"
  "MAPS"
  "PLUGINS"
  "PROJECTION"
  "POINTS"
  "PATTERN"
  "VALUES"
  "METADATA"
  "VALIDATION"
  "CONNECTIONOPTIONS"
  "INCLUDE"
  "CLASSAUTO"
] @keyword

; Expressions
(func_call name: (_) @function)
(attr_bind (unquoted_string) @variable)
(runtime_var) @variable

[
  (compare_op)
  "AND"
  "OR"
  "NOT"
  "&&"
  "||"
  "!"
  "+"
  "-"
  "*"
  "/"
  "^"
] @operator

; Values
(string) @string
(unquoted_string_space) @string
(hexcolor) @string
(regexp) @string.regexp
(path) @string.special.path
(int) @constant.numeric.integer
(float) @constant.numeric.float
[(true) (false)] @constant.builtin.boolean
[(null) (auto) (style_mode)] @constant

; Unquoted values are mostly enums (`STATUS ON`, `UNITS meters`).
(attr value: (unquoted_string) @constant)
(config_attr value: (unquoted_string) @constant)
(config value: (unquoted_string) @constant)
(string_pair value: (unquoted_string) @constant)

["(" ")" "[" "]" "{" "}"] @punctuation.bracket
"," @punctuation.delimiter
