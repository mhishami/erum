-module(auth_controller).
-export ([handle_request/5]).
-export ([before_filter/1]).

-include("erum.hrl").

before_filter(_) ->
    {ok, proceed}.

handle_request(<<"GET">>, <<"login">> = Action, _, _, _) ->
    {render, Action, []};

handle_request(<<"POST">>, <<"login">>, _, Params, _) ->
    {ok, PostVals} = maps:find(<<"qs_body">>, Params),
    Email = proplists:get_value(<<"email">>, PostVals, <<"">>),
    Password = proplists:get_value(<<"password">>, PostVals, <<"">>),
    ?DEBUG("Email= ~p, Password= ~p~n", [Email, Password]),

    Res = mongo_worker:find_one(?DB_USER, {<<"email">>, Email}),
    ?DEBUG("Db Result = ~p~n", [Res]),
    case Res of
        {error, not_found} ->
            %% redirect to registration
            {redirect, <<"/auth/register">>};
        {ok, Data} ->
            %% validate user
            case authenticate(Password, Data) of
                ok ->
                    %% set session, and cookies etc.
                    Sid = web_util:hash_password(word_util:gen_pnr()),
                    % session_worker:set_cookies(Email, Sid),
                    session_worker:set_cookies(Sid, Email),
                    {redirect, <<"/">>, {cookie, Sid, Email}};
                error ->
                    {render, <<"auth_login">>, [
                            {error, "Username, or password is invalid"},
                            {email, Email}
                    ]}
            end
    end;

handle_request(<<"GET">>, <<"logout">>, _, Params, _) ->
    {ok, Sid} = maps:find(<<"sid">>, Params),
    session_worker:del_cookies(Sid),
    {redirect, <<"/">>};

handle_request(<<"GET">>, <<"register">>, _Args, _Params, _Req) ->
    {render, <<"register">>, []};
  
handle_request(<<"POST">>, <<"register">>, _Args, Params, _Req) ->
    {ok, PostVals} = maps:find(<<"qs_body">>, Params),

    Name = proplists:get_value(<<"name">>, PostVals),
    Email = proplists:get_value(<<"email">>, PostVals),
    Password = proplists:get_value(<<"password">>, PostVals),
    Password2 = proplists:get_value(<<"password2">>, PostVals),
    Page = <<"auth_register">>,

    case Password =/= Password2 orelse
         size(Password) =:= 0 orelse
         size(Name) =:= 0 orelse
         size(Email) =:= 0 of
        true ->
            %% passwords are not the same
            {render, Page, [
                {name, Name},
                {email, Email},
                {error, "Opps! All fields are required. Also, make sure all passwords are the same"}
            ]};
        _ ->
            %% save the user
            User = #{<<"name">> => Name, 
                     <<"email">> => Email, 
                     <<"password">> => web_util:hash_password(Password)},
            ?DEBUG("Page= ~p, User = ~p~n", [Page, User]),
            case mongo_worker:save(?DB_USER, User) of
                {ok, _} ->
                    {redirect, <<"/">>};
                _ ->
                    {render, Page, [
                        {name, Name},
                        {email, Email},
                        {error, "Cannot save user data. Pls come again!"}
                    ]}
            end

    end;

handle_request(_Method, _Action, _Args, _Params, _Req) ->    
    %% / will render home.dtl
    {redirect, <<"/">>}.

%% ----------------------------------------------------------------------------
%% Private funs
%%
authenticate(Password, Data) ->
    HashPass = web_util:hash_password(Password),
    Pass = maps:get(<<"password">>, Data),
    case HashPass =:= Pass of
        true -> ok;
        _    -> error
    end.

