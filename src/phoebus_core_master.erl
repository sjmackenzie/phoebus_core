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
-module(phoebus_core_master).
-author('Arun Suresh <arun.suresh@gmail.com>').
-include("phoebus.hrl").
-behaviour(gen_fsm).

%% API
-export([start_link/1]).

%% gen_fsm callbacks
-export([init/1,
         vsplit_phase1/2,
         vsplit_phase2/2,
         vsplit_phase3/2,
         algo/2,
         post_algo/2,
         check_algo_finish/2,
         store_result/2,
         end_state/2,
         state_name/3, handle_event/3,
         handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).

-record(state, {step = 0, max_steps, vertices = 0,
                job_id, job_name, start_time,
                conf, workers = {[], []},
                aggregate_val = none,
                aggregate_fun = none,
                algo_sub_state = none}).

-record(algo_sub_state, {num_active = 0}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Creates a gen_fsm process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this
%% function does not return until Module:init/1 has returned.
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(Conf) ->
  Name = name(proplists:get_value(name, Conf, noname)),
  gen_fsm:start_link(?MODULE, [[{name, Name}|Conf]], []).

%%%===================================================================
%%% gen_fsm callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm is started using gen_fsm:start/[3,4] or
%% gen_fsm:start_link/[3,4], this function is called by the new
%% process to initialize.
%%
%% @spec init(Args) -> {ok, StateName, State} |
%%                     {ok, StateName, State, Timeout} |
%%                     ignore |
%%                     {stop, StopReason}
%% @end
%%--------------------------------------------------------------------
init([Conf]) ->
  JobId = phoebus_core_utils:job_id(),
  JobName = proplists:get_value(name, Conf),
  {T, _} = erlang:statistics(wall_clock),
  io:format("~n### Starting Job : Id[~p] : Name[~p] ###~n", [JobId, JobName]),
  {ok, SS} = phoebus_core_external_stor:init(proplists:get_value(input_dir, Conf)),
  {ok, Partitions, SS2} = phoebus_core_external_store:partition_input(SS),
  phoebus_core_external_store:destroy(SS2),
  DefAlgoFun =
    fun({VName, _VValStr, EList}, InAgg, _InMsgs) ->
        {{VName, "done", EList}, [], InAgg, hold}
    end,
  DefCombineFun = none,
  AggVal = proplists:get_value(aggregate_val, Conf, none),
  AggFun = proplists:get_value(aggregate_fun, Conf, none),
  %% DefCombineFun = fun(Msg1, Msg2) -> Msg1 ++ "||" ++ Msg2 end,
  Workers = start_workers(JobId, {erlang:node(), self()},
                          Partitions,
                          proplists:get_value(output_dir, Conf),
                          proplists:get_value(algo_fun,
                                              Conf, DefAlgoFun),
                          proplists:get_value(combine_fun,
                                              Conf, DefCombineFun),
                          AggFun
                         ),
  {ok, vsplit_phase1,
   #state{max_steps = proplists:get_value(max_steps, Conf, 100000),
          job_id = JobId, job_name = JobName, start_time = T,
          aggregate_val = AggVal, aggregate_fun = AggFun,
          workers = {Workers, []}, conf = Conf}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_event/2, the instance of this function with the same
%% name as the current state name StateName is called to handle
%% the event. It is also called if a timeout occurs.
%%
%% @spec state_name(Event, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------

%% ------------------------------------------------------------------------
%% vsplit_phase1 START
%% Description : Get vertex loading progress from Wrokers
%% ------------------------------------------------------------------------
vsplit_phase1({vsplit_phase1_inter, WId, Vertices},
              #state{job_id = JobId,
                     conf = Conf,
                     vertices = OldVertices} = State) ->
  NewVertices = OldVertices + Vertices,
  ?DEBUG("Vertices Uncovered..", [{job, JobId}, {workers, WId},
                                  {name, proplists:get_value(name, Conf)},
                                  {num, NewVertices}]),
  {next_state, vsplit_phase1, State#state{vertices = NewVertices}};

vsplit_phase1({vsplit_phase1_done, WId, Vertices},
              #state{job_id = JobId,
                     conf = Conf,
                     vertices = OldVertices,
                     workers = Workers} = State) ->
  NewVertices = OldVertices + Vertices,
  ?DEBUG("Vertices Uncovered..", [{job, JobId}, {workers, WId},
                                  {name, proplists:get_value(name, Conf)},
                                  {num, NewVertices}]),
  {NewWorkers, NextState} =
    update_workers(vsplit_phase1, vsplit_phase2, none, Workers, WId),
  {next_state, NextState, State#state{workers = NewWorkers}}.
%% ------------------------------------------------------------------------
%% vsplit_phase1 DONE
%% ------------------------------------------------------------------------


%% ------------------------------------------------------------------------
%% vsplit_phase2 START
%% Description : Wait for Workers to finish transferring files..
%% ------------------------------------------------------------------------
vsplit_phase2({vsplit_phase2_done, WId, _WData},
              #state{workers = Workers} = State) ->
  {NewWorkers, NextState} =
    update_workers(vsplit_phase2, vsplit_phase3, bla, Workers, WId),
  {next_state, NextState, State#state{workers = NewWorkers}}.
%% ------------------------------------------------------------------------
%% vsplit_phase2 DONE
%% ------------------------------------------------------------------------


%% ------------------------------------------------------------------------
%% vsplit_phase3 START
%% Description : copy vertex data to new dir..
%% ------------------------------------------------------------------------
vsplit_phase3({vsplit_phase3_done, WId, _WData},
              #state{aggregate_val = Agg, workers = Workers} = State) ->
  {NewWorkers, NextState} =
    update_workers(vsplit_phase3, algo, Agg, Workers, WId),
  {next_state, NextState, State#state{workers = NewWorkers}}.
%% ------------------------------------------------------------------------
%% vsplit_phase3 DONE
%% ------------------------------------------------------------------------

algo({algo_done, WId, InterAggregate, NumMsgsActive},
     #state{workers = Workers,
            aggregate_val = CurrAgg,
            aggregate_fun = AggFun,
            algo_sub_state = AS} = State) ->
  NewAgg = apply_aggregate(AggFun, InterAggregate, CurrAgg),
  {NewWorkers, NextState} =
    update_workers(algo, post_algo, NewAgg, Workers, WId),
  %% TODO : Compute Incremental Aggregate..
  NewSubState =
    case AS of
      none -> #algo_sub_state{num_active = NumMsgsActive};
      #algo_sub_state{num_active = A} ->
        AS#algo_sub_state{num_active = A + NumMsgsActive}
    end,
  {next_state, NextState, State#state{
                            workers = NewWorkers,
                            aggregate_val = NewAgg,
                            algo_sub_state = NewSubState}}.


post_algo({post_algo_done, WId, _WData},
              #state{step = Step, workers = Workers} = State) ->
  {NewWorkers, NextState} =
    update_workers(post_algo, check_algo_finish, Step, Workers, WId),
  case NextState of
    check_algo_finish ->
      {next_state, check_algo_finish, State#state{workers = NewWorkers}, 0};
    _ ->
      {next_state, NextState, State#state{workers = NewWorkers}}
  end.


check_algo_finish(timeout, #state{step = Step, max_steps = MaxSteps,
                                  aggregate_val = Agg,
                                  algo_sub_state =
                                    #algo_sub_state{num_active = A},
                                  workers = {Workers, []}} = State) ->
  {NextState, NextStep} =
    case Step < MaxSteps of
      true ->
        case A > 0 of
          true -> {algo, Step + 1};
          _ -> {store_result, Step}
        end;
      _ -> {store_result, Step}
    end,
  NewWorkers = notify_workers2(Workers, NextState, Agg),
  {next_state, NextState, State#state{workers = {NewWorkers, []},
                                      algo_sub_state = none,
                                      step = NextStep}}.


store_result({store_result_done, WId, _WData},
              #state{workers = Workers} = State) ->
  {NewWorkers, NextState} =
    change_state(store_result, end_state, bla, Workers, WId, false),
  case NextState of
    end_state ->
      {next_state, end_state, State#state{workers = NewWorkers}, 0};
    _ ->
      {next_state, NextState, State#state{workers = NewWorkers}}
  end.

end_state(timeout, #state{job_id = JobId, job_name = JobName,
                          start_time = T, aggregate_val = Agg} = State) ->
  {T2, _} = erlang:statistics(wall_clock),
  io:format("~n### Job Ended : Id[~p] : Name[~p] "
            ++ ": Aggegate [~p] : Time [~p] ###~n",
            [JobId, JobName, Agg, (T2 - T)]),
  {stop, normal, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_event/[2,3], the instance of this function with
%% the same name as the current state name StateName is called to
%% handle the event.
%%
%% @spec state_name(Event, From, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {reply, Reply, NextStateName, NextState} |
%%                   {reply, Reply, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState} |
%%                   {stop, Reason, Reply, NewState}
%% @end
%%--------------------------------------------------------------------
state_name(_Event, _From, State) ->
  Reply = ok,
  {reply, Reply, state_name, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_all_state_event/2, this function is called to handle
%% the event.
%%
%% @spec handle_event(Event, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
handle_event(_Event, StateName, State) ->
  {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_all_state_event/[2,3], this function is called
%% to handle the event.
%%
%% @spec handle_sync_event(Event, From, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {reply, Reply, NextStateName, NextState} |
%%                   {reply, Reply, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState} |
%%                   {stop, Reason, Reply, NewState}
%% @end
%%--------------------------------------------------------------------
handle_sync_event(_Event, _From, StateName, State) ->
  Reply = ok,
  {reply, Reply, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it receives any
%% message other than a synchronous or asynchronous event
%% (or a system message).
%%
%% @spec handle_info(Info,StateName,State)->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
%% handle_info({'DOWN', MRef, _, _, _}, StateName,
%%             #state{step = Step, algo_sub_state = A,
%%                    workers = {Workers, []}} = State) ->
%%   ?DEBUG("Master Down... Shutting Down..", [{state_name, StateName},
%%                                              {job, JobId}, {worker, WId}]),
%%   {stop, monitor_down, State};

handle_info(_Info, StateName, State) ->
  {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_fsm terminates with
%% Reason. The return value is ignored.
%%
%% @spec terminate(Reason, StateName, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _StateName, _State) ->
  ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, StateName, State, Extra) ->
%%                   {ok, StateName, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, StateName, State, _Extra) ->
  {ok, StateName, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
update_workers(CurrentState, NextState, EInfo, {Waiting, Finished}, WId) ->
  change_state(CurrentState, NextState, EInfo, {Waiting, Finished}, WId, true).

change_state(CurrentState, NextState, ExtraInfo,
               {Waiting, Finished}, WId, NotifyWorkers) ->
  ?DEBUG("Master Recvd Event...", [{current, CurrentState},
                                     {next, NextState},
                                     {workers, {Waiting, Finished}},
                                     {worker, WId}]),
  {NewWaiting, NewFinished} =
    lists:foldl(
      fun({N, W, P, R, _}, {Wait, Done}) when W =:= WId ->
          {Wait, [{N, WId, P, R, NextState}|Done]};
         (WInfo, {Wait, Done}) -> {[WInfo|Wait], Done}
      end, {[], Finished}, Waiting),
  ?DEBUG("Master New State...", [{current, CurrentState},
                                     {next, NextState},
                                     {workers, {NewWaiting, NewFinished}},
                                     {worker, WId}]),
  case NewWaiting of
    [] ->
      ?DEBUG("Master Shifting States...", [{current, CurrentState},
                                             {next, NextState}]),
      case NotifyWorkers of
        true ->
          notify_workers(NewFinished, NextState, ExtraInfo);
        _ -> void
      end,
      {{NewFinished, NewWaiting}, NextState};
    _ -> {{NewWaiting, NewFinished}, CurrentState}
  end.

notify_workers(_, check_algo_finish, _) -> void;
notify_workers(Workers, NextState, ExtraInfo) ->
  lists:foreach(
    fun({Node, _, WPid, _, _}) ->
        rpc:call(Node, gen_fsm, send_event,
                 [WPid, {goto_state, NextState, ExtraInfo}])
    end, Workers).


notify_workers2(Workers, NextState, ExtraInfo) ->
  lists:foldl(
    fun({Node, WId, WPid, R, _}, Ws) ->
        rpc:call(Node, gen_fsm, send_event,
                 [WPid, {goto_state, NextState, ExtraInfo}]),
        [{Node, WId, WPid, R, NextState}|Ws]
    end, [], Workers).


name(StrName) ->
  list_to_atom("master_" ++ StrName).

start_workers(JobId, MasterInfo, Partitions,
              OutputDir, AlgoFun, CombineFun, AggFun) ->
  PartLen = length(Partitions),
  Nodes = phoebus_core_utils:all_nodes(),
  lists:foldl(
    fun(Part, Workers) ->
        WId = length(Workers) + 1,
        Node = phoebus_core_utils:map_to_node(JobId, WId, Nodes),
        %% TODO : Make Async
        %% [{Node, wId, wPid, wMonRef}]
        {ok, WPid} =
          rpc:call(Node, phoebus_core_worker, start_link,
                   [{JobId, WId, Nodes}, PartLen, MasterInfo, Part,
                    OutputDir, AlgoFun, CombineFun, AggFun]),
        MRef = erlang:monitor(process, WPid),
        [{Node, WId, WPid, MRef, vsplit_phase1}|Workers]
    end, [], Partitions).

apply_aggregate(none, Arg1, _) -> Arg1;
apply_aggregate(AggFun, Agg1, Agg2) -> AggFun(Agg1, Agg2).
