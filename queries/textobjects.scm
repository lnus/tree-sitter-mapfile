; Blocks behave like classes: `]c`, `mac`, `mic`.
(composite
  type: (_)
  (_)+ @class.inside) @class.around

(symbolset
  (_)+ @class.inside) @class.around

(config_file
  (_)+ @class.inside) @class.around

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
] @class.around

(func_call
  (func_params) @function.inside) @function.around

(func_params
  (_) @parameter.inside)

(comment) @comment.inside
(comment)+ @comment.around
