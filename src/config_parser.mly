%{
  exception SyntaxError of string
%}

(* punctuators *)
%token LCBRACE RCBRACE EQ COMMA

(* keyword *)
%token KEYWORD_DEFLOCK
%token KEYWORD_LOCK KEYWORD_DEFVAR KEYWORD_KEY

(* %token <string> WHITE_SPACE *)
(* %token <string> LINE_TERMINATOR *)

%token <string> VARIABLE
%token <string> IDENT
%token EOF
%start parser_main
%type <Config_type.main option> parser_main
%%

parser_main:
EOF {None}
   |config EOF {Some $1}
  ;

  config:
    statements { Config_type.Cprog_main ($1)}
  ;

  statements:
    statement { [$1]}
   |statements statement { $1 @ [$2] }
  ;

  statement:
    key_statement { $1 }
   |deflock_statement { $1 }
   |lock_statement { $1 }
   |defvar_statement { $1 }
  ;

  key_statement:
    KEYWORD_KEY identifier EQ key_sequences { Config_type.Cstm_key ($2, $4)}
  ;

  deflock_statement:
    KEYWORD_DEFLOCK ident=identifier EQ seq=key_sequence {
      match ident with
      | Config_type.Cexp_ident _ -> Config_type.Cstm_deflock(ident, seq)
      | _ -> failwith "deflock only apply identifier"
    }
  ;

  lock_statement:
    KEYWORD_LOCK identifier LCBRACE list(key_statement) RCBRACE { Config_type.Cstm_lock ($2, $4)}
  ;

  defvar_statement:
    KEYWORD_DEFVAR variable EQ key_sequences { Config_type.Cstm_defvar ($2, $4)}
  ;

  (* Key sequence grammer*)
  key_sequences:
    separated_nonempty_list(COMMA, key_sequence) { $1 }
  ;

  key_sequence:
    variable {$1}
   |identifier {$1}
  ;

  identifier:
    IDENT {Config_type.Cexp_var ($1)}
  ;

  variable:
    VARIABLE {Config_type.Cexp_ident ($1)}
  ;
