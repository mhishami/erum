%% adm_controller.erl
-module (adm_controller).
-export ([handle_request/5]).
-export ([before_filter/1]).

-include("erum.hrl").

before_filter(SessionId) ->
    %% do some checking
    Sid = session_worker:get_cookies(SessionId),
    case Sid of
        {error, undefined} ->
            {redirect, <<"/auth/login">>};
        _ ->
            {ok, proceed}
    end.

handle_request(<<"GET">>, <<"users">>, _, Params, _) ->
    User = get_user(Params),
    {ok, Users} = mongo_worker:find(?DB_USER, {}, [], 10),
    {render, <<"adm_users">>, [
            {user, User},
            {users, web_util:maps_to_list(Users)}
        ]};

handle_request(<<"POST">>, <<"user">>, [<<"edit">>], Params, _) ->
    {ok, PostVals} = maps:find(<<"qs_body">>, Params),
    Id = proplists:get_value(<<"id">>, PostVals),

    User = get_user(Params),
    {ok, Data} = mongo_worker:find_one(?DB_USER, {<<"email">>, Id}),
    {ok, Name} = maps:find(<<"name">>, Data),
    {ok, Email} = maps:find(<<"email">>, Data),
    ?DEBUG("Data= ~p~n", [Data]),
    {render, <<"adm_user_edit">>, [
            {user, User}, {name, Name}, {email, Email}
        ]};

handle_request(<<"POST">>, <<"user">>, [<<"delete">>], Params, _) ->
    {ok, PostVals} = maps:find(<<"qs_body">>, Params),
    Id = proplists:get_value(<<"id">>, PostVals),

    ?DEBUG("Deleting user ~p~n", [Id]),
    mongo_worker:delete(?DB_USER, {<<"email">>, Id}),
    {redirect, <<"/adm/users">>};

handle_request(<<"POST">>, <<"user">>, [<<"update">>, <<"password">>], Params, _) ->
    {ok, PostVals} = maps:find(<<"qs_body">>, Params),
    Name  = proplists:get_value(<<"name">>, PostVals),
    Email = proplists:get_value(<<"email">>, PostVals),
    Pass1 = proplists:get_value(<<"password">>, PostVals),
    Pass2 = proplists:get_value(<<"password2">>, PostVals),

    case Pass1 =/= Pass2 orelse Pass1 =:= <<>> orelse Pass2 =:= <<>> of
        true ->
            %% show error
            {render, <<"adm_user_edit">>, [
                    {user, Email},
                    {name, Name},
                    {email, Email},
                    {pwd_error, <<"Bad password!">>}
                ]};
        false ->
            %% update password
            {ok, User} = mongo_worker:find_one(?DB_USER, {<<"email">>, Email}),
            User2 = User#{<<"password">> := web_util:hash_password(Pass2)},
            mongo_worker:update(?DB_USER, User2),
            {redirect, <<"/adm/users">>}
    end;

handle_request(<<"POST">>, <<"user">>, [<<"update">>, <<"info">>], Params, _) ->
    {ok, PostVals} = maps:find(<<"qs_body">>, Params),
    Name  = proplists:get_value(<<"name">>, PostVals),
    Email = proplists:get_value(<<"email">>, PostVals),

    {ok, User} = mongo_worker:find_one(?DB_USER, {<<"email">>, Email}),
    User2 = User#{<<"name">> := Name, <<"email">> := Email},
    mongo_worker:update(?DB_USER, User2),
    {redirect, <<"/adm/users">>};


handle_request(_Method, _Action, _Args, _Params, _Req) ->    
    %% redirect to /
    {redirect, <<"/">>}.

get_user(Params) ->
    case maps:find(<<"auth">>, Params) of
        {ok, User} -> User;
        _          -> undefined
    end.

