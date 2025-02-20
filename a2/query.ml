(* Box office analysis *)

(* Contents:
    -- the movie type
    -- the studio_gross type
    -- functions for querying and transforming lists of movies
*)

(* a movie is a tuple of (title, studio, gross in millions, year) *)
type movie = string * string * float * int

(* a studio_gross is a pair of (studio, gross in millions) *)
type studio_gross = string * float

(* call bad_argument if your function receives a bad argument *)
(* do not change this exception or function                   *)
exception Bad_arg of string
let bad_arg (s:string) = raise (Bad_arg s)

(* a useful debugging routine *)
let debug s = print_string s; flush_all()

(* *** DO NOT CHANGE DEFINITIONS ABOVE THIS LINE! *** *)

let rec map (f: ('a -> 'b)) (xs: 'a list): 'b list =
  match xs with
  | [] -> []
  | hd::tl -> (f hd)::(map f tl)

let rec reduce (f: ('b -> 'a -> 'b)) (acc: 'b) (xs: 'a list): 'b =
  match xs with
  | [] -> acc
  | hd::tl -> reduce f (f acc hd) tl

let reverse xs = reduce (fun acc x -> x::acc ) [] xs

let length: 'a list -> int =
  reduce (fun acc _ -> acc + 1) 0

let do_filter f acc x =
  if f x then
    x::acc
  else
    acc

let rec filter (f: ('a -> bool)) (xs: 'a list): 'a list = 
  reverse (reduce (do_filter f) [] xs)

(* you may add "rec" after any of the let declarations below that you
 * wish if you find doing so useful. *)

let ( % ) f g x = f (g x)
let flip f x y = f y x
let equals x y = x = y
let reverse xs = reduce (fun acc x -> x::acc ) [] xs

let get_name   ((name,   _, _, _): movie): string = name
let get_studio ((_, studio, _, _): movie): string = studio
let get_gross  ((_, _, gross,  _): movie): float  = gross
let get_year   ((_, _, _, year  ): movie): int    = year

(* find the average gross of the movies in the list                  *)
(* return 0.0 if the list is empty                                   *)
(* hint: you may need to use functions float_of_int and int_of_float *)
(* hint: if you don't know what those functions do,                  *)
(*       type them in to ocaml toplevel                              *)
(* hint: recall the difference between +. and + also 0. and 0        *)

let sum_floats = reduce (+.) 0.
let sum_gross: (movie list -> float) = sum_floats % (map get_gross)

let average (movies : movie list) : float = 
  match (float_of_int (length movies)) with
  | 0. -> 0.
  | count -> (sum_gross movies) /. count

(* return a list containing only the movies from the given decade *)
(* call bad_arg if n is not 20, 30, ..., 90, 00, 10               *)
(* Treat 0 as 00 (this is unavoidable as 00 is not represented    *)
(*   differently from 0).                                         *)
(* Note: movies from any years outside the range 1920-2019 will   *)
(* always be discarded but should not raise an error condition    *)
let last_two: (int -> int) = flip (mod) 100
let last_one:   (int -> int) = flip (mod) 10
let get_decade_start (n: int): int = (last_two n) - (last_one n)

let bad_decade (n: int): bool = n < 0 || 90 < n
let bad_year   (n: int): bool = (n mod 10) != 0
let bad_decade_input (n: int): bool = bad_decade n || bad_year n

let decade (n:int) (ms:movie list) : movie list =
  if bad_decade_input n then
    bad_arg (string_of_int n)
  else
    filter (equals n % get_decade_start % get_year) ms

(* return the first n items from the list *)
(* if there are fewer than n items, return all of them *)
(* call bad_arg if n is negative *)
let rec take (n:int) (l:'a list)  : 'a list =
  match l with
  | [] -> []
  | hd::tl ->
    match n with
    | 0 -> []
    | n when n < 0 -> bad_arg (string_of_int n)
    | n -> hd :: take (n - 1) tl

(* return everything but the first n items from the list *)
(* if there are fewer than n items, return the empty list *)
(* call bad_arg if n is negative *)

let rec drop (n:int) (l:'a list)  : 'a list =
  match l with
  | [] -> []
  | hd::tl ->
    match n with
    | 0 -> l
    | n when n < 0 -> bad_arg (string_of_int n)
    | n -> drop (n - 1) tl

(* return a list [x1; x2; ...; xn] with the same elements as the input l
   and where:
     leq xn xn-1
     ...
     leq x3 x2
     leq x2 x1
     are all true
*)

(* hint: define an auxiliary function "select" *)
type 'a less = 'a -> 'a -> bool

let rec select (leq:'a less) (l:'a list) (lowest: 'a): 'a =
  match l with
  | [] -> lowest
  | hd::tl when leq hd lowest -> select leq tl hd
  | hd::tl -> select leq tl lowest

let rec remove (lowest: 'a) (acc: 'a list) (l: 'a list): 'a list =
  match l with
  | [] -> acc
  | hd::tl when hd = lowest -> remove lowest acc tl
  | hd::tl -> remove lowest (hd::acc) tl

let rec selection_sort (leq:'a less) (l:'a list) : 'a list =
  match l with
  | [] -> []
  | hd::_ -> 
    let lowest = (select leq l hd) in
    lowest :: (selection_sort leq % (remove lowest []) @@ l)

(* ASIDE:  Why does this assignment ask you to implement selection sort?
   Insertion sort is almost always preferable to selection sort,
   if you have to implement a quadratic-time sorting algorithm.
   Insertion sort is faster, it's simpler to implement, and it's
   easier to reason about.  For smallish inputs (less than 5 or 8),
   insertion sort is typically faster than quicksort or any
   other NlogN sorting algorithm.  So, why do we ask you to implement
   selection sort?  Answer: we already showed you insertion sort
   in the lecture notes.

   ASIDE 2: But at least selection sort is better than bubble sort.
   Even Barack Obama knows that. https://www.youtube.com/watch?v=k4RRi_ntQc8
*)

let compare_field (getter: ('a -> 'b)) (comparator: ('b -> 'b -> bool)) (x: 'a) (y: 'a) =
  comparator (getter x) (getter y)

(* return list of movies sorted by gross (largest gross first) *)
let compare_gross = compare_field get_gross (>)

let sort_by_gross: (movie list -> movie list) =
  selection_sort compare_gross 

(* return list of movies sorted by year produced (largest year first) *)
let compare_year = compare_field get_year (>)

let sort_by_year: (movie list -> movie list) =
  selection_sort compare_year

(* sort list of (studio, gross in millions) by gross in millions 
 * with the largest gross first *)
let get_studio_gross ((_, gross): studio_gross): float = gross
let compare_studio_gross = compare_field get_studio_gross (>)

let sort_by_studio: (studio_gross list -> studio_gross list) =
  selection_sort compare_studio_gross

(* given list of movies,
 * return list of pairs (studio_name, total gross revenue for that studio)  *)
let rec add_to_studio (others: studio_gross list) (studios: studio_gross list) (studio: studio_gross) : studio_gross * studio_gross list =
  let (name, gross) = studio in
  match studios with
  | [] -> (studio, others)
  | (hd_name, hd_gross)::tl when hd_name = name ->
    add_to_studio others tl (name, gross +. hd_gross)
  | hd::tl -> add_to_studio (hd::others) tl studio

let rec merge_studios (studios: studio_gross list): studio_gross list =
  match studios with
  | [] -> []
  | hd::tl -> 
    let (full_studio, others) = add_to_studio [] tl hd in
    full_studio :: merge_studios others

let to_studio = function
    (_, studio, gross, _) -> (studio, gross)

let by_studio: (movie list -> studio_gross list) =
  reverse % merge_studios % map to_studio

(***********)
(* Testing *)
(***********)

(* Augment the testing infrastructure below as you see fit *)

(* Test Data *)

let data1 : movie list = [
  ("The Lord of the Rings: The Return of the King","NL",377.85,2003)
]

let data2 : movie list = [
  ("The Lord of the Rings: The Return of the King","NL",377.85,2003);
  ("The Hunger Games","LGF",374.32,2012)
]

let data3 : movie list = [
  ("Harry Potter and the Sorcerer's Stone","WB",317.57555,2001);
  ("Star Wars: Episode II - Attack of the Clones","Fox",310.67674,2002);
  ("Return of the Jedi", "Fox", 309.306177, 1983)
]

let data4 : movie list = [
  ("The Lord of the Rings: The Return of the King","NL",377.85,2003);
  ("The Hunger Games","LGF",374.32,2012);
  ("The Dark Knight","WB",533.34,2008);
  ("Harry Potter and the Deathly Hallows Part 2","WB",381.01,2011)
]

(* Assertion Testing *)

(* Uncomment the following when you are ready to test your take routine *)
(*
let _ = assert(take 0 data4 = [])
let _ = assert(take 1 data1 = data1)
let _ = assert(take 2 data4 = data2)
let _ = assert(take 5 data2 = data2)
let _ = assert(take 2 data2 = data2)
*)

(* Additional Testing Infrastructure *)

let stests : (unit -> movie list) list = [
  (fun () -> sort_by_gross data1);
  (fun () -> sort_by_gross data2);
  (fun () -> sort_by_gross data3);
  (fun () -> sort_by_gross data4)
]

let check (i:int) (tests:(unit -> 'a) list) : 'a =
  if i < List.length tests && i >= 0 then
    List.nth tests i ()
  else
    failwith ("bad test" ^ string_of_int i)
