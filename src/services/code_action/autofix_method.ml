(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

(* This class maps each node that contains the target until a node is contained
   by the target *)
module Super_finder = struct
  class finder =
    object (this)
      inherit [bool, Loc.t] Flow_ast_visitor.visitor ~init:false

      method! super_expression _ node =
        this#set_acc true;
        node

      (* Any mentions of `this` in these constructs would reference
         the `this` within those structures, so we ignore them *)
      method! class_ _ x = x

      method! function_declaration _ x = x

      method! function_expression_or_method _ x = x
    end

  let found_super_in_body (body : (Loc.t, Loc.t) Flow_ast.Function.body) =
    let finder = new finder in
    finder#eval finder#function_body_any body
end

module Arguments_finder = struct
  class finder =
    object (this)
      inherit [bool, Loc.t] Flow_ast_visitor.visitor ~init:false

      method! identifier ((_, Flow_ast.Identifier.{ name; _ }) as id) =
        this#set_acc (name = "arguments");
        id

      (* Any mentions of `this` in these constructs would reference
         the `this` within those structures, so we ignore them *)
      method! function_declaration _ x = x

      method! function_expression_or_method _ x = x
    end

  let found_arguments_in_body (body : (Loc.t, Loc.t) Flow_ast.Function.body) =
    let finder = new finder in
    finder#eval finder#function_body_any body
end

class mapper target =
  object (this)
    inherit Flow_ast_contains_mapper.mapper target as super

    method private is_constructor =
      Flow_ast.(
        Expression.Object.Property.(
          function
          | Identifier (_, { Identifier.name; _ }) -> name = "constructor"
          | StringLiteral (_, { StringLiteral.raw; _ }) -> raw = "constructor"
          | NumberLiteral _
          | BigIntLiteral _
          | PrivateName _
          | Computed _ ->
            false
        )
      )

    method! class_element elem =
      let open Flow_ast in
      let open Flow_ast.Class in
      match elem with
      | Body.Method (loc, { Method.value = (mloc, value); key; static; decorators; comments; _ })
        when this#is_target loc ->
        if
          this#is_constructor key
          || Super_finder.found_super_in_body value.Flow_ast.Function.body
          || Arguments_finder.found_arguments_in_body value.Flow_ast.Function.body
        then
          super#class_element elem
        else
          let value = Property.Initialized (mloc, Expression.ArrowFunction value) in
          Body.Property
            ( loc,
              {
                Property.key;
                value;
                static;
                variance = None;
                annot = Type.Missing loc;
                decorators;
                comments;
              }
            )
      | _ -> super#class_element elem
  end

let replace_method_at_target ast loc =
  let mapper = new mapper loc in
  mapper#program ast
