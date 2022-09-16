(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

val evaluate_hint :
  Context.t ->
  Reason.t ->
  resolver:(Context.t -> Type.t -> Type.t) ->
  (Type.t, Type.call_arg list) Hint_api.hint ->
  Type.t option
