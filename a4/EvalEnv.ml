(*************************************************)
(* An environment-based evaluator for Dynamic ML *)
(*************************************************)

open Syntax
open Printing
open EvalUtil

(* Defines the subset of expressions considered values
   Notice that closures are values but the rec form is not -- this is
   slightly different from the way values are defined in the 
   substitution-based interpreter.  Rhetorical question:  Why is that?
   Notice also that Cons(v1,v2) is a value (if v1 and v2 are both values).
*) 
let rec is_value (e:exp) : bool = 
  match e with
    Constant _ -> true  
  | Pair (e1, e2) -> is_value e1 && is_value e2
  | EmptyList -> true
  | Cons (e1, e2) -> is_value e1 && is_value e2
  | Closure _ -> true
  | _ -> false

let rec contains xs x : bool =
  match xs with
  | [] -> false
  | hd::_ when var_eq hd x -> true
  | _::tl -> contains tl x

let rec free_variables' (bound: variable list) (free: variable list) (e: exp) : variable list =
  let unbound_free = free_variables' bound free in
  match e with
  (* Don't bother looking for vars in values *)
  | _ when is_value e -> []
  (* Expressions with vars *)
  | Var x ->
    if contains bound x
    then free
    else x::free
  | Let (var, x, expression) ->
    free_variables' (var::bound) free expression
  | Rec(name, param, body)->
    free_variables' (param::name::bound) free body 
  | Match (matcher, if_empty, hd, tl, if_full)-> 
    unbound_free matcher @
    unbound_free if_empty @
    free_variables' (hd::tl::bound) free if_full
  (* Expressions without vars *)
  | Constant _ -> []
  | Op (x, op, y) ->
    unbound_free x @
    unbound_free y
  | If (condition, yes, no) ->
    unbound_free condition @
    unbound_free yes @
    unbound_free no
  | Pair(x, y) ->
    unbound_free x @
    unbound_free y
  | Fst p -> 
    unbound_free p
  | Snd p -> 
    unbound_free p
  | EmptyList -> []
  | Cons (hd, tl)-> 
    unbound_free hd @
    unbound_free tl
  | Closure _-> []
  | App(f, arg)->
    unbound_free f @
    unbound_free arg 

let free_variables (bound: variable list) (e: exp) : variable list =
  free_variables' bound [] e

let lookup_env_pair (env:env) (x:variable) : (variable * exp) =
  match lookup_env env x with
  | None -> raise (UnboundVariable x)
  | Some value -> (x, value)

let remove_dupe clean x =
  if contains clean x then clean else x::clean

let dedupe (xs: 'a list): 'a list =
  xs
  |> List.fold_left remove_dupe []
  |> List.rev

let prune_env (env: env) (free: variable list) : env =
  List.map (fun var -> lookup_env_pair env var) free

(* evaluation; use eval_loop to recursively evaluate subexpressions *)
let eval_body (env:env) (eval_loop:env -> exp -> exp) (e:exp) : exp = 
  let eval_env = eval_loop env in
  match e with
  | Var x -> 
    (match lookup_env env x with 
     | None -> raise (UnboundVariable x)
     | Some v -> v)
  | Constant _ -> e
  | Op (x, op, y) ->
    let v1 = eval_env x in 
    let v2 = eval_env y in 
    apply_op v1 op v2 
  | If (condition, yes, no) ->
    (match eval_env condition with
     | Constant (Bool true) -> eval_env yes
     | Constant (Bool false) -> eval_env no
     | v1 -> raise (BadIf v1))
  | Let (var, x, expression) ->
    let value = eval_env x in
    eval_loop (update_env env var value) expression
  | Pair(x, y) -> Pair(eval_env x, eval_env y)
  | Fst p -> 
    (match eval_env p with
     | Pair(x, _) -> eval_env x
     | p -> raise (BadPair p))
  | Snd p -> 
    (match eval_env p with
     | Pair(_, y) -> eval_env y
     | p -> raise (BadPair p))
  | EmptyList -> EmptyList
  | Cons (hd, tl)-> 
    let hd = eval_env hd in
    (match eval_env tl with
     | EmptyList -> Cons(hd, EmptyList)
     | Cons(x,y) -> Cons(hd, Cons(x,y))
     | _ -> raise (BadMatch tl))
  | Match (matcher, if_empty, hd, tl, if_full)-> 
    (match eval_env matcher with
     | EmptyList -> eval_env if_empty
     | Cons(h, t) ->
       let env = update_env env hd h in
       let env = update_env env tl t in
       eval_loop env if_full
     | _ -> raise (BadMatch matcher))
  | Rec(name, param, body)->
    let env = 
      body 
      |> free_variables [param;name]
      |> dedupe
      |> prune_env env in

    Closure(env, name, param, body)
  | Closure _-> e
  | App(f, arg)->
    (match eval_env f with
     | Closure(c_env, name, param, body) ->
       let arg = eval_env arg in

       let c_env = update_env c_env name (Closure(c_env, name, param, body)) in
       let c_env = update_env c_env param arg in

       eval_loop (update_env c_env param arg) body
     | _ -> raise (BadApplication f))

(* evaluate closed, top-level expression e *)

let eval e =
  let rec loop env e = eval_body env loop e in
  loop empty_env e


(* print out subexpression after each step of evaluation *)
let debug_eval e = 
  let rec loop env e =
    if is_value e then e  (* don't print values *)
    else 
      begin
        Printf.printf "Evaluating %s\n" (string_of_exp e); 
        let v = eval_body env loop e in 
        Printf.printf 
          "%s evaluated to %s\n" (string_of_exp e) (string_of_exp v); 
        v
      end
  in
  loop empty_env e
