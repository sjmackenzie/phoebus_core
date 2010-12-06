%% -------------------------------------------------------------------
%%
%% Phoebus: A distributed framework for large scale graph processing.
%%
%% Copyright (c) 2010 Arun Suresh. All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
-module(phoebus_core_worker_store).
-author('Arun Suresh <arun.suresh@gmail.com>').
-include("phoebus.hrl").


%% API
-export([purge/0, init/2, store_vertex/4,
         init_step_file/5, init_step_file/6,
         sync_table/2, sync_table/4,
         close_step_file/2,
         transfer_files/3,
         create_receiver/6,
         load_active_vertices/2,
         table_name/3,
         table_insert/3,
         mkdir_p/1,
         commit_step/3]).

%%%===================================================================
%%% API
%%%===================================================================
purge() ->
  os:cmd("rm -rf " ++ ?BASE_DIR()).

init(JobId, WId) ->
  ok = mkdir_p(?JOB_DIR(JobId, WId)),
  case file:open(?LAST_STEP_FILE(JobId, WId), [read]) of
    {error, enoent} -> {last_step, -1};
    {ok, F} ->
      case file:read_line(F) of
        {ok, StrStep} when is_list(StrStep) ->
          file:close(F),
          {last_step, list_to_integer(StrStep)};
        _ ->
          file:close(F),
          {last_step, -1}
      end
  end.

init_step_file(Type, JobId, WId, Mode, Step) ->
  init_step_file(Type, JobId, WId, Mode, Step, Step).

init_step_file(Type, JobId, WId, {table, Table}, Step, Idx) ->
  ok = mkdir_p(?STEP_DIR(JobId, WId, Step)),
  TableName = table_name(Table, Type, Step),
  ets:insert(worker_registry, {{TableName, sync}, 0}),
  case dets:info(TableName) of
    undefined ->
      ?DEBUG("Opening Table...",
             [{job, JobId}, {worker, WId}, {step, Step}]),
      case Type of
        flag ->
          dets:open_file(TableName,
                         [{file, step_data(Type, JobId, WId, Step, Idx)}]);
        vertex ->
          dets:open_file(TableName,
                         [{file, step_data(Type, JobId, WId, Step, Idx)}]);
        msg ->
          dets:open_file(TableName,
                         [{file, step_data(Type, JobId, WId, Step, Idx)},
                          {type, duplicate_bag}])
      end;
    _ -> {ok, TableName}
  end;
init_step_file(Type, JobId, WId, _Mode, Step, Idx) ->
  ok = mkdir_p(?STEP_DIR(JobId, WId, Step)),
  {table, Table} = phoebus_core_table_manager:lookup_table(JobId, WId),
  init_step_file(Type, JobId, WId, {table, Table}, Step, Idx).

init_rstep_file(Type, JobId, WId, RWId, Mode, Step) ->
  init_rstep_file(Type, JobId, WId, RWId, Mode, Step, Step).

init_rstep_file(Type, JobId, WId, RWId, Mode, Step, Idx) ->
  ok = mkdir_p(?RSTEP_DIR(JobId, WId, Step, RWId)),
  file:open(rstep_data(Type, JobId, WId, Step, RWId, Idx), Mode).

sync_table(Table, Type, Step, IsForce) ->
  TName = table_name(Table, Type, Step),
  sync_table(TName, IsForce).

sync_table(TName, IsForce) ->
  LastSync =
    case ets:lookup(worker_registry, {TName, sync}) of
      [{_, LS}] -> LS;
      _ -> 0
    end,
  CurrSize = dets:info(TName, size),
  case (((CurrSize - LastSync) > 100) or IsForce) of
    true ->
      ets:insert(worker_registry, {{TName, sync}, CurrSize}),
      FileName = dets:info(TName, filename),
      dets:close(TName),
      dets:open_file(TName, {file, FileName});
    _ -> ok
  end.

close_step_file(_, {_, []}) -> void;
close_step_file(Type, {Table, Buffer}) ->
  table_insert(Type, Table, Buffer);
close_step_file(_, FD) ->
  file:close(FD).

commit_step(JobId, WId, Step) ->
  {ok, FD} = file:open(?LAST_STEP_FILE(JobId, WId), [write]),
  file:write(FD, integer_to_list(Step)),
  file:close(FD),
  {_, Table} = phoebus_core_table_manager:lookup_table(JobId, WId),
  dets:close(table_name(Table, vertex, Step)),
  dets:close(table_name(Table, flag, Step)),
  dets:close(table_name(Table, msg, Step)),
  ok = mkdir_p(?STEP_DIR(JobId, WId, Step + 1)),
  OldDFile = step_data(vertex, JobId, WId, Step, Step),
  NewDFile = step_data(vertex, JobId, WId, Step + 1, Step + 1),
  os:cmd("cp " ++ OldDFile ++ " " ++ NewDFile).


load_active_vertices(JobId, WId) ->
  {_, Table} = phoebus_core_table_manager:lookup_table(JobId, WId),
  ActiveVerts =
    dets:select(table_name(Table, vertex, 0),
               [{{'$1', '_', '_'}, [], ['$$']}]),
  lists:foreach(
    fun([V]) -> dets:insert(table_name(Table, flag, 0), {V, active}) end,
    ActiveVerts).
  %% copy_step_file(JobId, WId, Step, vertex),
  %% copy_step_file(JobId, WId, Step, msg).


store_vertex(Vertex, {_, {JobId, MyWId, WId}}, Step, FDs)
  when WId =:= MyWId->
  {Table, Buffer} =
    case proplists:get_value(MyWId, FDs) of
      undefined ->
        {ok, T} = init_step_file(vertex, JobId, MyWId, [write], Step),
        {T, []};
      OldTD -> OldTD
    end,
  store_vertex_helper(Table, Buffer, Vertex, WId, FDs);
store_vertex(Vertex, {_Node, {JobId, MyWId, WId}}, Step, FDs) ->
  VRec = phoebus_core_serde:serialize_rec(vertex, Vertex),
  {ok, FD} =
    case proplists:get_value(WId, FDs) of
      undefined ->
        init_rstep_file(vertex, JobId, MyWId, WId, [write], Step);
      OldFD -> {ok, OldFD}
    end,
  file:write(FD, VRec),
  TempFDs = lists:keydelete(WId, 1, FDs),
  [{WId, FD}|TempFDs].



table_insert(Type, Table, X) ->
  %% io:format("~n~n Inserting [~p,~p,~p] ~n~n", [Type, Table, X]),
  try
    case Type of
      msg ->
        case X of
          {VName, Msgs} ->
            lists:foreach(
              fun(Msg) -> ok = dets:insert(Table, {VName, Msg}) end, Msgs);
          Lst ->
            lists:foreach(
              fun({VName, Msgs}) ->
                  lists:foreach(
                    fun(Msg) ->
                        ok = dets:insert(Table, {VName, Msg}) end, Msgs)
              end, Lst)
        end;
      _ -> case is_list(X) of
             true ->
               lists:foreach(
                 fun(Rec) ->
                     dets:insert_new(Table, Rec)
                 end, X);
             _ ->
               ok = dets:insert(Table, X)
           end
    end
  catch
    E1:E2 ->
      ?DEBUG("Error while inserting into table..",
             [{table, Table}, {error, E1, E2}]),
      table_insert(Type, Table, X, 120)
  end.


transfer_files(Node, {JobId, WId, OWid}, Step) ->
  MyPid = self(),
  spawn(fun() -> transfer_loop(init, MyPid, Node,
                               {JobId, WId, OWid}, Step) end).

create_receiver(Type, JobId, WId, Mode, Step, Idx) ->
  spawn(fun() ->
            recv_loop({init, Type}, JobId, WId, Mode, Step, Idx)
        end).

%%--------------------------------------------------------------------
%% @doc`
%% @spec
%% @end
%%--------------------------------------------------------------------

%%%===================================================================
%%% Internal functions
%%%===================================================================
transfer_loop(init, _MyPid, Node, {JobId, WId, OWid}, Step) ->
  Dir = ?RSTEP_DIR(JobId, WId, Step, OWid),
  case file:list_dir(Dir) of
    {ok, FList} ->
      lists:foreach(
        fun(FName) ->
            handle_transfer(file_type(FName), Node, Dir ++ FName,
                            JobId, OWid, Step, WId)
        end, FList);
    _ -> void
  end.


handle_transfer(Type, Node, LocalFName, JobId, OWid, Step, WId) ->
  WriteFD =
    rpc:call(Node, phoebus_core_worker_store, create_receiver,
             [Type, JobId, OWid, [write, binary], Step, WId]),
  {ok, ReadFD} =
    file:open(LocalFName, [read, binary]),
  trans_loop(LocalFName, ReadFD, WriteFD).


trans_loop(LocalFName, ReadFD, WriteFD) ->
  %% io:format("~n ~n [~p] [~p] ~n ~n",
  %% [self(), [LocalFName, ReadFD, WriteFD]]),
  case file:read(ReadFD, 16384) of
    {ok, Data} ->
      WriteFD ! {data, Data},
      trans_loop(LocalFName, ReadFD, WriteFD);
    eof ->
      file:close(ReadFD),
      %% file:delete(LocalFName),
      MRef = erlang:monitor(process, WriteFD),
      WriteFD ! {close, self()},
      receive
        {done, WriteFD} -> done;
        %% TODO : Handle this...
        {'DOWN', MRef, _, _, _} -> done
      end
  end.

recv_loop({init, Type}, JobId, WId, Mode, Step, Idx) ->
  Table = get_other_worker_table(JobId, WId, Type, Step),
  recv_loop({Type, Table, <<>>, 0}, JobId, WId, Mode, Step, Idx);
recv_loop({Type, WriteFD, Buffer, RCount}, JobId, WId, Mode, Step, Idx) ->
  receive
    {data, Data} ->
      %% io:format("~n~n Recvd lines : ~p ~n~n", [BinLines]),
      {VRecs, Rem} = phoebus_core_serde:deserialize_stream(Type, Buffer, Data),
      NewRCount = RCount + length(VRecs),
      case RCount > 750 of
        true ->
          [{_, WPid}] = ets:lookup(worker_registry, {JobId, WId}),
          ok = gen_fsm:sync_send_all_state_event(WPid, sync_table);
        _ ->
          void
      end,
      table_insert(Type, WriteFD, VRecs),
      recv_loop({Type, WriteFD, Rem, NewRCount}, JobId, WId, Mode,
                Step, Idx);
    {close, WPid} -> WPid ! {done, self()}
      %% file:close(WriteFD)
  end.


wait_table_loop(_Type, _JobId, _OWid, Pid, _Step, 0) ->
  Pid ! {error, enoent};
wait_table_loop(Type, JobId, OWid, Pid, Step, Counter) ->
  ?DEBUG("Checking for table...",
         [{job, JobId}, {worker, OWid}, {counter, Counter}]),
  case phoebus_core_table_manager:lookup_table(JobId, OWid) of
    {_, Table} ->
      case dets:info(table_name(Table, Type, Step)) of
        undefined ->
          ?DEBUG("Table unopen... waiting..",
                 [{job, JobId}, {worker, OWid}, {counter, Counter}]),
          timer:sleep(20000),
          wait_table_loop(Type, JobId, OWid, Pid, Step, Counter - 1);
        _ ->Pid ! {table, Table}
      end;
    _ ->
      ?DEBUG("Table NOT acquired... waiting..",
             [{job, JobId}, {worker, OWid}, {counter, Counter}]),
      timer:sleep(20000),
      wait_table_loop(Type, JobId, OWid, Pid, Step, Counter - 1)
  end.


get_other_worker_table(JobId, OWId, Type, Step) ->
  Pid = self(),
  spawn(fun() -> wait_table_loop(Type, JobId, OWId, Pid, Step, 30) end),
  Table =
    receive
      {table, T} -> T;
      %% TODO : have to think of something...
      {error, enoent} -> backup_table
    end,
  table_name(Table, Type, Step).

mkdir_p(Loc) ->
  {_, FinalRetVal} =
    lists:foldl(
      fun([], X) -> X;
         (DirName, {Finished, _}) ->
          Next =
            case Finished of
              "/" -> "/" ++ DirName;
              _ -> Finished ++ "/" ++ DirName
            end,
          R = file:make_dir(Next), {Next, R}
      end, {"/", init}, re:split(Loc, "/", [{return, list}])),
  case FinalRetVal of
    ok -> ok;
    {error, eexist} -> ok;
    E ->
      ?DEBUG("Could not Create Directory...", [{location, Loc}, {error, E}]),
      {error, E}
  end.


is_vfile(F) -> (re:run(F, ".*vertex_data", [anchored]) =/= nomatch).
is_qfile(F) -> (re:run(F, ".*msg_queue", [anchored]) =/= nomatch).

file_type(F) ->
  case is_vfile(F) of
    true -> vertex;
    _ -> case is_qfile(F) of
           true -> msg;
           _ -> unknown
         end
  end.

step_data(vertex, JobId, WId, Step, Idx) ->
        ?STEP_VETEX_DATA(JobId, WId, Step, Idx);
step_data(msg, JobId, WId, Step, Idx) ->
        ?STEP_MSG_QUEUE(JobId, WId, Step, Idx);
step_data(flag, JobId, WId, Step, Idx) ->
        ?STEP_FLAG_DATA(JobId, WId, Step, Idx).


rstep_data(vertex, JobId, WId, Step, RWId, Idx) ->
        ?RSTEP_VETEX_DATA(JobId, WId, Step, RWId, Idx);
rstep_data(msg, JobId, WId, Step, RWId, Idx) ->
        ?RSTEP_MSG_QUEUE(JobId, WId, Step, RWId, Idx).


table_name(Table, Type, Step) ->
  list_to_atom(atom_to_list(Table) ++ "_" ++
                 atom_to_list(Type) ++ "_" ++
                 integer_to_list(Step)).

table_insert(Type, Table, X, Counter) ->
  case dets:info(Table) of
    undefined ->
      timer:sleep(1000),
      table_insert(Type, Table, X, Counter - 1);
    _ ->
      table_insert(Type, Table, X)
  end.

%% copy_step_file(JobId, WId, Step, Type) ->
%%   [{_, Table}] = ets:lookup(table_mapping, {JobId, WId}),
%%   TName = table_name(Table, Type, Step),
%%   TFileName = dets:info(TName, filename),
%%   NewTFileName = step_data(Type, JobId, WId, Step + 1, 0),
%%   dets:close(TName),
%%   os:cmd("cp " ++ TFileName ++ " " ++ NewTFileName),
%%   dets:open_file(TName, [{file, NewTFileName}]).

store_vertex_helper(Table, Buffer, Vertex, WId, FDs) ->
  NewBuffer =
    case length(Buffer) > 9 of
      true ->
        table_insert(vertex, Table, [Vertex|Buffer]),
        [];
      _ -> [Vertex|Buffer]
    end,
  TempFDs = lists:keydelete(WId, 1, FDs),
  [{WId, {Table, NewBuffer}}|TempFDs].
