open Printf

module Non_deterministic = struct
  type 'a t = 'a list

  let map = List.map

  let bind v f = List.concat_map f v

  let ( let* ) v f = bind v f

  let ( let+ ) v f = map f v

  let return v = [v]
end

type sudoku = int option array array

let di i = Some i

let print_sudoku ~sudoku =
  Array.iter
    (fun row ->
      Array.iter (function None -> printf "_ " | Some d -> printf "%i " d) row ;
      print_newline () )
    sudoku

let copy_sudoku ~sudoku = Array.(map copy sudoku)

let sudoku =
  [| [|di 2; di 5; None; di 8; None; di 3; None; di 6; None|]
   ; [|None; di 3; di 4; di 6; None; None; None; di 2; di 9|]
   ; [|di 6; None; None; None; di 9; di 5; di 3; None; di 4|]
   ; [|None; di 6; di 5; di 1; None; None; di 2; None; di 7|]
   ; [|None; di 8; None; di 7; di 3; None; None; di 1; di 5|]
   ; [|di 9; di 1; None; None; di 6; di 2; di 8; None; None|]
   ; [|di 5; di 9; None; None; None; None; di 1; di 7; di 6|]
   ; [|di 1; None; di 8; di 3; di 7; di 6; None; None; None|]
   ; [|None; None; di 6; None; di 5; di 1; di 4; di 3; None|] |]

let is_in_same_square (i, j) (i', j') = i / 3 = i' / 3 && j / 3 = j' / 3

let n_empty_cell ~sudoku =
  Array.fold_left
    (fun count row ->
      Array.fold_left
        (fun count cell -> match cell with None -> count + 1 | Some _ -> count)
        count row )
    0 sudoku

let fill_cells ~sudoku ~cells =
  let new_cell_coord = ref None in
  let cells = ref cells in
  Array.iteri
    (fun i row ->
      Array.iteri
        (fun j cell ->
          match cell with
          | Some _ ->
              ()
          | None -> (
            match !cells with
            | [] -> (
              match !new_cell_coord with
              | Some _ ->
                  ()
              | None ->
                  new_cell_coord := Some (i, j) )
            | cell_digit :: tl_cells ->
                cells := tl_cells ;
                sudoku.(i).(j) <- Some cell_digit ) )
        row )
    sudoku ;
  !new_cell_coord

let is_legal ~sudoku ~cells ~cell digit =
  assert (cell = List.length cells) ;
  let sudoku : sudoku = copy_sudoku ~sudoku in
  let next_cell_coord = fill_cells ~sudoku ~cells in
  let new_cell_i, new_cell_j = Option.get next_cell_coord in
  let row_legal =
    Array.for_all
      (function None -> true | Some digit' -> digit <> digit')
      sudoku.(new_cell_i)
  in
  let unique sudoku =
    Array.for_all
      (fun row ->
        Array.for_all
          (function None -> true | Some digit' -> digit <> digit')
          row )
      sudoku
  in
  let column_sudoku =
    Array.mapi
      (fun i row ->
        Array.mapi (fun j cell -> if new_cell_j = j then cell else None) row )
      sudoku
  in
  let column_legal = unique column_sudoku in
  let square_sudoku =
    Array.mapi
      (fun i row ->
        Array.mapi
          (fun j cell ->
            if is_in_same_square (new_cell_i, new_cell_j) (i, j) then cell
            else None )
          row )
      sudoku
  in
  let square_legal = unique square_sudoku in
  let res = row_legal && square_legal && column_legal in
  res

let is_legal = is_legal ~sudoku

let digits = [1; 2; 3; 4; 5; 6; 7; 8; 9]

(* [digit] is one element of [digits], we do not know which one *)
let solutions =
  (* solving cell by cell. A bit tedious. *)
  let open Non_deterministic in
  let* digit = digits in
  let* cell_0 =
    if is_legal ~cells:[] ~cell:0 digit then return digit
    else
      (* If this branch is executed, the execution stops here : [concat_map f []]
         does not call [f] *)
      []
  in
  let* digit = digits in
  let* cell_1 =
    if is_legal ~cells:[cell_0] ~cell:1 digit then return digit else []
  in
  let* digit = digits in
  let* cell_2 =
    if is_legal ~cells:[cell_0; cell_1] ~cell:2 digit then return digit else []
  in
  let* digit = digits in
  let* cell_3 =
    if is_legal ~cells:[cell_0; cell_1; cell_2] ~cell:3 digit then return digit
    else []
  in
  let* digit = digits in
  let* cell_4 =
    if is_legal ~cells:[cell_0; cell_1; cell_2; cell_3] ~cell:4 digit then
      return digit
    else []
  in
  let* digit = digits in
  let* cell_5 =
    if is_legal ~cells:[cell_0; cell_1; cell_2; cell_3; cell_4] ~cell:5 digit
    then return digit
    else []
  in
  let* digit = digits in
  let* cell_6 =
    if
      is_legal
        ~cells:[cell_0; cell_1; cell_2; cell_3; cell_4; cell_5]
        ~cell:6 digit
    then return digit
    else []
  in
  let* digit = digits in
  let* cell_7 =
    if
      is_legal
        ~cells:[cell_0; cell_1; cell_2; cell_3; cell_4; cell_5; cell_6]
        ~cell:7 digit
    then return digit
    else []
  in
  return [cell_0; cell_1; cell_2; cell_3; cell_4; cell_5; cell_6; cell_7]

let () =
  List.iter
    (fun solution ->
      List.iter (fun digit -> Printf.printf "%i " digit) solution ;
      print_newline () )
    solutions

(* Version for n cells, much more consise, but also more difficult to understand. *)
let solutions =
  let open Non_deterministic in
  let n_empty = n_empty_cell ~sudoku in
  let rev_solutions =
    List.fold_left
      (fun rev_cells cell_number ->
        (* [rev_cells] is a non-deterministic list of reversed cells. They are
           reversed because we add the last cell in front of the list.
           [cell_number] is the number of the current empty cell. *)
        let* rev_cells = rev_cells in
        let* digit = digits in
        let* digit =
          if is_legal ~cells:(List.rev rev_cells) ~cell:cell_number digit then
            return digit
          else []
        in
        return (digit :: rev_cells) )
      (return []) (List.init n_empty Fun.id)
  in
  List.map List.rev rev_solutions

let () =
  List.iteri
    (fun i solution ->
      printf "solution n%i\n" (i + 1) ;
      let sudoku = copy_sudoku ~sudoku in
      let _ = fill_cells ~sudoku ~cells:solution in
      print_sudoku ~sudoku )
    solutions
