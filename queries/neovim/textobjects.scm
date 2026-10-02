; For nvim-treesitter-textobjects. Blocks behave like classes.
(composite
  type: (_)
  (_)+ @class.inner) @class.outer

(symbolset
  (_)+ @class.inner) @class.outer

(config_file
  (_)+ @class.inner) @class.outer

[
  (env)
  (maps)
  (plugins)
  (projection)
  (points)
  (pattern)
  (values)
  (metadata)
  (validation)
  (connectionoptions)
] @class.outer

(func_call
  (func_params) @call.inner) @call.outer

(func_params
  (_) @parameter.inner)

(comment) @comment.inner
(comment)+ @comment.outer
