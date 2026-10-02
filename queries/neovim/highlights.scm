; Neovim: the last matching pattern wins, so generic patterns come first.
; The Helix version is ../highlights.scm; keep the two in sync.

; Values
(string) @string
(unquoted_string_space) @string
(hexcolor) @string
(regexp) @string.regexp
(path) @string.special.path
(int) @number
(float) @number.float
[(true) (false)] @boolean
[(null) (auto)] @constant.builtin
(style_mode) @constant

; Unquoted values are mostly enums (`STATUS ON`, `UNITS meters`).
(attr value: (unquoted_string) @constant)
(config_attr value: (unquoted_string) @constant)
(config value: (unquoted_string) @constant)
(string_pair value: (unquoted_string) @constant)

["(" ")" "[" "]" "{" "}"] @punctuation.bracket
"," @punctuation.delimiter

; Expressions
[
  (compare_op)
  "&&"
  "||"
  "!"
  "+"
  "-"
  "*"
  "/"
  "^"
] @operator

[
  "AND"
  "OR"
  "NOT"
] @keyword.operator

(func_call name: (_) @function.call)
(attr_bind (unquoted_string) @variable)
(runtime_var) @variable

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
  "CLASSAUTO"
] @keyword

"INCLUDE" @keyword.import

; Keys
(attr key: (_) @property)
(config_attr key: (unquoted_string) @property)
(config key: (unquoted_string) @property)
(string_pair key: (unquoted_string) @property)

(comment) @comment @spell
