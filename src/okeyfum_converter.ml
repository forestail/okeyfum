module T = Okeyfum_types
module IE = Okeyfum_types.Input_event
module E = Okeyfum_environment
module K = Okeyfum_key
module U = Okeyfum_util
module C = Okeyfum_config.Config

module GT = Okeyfum_ffi_bindings.Types(Okeyfum_ffi_generated_types)
let event_to_state {IE.value=value}= match value with
  | 0L -> `UP
  | _ -> `DOWN

let event_to_key_of_map event =
  let state = event_to_state event in
  match K.key_code_to_name event.IE.code with
    | None -> let module L = Okeyfum_log in
              L.debug (Printf.sprintf "Not defined key code: %d" event.IE.code);
              None
    | Some k -> Some (k, state)

(* Expand key sequence to terms are only code and function to invoke later *)
let rec expand_key config state = function
  | `Id k -> begin
    match K.key_name_to_code k with
    | Some c -> [T.Key (
      {IE.code = c;
       time = T.Timeval.empty;
       value = (match state with
       | `DOWN -> 1L
       | `UP -> 0L);
       typ = GT.Event_type.ev_key;
      })]
    | None -> let module L = Okeyfum_log in
              L.error (Printf.sprintf "Not defined key name : %s" k);
              raise Not_found
  end
  | `Var k -> let vars = C.variable_map config in
              let vars = try Hashtbl.find vars k with Not_found -> [] in
              expand_key_seq config state vars
  | `Func (fname, params) -> [T.Func(fname, params)]

and expand_key_seq config state seq =
  List.fold_left (fun seq key ->
    let keys = expand_key config state key in
    seq @ keys
  ) [] seq

let is_not_key_event {IE.typ=typ;_} = typ <> GT.Event_type.ev_key

(* resolve key event to key sequence to evalate with environment and config *)
let resolve_key_map config env event =
  let key = event_to_key_of_map event in
  let key_map = match E.locked_keys env with
    | [] -> C.keydef_map config
    | k :: _ -> C.lock_decls config |> List.filter (fun (k', _) -> k = k') |> List.hd |> snd
  in
  let module M = Okeyfum_config.Keydef_map in
  match key with
  | None -> None
  | Some key -> begin
    match try Some (M.find key key_map) with Not_found -> None with
    | None -> let module L = Okeyfum_log in
              let key, _  = key in
              L.debug (Printf.sprintf "Not found defined key sequence for : %s" key);
              None
    | Some seq -> let _, state = key in Some (expand_key_seq config state seq)
  end

let convert_event_to_seq ~config ~env ~event =
  let default_seq = [T.Key event] in
  if not (E.is_enable env) then default_seq
  else if is_not_key_event event then default_seq
  else
    match resolve_key_map config env event with
    | None -> default_seq
    | Some seq -> seq
