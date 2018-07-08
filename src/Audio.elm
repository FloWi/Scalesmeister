module Audio exposing (loadPianoSamples, noteOn, noteOff, play, stop)

import Types.Pitch as Pitch exposing (..)
import Types.Note exposing (..)
import Ports exposing (SampleUrl, ScientificPitchNotation)
import Types.Octave as Octave exposing (..)
import List.Extra


toScientificPitchNotation : Pitch -> Maybe ScientificPitchNotation
toScientificPitchNotation pitch =
    case Pitch.enharmonicEquivalents (pitch |> Pitch.semitoneOffset) |> choice [ natural, sharp, flat ] of
        Nothing ->
            Nothing

        Just (Pitch (Note letter accidental) octave) ->
            let
                acc =
                    case accidental of
                        Flat ->
                            Just "b"

                        Natural ->
                            Just ""

                        Sharp ->
                            Just "#"

                        _ ->
                            Nothing
            in
                acc |> Maybe.map (\accidental -> (toString letter) ++ accidental ++ (toString (Octave.number octave)))


pitchToSampleUrlMapping : Pitch -> Maybe ( ScientificPitchNotation, SampleUrl )
pitchToSampleUrlMapping (Pitch (Note letter accidental) octave) =
    let
        acc =
            case accidental of
                Natural ->
                    ""

                _ ->
                    toString accidental

        url =
            "samples/" ++ (toString letter) ++ acc ++ (toString (Octave.number octave)) ++ ".mp3"
    in
        toScientificPitchNotation (Pitch (Note letter accidental) octave)
            |> Maybe.map (\key -> ( key, url ))


loadPianoSamples : Cmd msg
loadPianoSamples =
    [ Note C Natural
    , Note D Sharp
    , Note F Sharp
    , Note A Natural
    ]
        |> List.concatMap
            (\note ->
                [ Octave.one
                , Octave.two
                , Octave.three
                , Octave.four
                , Octave.five
                , Octave.six
                , Octave.seven
                ]
                    |> List.map (Pitch note)
            )
        |> ((++) [ Pitch (Note A Natural) Octave.zero, Pitch (Note C Natural) Octave.eight ])
        |> List.filterMap pitchToSampleUrlMapping
        |> Ports.loadSamples


noteOn : Pitch -> Cmd msg
noteOn pitch =
    toScientificPitchNotation pitch
        |> Maybe.map Ports.noteOn
        |> Maybe.withDefault Cmd.none


noteOff : Pitch -> Cmd msg
noteOff pitch =
    toScientificPitchNotation pitch
        |> Maybe.map Ports.noteOff
        |> Maybe.withDefault Cmd.none


play : List Pitch -> Cmd msg
play pitches =
    Ports.startSequence (List.filterMap toScientificPitchNotation pitches)


stop : Cmd msg
stop =
    Ports.stopSequence ()
