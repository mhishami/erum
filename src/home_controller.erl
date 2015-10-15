-module(home_controller).
-export ([handle_request/5]).
-export ([before_filter/1]).

-include("erum.hrl").

before_filter(_) ->
    {ok, proceed}.

handle_request(<<"GET">>, _Action, _Args, Params, _Req) ->   
    ?DEBUG("Params= ~p~n", [Params]),
    %% / will render home.dtl
    case maps:find(<<"auth">>, Params) of
        {ok, User} -> {render, [{user, User}]};
        _          -> {render, []}
    end.
