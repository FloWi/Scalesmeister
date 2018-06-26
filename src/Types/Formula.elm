module Types.Formula exposing (..)


type alias Formula =
    List Int


type Direction
    = Ascending
    | Descending
    | Static


direction : Formula -> Direction
direction formula =
    let
        sum =
            List.sum formula
    in
        if sum > 0 then
            Ascending
        else if sum < 0 then
            Descending
        else
            Static


invert : Formula -> Formula
invert formula =
    formula |> List.map ((*) -1)


formula1 : Formula
formula1 =
    [ -2, -1, 2, -1 ]


formula2 : Formula
formula2 =
    [ -1, 2, -1, -2 ]


formula3 : Formula
formula3 =
    [ 2, -1, -2, -1 ]


formula4 : Formula
formula4 =
    [ -1, -2, -1, 2 ]


formula5 : Formula
formula5 =
    [ 3, -2, -2, 3 ]
