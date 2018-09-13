module State exposing (init, subscriptions, update)

import Audio
import Score exposing (render)
import SelectList exposing (SelectList)
import Task
import Types exposing (Device, Model, Msg(..), PlayingState(..))
import Types.Formula as Formula exposing (Formula)
import Types.Line as Line exposing (Line)
import Types.Note as Note
import Types.Octave as Octave
import Types.Orchestration as Orchestration
import Types.Pitch as Pitch exposing (Pitch(..), flat, natural, sharp)
import Types.PitchClass exposing (Accidental(..), Letter(..), PitchClass(..))
import Types.Range as Range exposing (Range, highest, lowest)
import Types.Scale exposing (Scale(..), ScaleDef, ionian, majorMinorSecondPentatonic, majorMinorSixthPentatonic, majorPentatonic, minorPentatonic, minorSevenDiminishedFifthPentatonic, minorSixthPentatonic)
import Types.Switch as Switch
import Types.TimeSignature as TimeSignature exposing (BeatDuration(..), NumberOfBeats(..), TimeSignature(..), beatDuration, durationGte)
import Window


scales : SelectList ( String, ScaleDef )
scales =
    SelectList.fromLists []
        ( "Major Pentatonic", majorPentatonic )
        [ ( "Minor Pentatonic", minorPentatonic )
        , ( "Minor 6 Pentatonic", minorSixthPentatonic )
        , ( "Major ♭6 Pentatonic", majorMinorSixthPentatonic )
        , ( "Minor 7 ♭5 Pentatonic", minorSevenDiminishedFifthPentatonic )
        , ( "Major ♭2 Pentatonic", majorMinorSecondPentatonic )
        , ( "Diatonic Major", ionian )
        ]


roots : SelectList PitchClass
roots =
    SelectList.fromLists
        []
        (PitchClass C Natural)
        [ PitchClass D Flat
        , PitchClass D Natural
        , PitchClass E Flat
        , PitchClass E Natural
        , PitchClass F Natural
        , PitchClass G Flat
        , PitchClass G Natural
        , PitchClass A Flat
        , PitchClass A Natural
        , PitchClass B Flat
        , PitchClass B Natural
        ]


formulas : SelectList Formula
formulas =
    SelectList.fromLists []
        [ 1 ]
        [ [ -1 ]
        , [ 2 ]
        , [ -2 ]
        , Formula.formula1
        , Formula.formula1 |> Formula.invert
        , Formula.formula2
        , Formula.formula2 |> Formula.invert
        , Formula.formula3
        , Formula.formula3 |> Formula.invert
        , Formula.formula4
        , Formula.formula4 |> Formula.invert
        , Formula.formula5
        , Formula.formula5 |> Formula.invert
        ]


mkLine : Range -> ScaleDef -> Formula -> PitchClass -> PitchClass -> Line
mkLine range scale formula root startingNote =
    Line.fromScaleWithinRange range (Scale root scale)
        |> Line.applyFormula startingNote formula


line : Model -> Line
line model =
    mkLine model.range
        (model.scales |> SelectList.selected |> Tuple.second)
        (model.formulas |> SelectList.selected)
        (model.roots |> SelectList.selected)
        model.startingNote


initialSizeCmd : Cmd Msg
initialSizeCmd =
    Task.perform (classifyDevice >> WindowResize) Window.size


init : ( Model, Cmd Msg )
init =
    let
        range =
            Range.piano
                |> Range.setLowest (Pitch (PitchClass C Natural) Octave.three)
                |> Range.setHighest (Pitch (PitchClass B Natural) Octave.six)

        timeSignature =
            TimeSignature Four TimeSignature.Quarter

        noteDuration =
            Note.Eighth Note.None

        model =
            { range = range
            , formulas = formulas
            , roots = roots
            , startingNote = SelectList.selected roots
            , scales = scales
            , playingState = Stopped
            , dialog = Nothing
            , samplesLoaded = False
            , device = classifyDevice { width = 0, height = 0 }
            , timeSignature = timeSignature
            , noteDuration = noteDuration
            , clickTrack = Switch.off
            , tempo = 160
            }
    in
    case line model |> Orchestration.orchestrate timeSignature noteDuration of
        Just orchestration ->
            ( model, Cmd.batch [ initialSizeCmd, Audio.loadPianoSamples, Score.render orchestration ] )

        Nothing ->
            ( model, Cmd.batch [ initialSizeCmd, Audio.loadPianoSamples ] )


classifyDevice : Window.Size -> Device
classifyDevice { width, height } =
    { width = width
    , height = height
    , phone = width <= 600
    , tablet = width > 600 && width <= 1200
    , desktop = width > 1200 && width <= 1800
    , bigDesktop = width > 1800
    , portrait = width < height
    }


renderNew : PlayingState -> Model -> ( Model, Cmd msg )
renderNew playingState model =
    case ( playingState, line model |> Orchestration.orchestrate model.timeSignature model.noteDuration ) of
        ( _, Nothing ) ->
            ( model, Cmd.none )

        ( Stopped, Just orchestration ) ->
            ( model, render orchestration )

        ( Playing, Just orchestration ) ->
            ( { model | playingState = Stopped }, Cmd.batch [ Audio.stop, render orchestration ] )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TogglePlay ->
            case model.playingState of
                Stopped ->
                    ( { model | playingState = Playing }, Audio.play model.clickTrack model.timeSignature model.noteDuration (line model) )

                Playing ->
                    ( { model | playingState = Stopped }, Audio.stop )

        DownloadPdf ->
            ( model, Score.downloadAsPdf )

        Open dialog ->
            ( { model | dialog = Just dialog }, Cmd.none )

        CloseDialog ->
            ( { model | dialog = Nothing }, Cmd.none )

        RootSelected note ->
            { model
                | roots = model.roots |> SelectList.select ((==) note)
                , playingState = Stopped
                , startingNote = note
            }
                |> renderNew model.playingState

        StartingNoteSelected note ->
            { model | startingNote = note, playingState = Stopped }
                |> renderNew model.playingState

        ScaleSelected scale ->
            { model
                | scales = model.scales |> SelectList.select (Tuple.second >> (==) scale)
                , playingState = Stopped
                , startingNote = SelectList.selected model.roots
            }
                |> renderNew model.playingState

        FormulaSelected formula ->
            { model
                | formulas = model.formulas |> SelectList.select ((==) formula)
                , playingState = Stopped
            }
                |> renderNew model.playingState

        SetTimeSignature timeSignature ->
            { model
                | timeSignature = timeSignature
                , playingState = Stopped
                , noteDuration =
                    if durationGte (beatDuration timeSignature) Quarter then
                        model.noteDuration

                    else
                        Note.Eighth Note.None
            }
                |> renderNew model.playingState

        ToggleNoteValue ->
            (case ( model.noteDuration, model.timeSignature ) of
                ( Note.Eighth Note.None, TimeSignature _ TimeSignature.Quarter ) ->
                    { model | noteDuration = Note.Eighth Note.Triplet }

                ( Note.Eighth Note.Triplet, _ ) ->
                    { model | noteDuration = Note.Eighth Note.None }

                _ ->
                    model
            )
                |> renderNew model.playingState

        RangeMinStepDown ->
            let
                min =
                    Pitch.transpose [ natural, flat ] (lowest model.range) -1
                        |> Maybe.withDefault (lowest model.range)
            in
            { model | range = Range.setLowest min model.range }
                |> renderNew model.playingState

        RangeMinStepUp ->
            let
                min =
                    Pitch.transpose [ natural, sharp ] (lowest model.range) 1
                        |> Maybe.withDefault (lowest model.range)
            in
            { model | range = Range.setLowest min model.range }
                |> renderNew model.playingState

        RangeMinSkipDown ->
            let
                min =
                    Pitch.transpose [ natural, flat ] (lowest model.range) -12
                        |> Maybe.withDefault (lowest model.range)
            in
            { model | range = Range.setLowest min model.range }
                |> renderNew model.playingState

        RangeMinSkipUp ->
            let
                min =
                    Pitch.transpose [ natural, sharp ] (lowest model.range) 12
                        |> Maybe.withDefault (lowest model.range)
            in
            { model | range = Range.setLowest min model.range }
                |> renderNew model.playingState

        RangeMaxStepDown ->
            let
                max =
                    Pitch.transpose [ natural, flat ] (highest model.range) -1
                        |> Maybe.withDefault (highest model.range)
            in
            { model | range = Range.setHighest max model.range }
                |> renderNew model.playingState

        RangeMaxStepUp ->
            let
                max =
                    Pitch.transpose [ natural, sharp ] (highest model.range) 1
                        |> Maybe.withDefault (highest model.range)
            in
            { model | range = Range.setHighest max model.range }
                |> renderNew model.playingState

        RangeMaxSkipDown ->
            let
                max =
                    Pitch.transpose [ natural, flat ] (highest model.range) -12
                        |> Maybe.withDefault (highest model.range)
            in
            { model | range = Range.setHighest max model.range }
                |> renderNew model.playingState

        RangeMaxSkipUp ->
            let
                max =
                    Pitch.transpose [ natural, sharp ] (highest model.range) 12
                        |> Maybe.withDefault (highest model.range)
            in
            { model | range = Range.setHighest max model.range }
                |> renderNew model.playingState

        SamplesLoaded ->
            ( { model | samplesLoaded = True }, Cmd.none )

        WindowResize device ->
            ( { model | device = device }, Cmd.none )

        ToggleClick ->
            ( { model | clickTrack = model.clickTrack |> Switch.toggle }, model.clickTrack |> Switch.fold Audio.muteClick Audio.unMuteClick )

        UpdateTempo tempo ->
            ( { model | tempo = String.toFloat tempo |> Result.withDefault 160.0 }, String.toFloat tempo |> Result.withDefault 160.0 |> round |> Audio.setTempo )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Audio.samplesLoaded SamplesLoaded
        , Window.resizes (classifyDevice >> WindowResize)
        ]