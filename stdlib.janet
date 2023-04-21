# Internal Functions (defined by the implementation)
# `neorg/set-property`
# `neorg/from-object` (to convert Neorg nodes to janet nodes)

(defn neorg/abstract-object? [object]
 "Checks if the given object is an abstract object.
  
  An abstract object is an object that has a `:bind` key and its value is a Treesitter node.
  
  Arguments:
  - object: The object to check.
  
  Returns:
  - true if the object is an abstract object, false otherwise."
 (def binding (get object :bind))
 (and (truthy? binding) (neorg/ts/node? binding)))

(defn neorg/abstracto-object/unbind [abstract-object]
  "Unbinds an abstract object into its bound value and data.
  
  Arguments:
  - abstract-object: The abstract object to unbind.
  
  Returns:
  - A tuple containing the bound value and data of the abstract object.
  
  Throws:
  - An error if the given variable is not an abstract object."
 (unless (neorg/abstract-object? abstract-object) (error "Variable is not an abstract object!"))
 [(get abstract-object :bind) (get abstract-object :data)])

(defn neorg/export/code-block/markdown [abstract-object]
  "Exports a code block as a markdown-formatted string.
  
  Arguments:
  - abstract-object: The abstract object representing the code block.
  
  Returns:
  - A string containing the markdown-formatted code block."
 (def [bound-value, data] (neorg/abstract-object/unbind abstract-object))
 (string "```" (or (data :language) "") "\n" (neorg/ts/node-text bound-value) "\n```"))

(defn neorg/export/code-block [abstract-object target]
  "Exports a code block to the specified target language.
  
  Arguments:
  - abstract-object: The abstract object representing the code block.
  - target: The target language to export the code block to.
  
  Returns:
  - The exported code block in the target language.
  
  Throws:
  - An error if the target language is not supported for code block export."
 (try
  (eval-string (string "(neorg/export/code-block/" target " " 'abstract-object ")"))
  ([_] (error (string "Language with name '" target "' not supported for code block export!")))))
