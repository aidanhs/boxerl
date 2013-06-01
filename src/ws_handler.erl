-module(ws_handler).
-behaviour(cowboy_websocket_handler).

-export([init/3]).
-export([websocket_init/3]).
-export([websocket_handle/3]).
-export([websocket_info/3]).
-export([websocket_terminate/3]).

init({tcp, http}, _Req, _Opts) ->
	{upgrade, protocol, cowboy_websocket}.

websocket_init(_TransportName, Req, _Opts) ->
	erlang:start_timer(1000, self(), <<"Hello!">>),
	{ok, Req, undefined_state}.

websocket_handle({text, Cmd}, Req, State) ->
	case Cmd of
		<<"lock">> ->
			lock_computer(),
			{reply, {text, <<"Computer locked">>}, Req, State};
		<<"lock_after ", Time/binary>> ->
			case parse_num(Time) of
				error ->
					{reply, {text, <<Time/binary, " not a time">>}, Req, State};
				Seconds ->
					case whereis(lock_timer) of
						undefined ->
							Pid = spawn(fun() -> lock_after(Seconds) end),
							register(lock_timer, Pid);
						_Pid ->
							lock_timer ! Seconds
					end,
					{reply, {text, <<"Locking in ", Time/binary, " secs">>}, Req, State}
			end;
		Other ->
			{reply, {text, <<"Unknown command ", Other/binary>>}, Req, State}
	end;
websocket_handle(_Data, Req, State) ->
	{ok, Req, State}.

websocket_info(_Info, Req, State) ->
	{ok, Req, State}.

websocket_terminate(_Reason, _Req, _State) ->
	ok.

%% UTILITY FUNCTIONS DOWN HERE %%

parse_num(<<"inf">>) -> inf;
parse_num(Bin) ->
	Str = binary_to_list(Bin),
	case string:to_integer(Str) of
		{N,[]} ->
			N;
		_ ->
			error
	end.

lock_computer() ->
	os:cmd("rundll32.exe user32.dll, LockWorkStation").

lock_after(Seconds) ->
	receive
		NewSeconds ->
			lock_after(NewSeconds)
	after
		5000 ->
			case Seconds of
				inf ->
					ok;
				N when N > 0 ->
					lock_after(N - 5);
				N when N =< 0 ->
					lock_computer()
			end
	end.
