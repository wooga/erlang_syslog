%% Copyright (c) 2010 Jacob Vorreuter <jacob.vorreuter@gmail.com>
%%
%% Permission is hereby granted, free of charge, to any person
%% obtaining a copy of this software and associated documentation
%% files (the "Software"), to deal in the Software without
%% restriction, including without limitation the rights to use,
%% copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following
%% conditions:
%%
%% The above copyright notice and this permission notice shall be
%% included in all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
%% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
%% OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
%% NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
%% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
%% WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
%% OTHER DEALINGS IN THE SOFTWARE.
-module(syslog).
-behaviour(gen_server).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2, code_change/3]).

%% api callbacks
-export([start_link/0, start_link/3, send/1, send/2, send/3, multi_send/2]).

-record(state, {socket, address, port}).

%%====================================================================
%% api callbacks
%%====================================================================
start_link() ->
    {ok, Host} = inet:gethostname(),
    gen_server:start_link({local, ?MODULE}, ?MODULE, [Host, 514], []).

start_link(Name, Host, Port) when is_atom(Name), is_list(Host), is_integer(Port) ->
    gen_server:start_link({local, Name}, ?MODULE, [Host, Port], []).

send(Msg) when is_list(Msg) ->
    send(?MODULE, Msg, []).

send(Msg, Opts) when is_list(Msg), is_list(Opts) ->
    send(?MODULE, Msg, Opts);

send(Name, Msg) when is_atom(Name), is_list(Msg) ->
    send(Name, Msg, []).

send(Name, Msg, Opts) when is_atom(Name), is_list(Msg), is_list(Opts) ->
    gen_server:cast(Name, {send, [msg({Msg, Opts})]}).

multi_send(Name, Msgs) ->
    gen_server:cast(Name, {send, lists:map(fun msg/1, Msgs)}).

msg({Msg, Opts}) ->
    Level    = get_level(Opts),
    Facility = get_facility(Opts),
    Priority = get_priority(Level, Facility),
    Ident    = get_ident(Opts),
    Pid      = get_pid(Opts),

    ["<", Priority, "> ", Ident, "[", Pid, "]: ", Msg, "\n"].




%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
%%--------------------------------------------------------------------
init([Host, Port]) ->
    {ok, Addr} = inet:getaddr(Host, inet),
    case gen_udp:open(0) of
        {ok, Socket} ->
            {ok, #state{
                    socket = Socket,
                    address = Addr,
                    port = Port
            }};
        {error, Reason} ->
            {stop, Reason}
    end.


handle_call(_Msg, _From, State) ->
    {reply, ok, State}.


handle_cast({send, Packets}, State) ->
    lists:foreach(fun (Packet) ->
                          gen_udp:send(State#state.socket, State#state.address,
                                       State#state.port, Packet)
                  end, Packets),
    {noreply, State}.


handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
get_level(Opts) ->
    atom_to_level(proplists:get_value(level, Opts)).

get_facility(Opts) ->
    atom_to_facility(proplists:get_value(facility, Opts, user)).

get_priority(Level, Facility) ->
    integer_to_list(Level + Facility).

get_ident(Opts) ->
    case proplists:get_value(ident, Opts) of
        Atom when is_atom(Atom) -> atom_to_list(Atom);
        List when is_list(List) -> List;
        Binary when is_binary(Binary) -> Binary
    end.

get_pid(Opts) ->
    case proplists:get_value(pid, Opts) of
        undefined -> os:getpid();
        Atom when is_atom(Atom) -> atom_to_list(Atom);
        List when is_list(List) -> List;
        Binary when is_binary(Binary) -> Binary;
        Integer when is_integer(Integer) -> integer_to_list(Integer)
    end.

atom_to_level(emergency) -> 0; % system is unusable
atom_to_level(alert)     -> 1; % action must be taken immediately
atom_to_level(critical)  -> 2; % critical conditions
atom_to_level(error)     -> 3; % error conditions
atom_to_level(warning)   -> 4; % warning conditions
atom_to_level(notice)    -> 5; % normal but significant condition
atom_to_level(info)      -> 6; % informational
atom_to_level(debug)     -> 7; % debug-level messages
atom_to_level(_)         -> atom_to_level(info). % default to info


%% Copied from the c driver syslog project:
%% https://github.com/Vagabond/erlang-syslog/blob/master/src/syslog.erl#L141
atom_to_facility(kern)                 -> 0;
atom_to_facility(user)                 -> 8;
atom_to_facility(mail)                 -> 16;
atom_to_facility(daemon)               -> 24;
atom_to_facility(auth)                 -> 32;
atom_to_facility(syslog)               -> 40;
atom_to_facility(lpr)                  -> 48;
atom_to_facility(news)                 -> 56;
atom_to_facility(uucp)                 -> 64;
atom_to_facility(cron)                 -> 72;
atom_to_facility(authpriv)             -> 80;
atom_to_facility(ftp)                  -> 88;
atom_to_facility(netinfo)              -> 96;
atom_to_facility(remoteauth)           -> 104;
atom_to_facility(install)              -> 112;
atom_to_facility(ras)                  -> 120;
atom_to_facility(local0)               -> 16 * 8;
atom_to_facility(local1)               -> 17 * 8;
atom_to_facility(local2)               -> 18 * 8;
atom_to_facility(local3)               -> 19 * 8;
atom_to_facility(local4)               -> 20 * 8;
atom_to_facility(local5)               -> 21 * 8;
atom_to_facility(local6)               -> 22 * 8;
atom_to_facility(local7)               -> 23 * 8;
atom_to_facility(N) when is_integer(N) -> N.
