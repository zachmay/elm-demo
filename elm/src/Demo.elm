module Demo exposing (..)

import Platform exposing (Program)
import Html exposing (Html, div, h1, text, program)
import Html.Attributes as Attr
import Html.Events as Events
import Platform.Cmd as Cmd exposing (Cmd)
import Platform.Sub as Sub exposing (Sub)
import Http
import Json.Decode as D
import Json.Encode as E

-- Model

type alias Id = Int

type alias Candidate =
    { name : String
    , bandVotes : Int
    , albumVotes : Int
    , id : Id
    }

type alias Model =
    { candidates : List Candidate
    , nextId : Id
    , currentNameValue : String
    , debug : String 
    }

initialModel =
    { candidates = []
    , nextId = 2
    , currentNameValue = ""
    , debug = ""
    }

-- Messages

type Msg 
    = SuggestName 
    | CurrentNameUpdate String
    | BandVote Candidate 
    | AlbumVote Candidate
    | RequestDelete Candidate
    | RemoveCandidate Candidate
    | SetCandidateList (List Candidate)
    | OnError Http.Error
    | UpdateCandidate Candidate

-- Update

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        SetCandidateList candidates ->
            ( { model | candidates = candidates }
            , Cmd.none )

        OnError error -> 
            ( { model | debug = model.debug ++ toString error }
            , Cmd.none )

        SuggestName -> 
            let
                newCandidate =
                    { name = model.currentNameValue
                    , bandVotes = 0
                    , albumVotes = 0
                    , id = model.nextId
                    }
                newId = model.nextId + 1
            in
                ( { model
                  | candidates = model.candidates ++ [ newCandidate ]
                  , nextId = newId
                  }
                , Cmd.none
                )

        CurrentNameUpdate str ->
            ( { model | currentNameValue = str }
            , Cmd.none
            )

        BandVote candidate -> 
            ( model
            , putCandidate { candidate | bandVotes = candidate.bandVotes + 1 }
            )

        AlbumVote candidate -> 
            ( model
            , putCandidate { candidate | albumVotes = candidate.albumVotes + 1 }
            )

        UpdateCandidate candidate ->
            let
                replaceCandidate = updateById (always candidate) candidate.id
            in
            ( { model 
              | candidates = List.map replaceCandidate model.candidates }
            , Cmd.none )

        RequestDelete candidate -> 
            ( model
            , deleteCandidate candidate
            )

        RemoveCandidate candidate ->
            ( { model | candidates = List.filter (\c -> c.id /= candidate.id) model.candidates }
            , Cmd.none
            )




updateById : (Candidate -> Candidate) -> Id -> Candidate -> Candidate
updateById updater id candidate =
    if candidate.id == id then
        updater candidate
    else
        candidate

updateWithNew : Candidate -> Candidate -> Candidate
updateWithNew newCandidate _ =
    newCandidate

-- View

view : Model -> Html Msg 
view model =
    let
        candidateRows = List.map viewCandidate model.candidates
    in
        div
            []
            [ h1 [] [ text "Band/Album Name Manager" ] 
            , div 
                []
                [ Html.input
                    [ Attr.type_ "text"
                    , Events.onInput CurrentNameUpdate
                    ]
                    []
                , Html.button [ Events.onClick SuggestName ] [ text "Submit" ]
                ]
            , Html.table 
                []
                candidateRows 
            , Html.pre [] [ model.debug |> text ]
            ]
   
viewCandidate : Candidate -> Html Msg
viewCandidate candidate =
    Html.tr
        []
        [ Html.td [] [ text candidate.name ]
        , Html.td
            []
            [ candidate.bandVotes |> toString |> text
            , Html.button 
                [ Events.onClick (BandVote candidate) ]
                [ text "Vote Band" ]
            ]
        , Html.td
            []
            [ candidate.albumVotes |> toString |> text
            , Html.button
                [ Events.onClick (AlbumVote candidate) ]
                [ text "Vote Album" ]
            ]
        , Html.td
            []
            [ Html.button
                [ Events.onClick (RequestDelete candidate) ]
                [ text "Delete" ]
            ]
        ]


httpHelper : (error -> msg) -> (a -> msg) -> Result error a -> msg
httpHelper errorMapper successMapper result =
    case result of
        Err e -> errorMapper e
        Ok value -> successMapper value

deleteCandidate : Candidate -> Cmd Msg
deleteCandidate candidate =
    let
        url = "http://localhost:3000/candidates/" ++ (toString candidate.id)
    in
        delete url 
            |> Http.send (httpHelper OnError (\_ -> RemoveCandidate candidate))

putCandidate : Candidate -> Cmd Msg
putCandidate candidate =
    let
        url = "http://localhost:3000/candidates/" ++ (toString candidate.id)
        body =
            candidate |> candidateEncoder |> Http.jsonBody
    in
        put url body candidateDecoder
            |> Http.send (httpHelper OnError UpdateCandidate)


put : String -> Http.Body -> D.Decoder result -> Http.Request result
put url body decoder =
    Http.request
        { method = "PUT"
        , headers = []
        , url = url
        , body = body
        , expect = Http.expectJson decoder
        , timeout = Nothing
        , withCredentials = False
        }


delete : String -> Http.Request ()
delete url =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = url
        , body = Http.emptyBody
        , expect = Http.expectStringResponse (\_ -> Ok ())
        , timeout = Nothing
        , withCredentials = False
        }

candidateEncoder : Candidate -> E.Value
candidateEncoder candidate =
    E.object 
        [ ("id", E.int candidate.id)
        , ("name", E.string candidate.name)
        , ("bandVotes", E.int candidate.bandVotes)
        , ("albumVotes", E.int candidate.albumVotes)
        ]


getCandidateList : Cmd Msg
getCandidateList =
    Http.get "http://localhost:3000/candidates" candidateListDecoder
        |> Http.send (httpHelper OnError SetCandidateList)


candidateListDecoder : D.Decoder (List Candidate)
candidateListDecoder = D.list candidateDecoder

candidateDecoder : D.Decoder Candidate
candidateDecoder =
    D.map4 Candidate
        (D.field "name" D.string)
        (D.field "bandVotes" D.int)
        (D.field "albumVotes" D.int)
        (D.field "id" D.int)    

main = Html.program
    { init = (initialModel, getCandidateList)
    , subscriptions = (\_ -> Sub.none)
    , view = view
    , update = update
    }